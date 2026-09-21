import 'dart:math';

/// A short, human-readable pairing code: two capital letters then four digits
/// (for example `QX4821`).
///
/// The same value is both encoded into the QR image and printed underneath it,
/// so a guardian whose camera is broken — or who simply prefers typing — can
/// key it in and get exactly the same result as scanning. Two letters plus
/// four digits is short enough to read aloud over the phone, and codes are
/// single-use and short-lived, which is what keeps them safe to be guessable.
abstract final class PairingCode {
  static const int length = 6;
  static const Duration validity = Duration(minutes: 10);

  static const String _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static final RegExp _pattern = RegExp(r'^[A-Z]{2}[0-9]{4}$');

  /// QR payloads carry this prefix so the scanner can reject unrelated codes
  /// (a shop receipt, a Wi-Fi QR) instead of trying to pair with them.
  static const String qrPrefix = 'ECHO:';

  static String generate([Random? random]) {
    final Random rng = random ?? Random.secure();
    final String a = _letters[rng.nextInt(_letters.length)];
    final String b = _letters[rng.nextInt(_letters.length)];
    final String digits = rng.nextInt(10000).toString().padLeft(4, '0');
    return '$a$b$digits';
  }

  /// What the QR image encodes.
  static String toQrPayload(String code) => '$qrPrefix$code';

  /// Accepts either a typed code or a scanned QR payload and returns the
  /// canonical code, or null if it is not one of ours. Spaces and dashes are
  /// tolerated because people naturally type `QX-4821`.
  static String? parse(String raw) {
    var value = raw.trim().toUpperCase();
    if (value.startsWith(qrPrefix)) {
      value = value.substring(qrPrefix.length);
    }
    value = value.replaceAll(RegExp(r'[\s\-_]'), '');
    return _pattern.hasMatch(value) ? value : null;
  }

  static bool isValid(String value) => _pattern.hasMatch(value);
}

/// A patient account a guardian has been granted control of.
class PatientLink {
  const PatientLink({
    required this.uid,
    required this.email,
    required this.linkedAt,
  });

  final String uid;
  final String email;
  final DateTime linkedAt;

  /// A readable stand-in when the account has no email (a Google account with
  /// a hidden address, for instance).
  String get displayName => email.isNotEmpty ? email : 'Patient ${uid.substring(0, 6)}';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'email': email,
    'linkedAt': linkedAt.toIso8601String(),
  };

  static PatientLink? fromJson(String uid, Map<String, dynamic> json) {
    if (uid.isEmpty) return null;
    final Object? linkedAt = json['linkedAt'];
    return PatientLink(
      uid: uid,
      email: json['email'] is String ? json['email'] as String : '',
      linkedAt: linkedAt is String
          ? (DateTime.tryParse(linkedAt) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

/// One emergency activation raised by a patient, surfaced to their guardians
/// as an in-app alert.
class SosEvent {
  const SosEvent({required this.id, required this.at, required this.label});

  /// The Firebase push key — also what lets a guardian's device tell a new
  /// alert from one it has already shown.
  final String id;
  final DateTime at;
  final String label;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'at': at.toIso8601String(),
    'label': label,
  };

  static SosEvent? fromJson(String id, Map<String, dynamic> json) {
    final Object? at = json['at'];
    if (at is! String) return null;
    final DateTime? parsed = DateTime.tryParse(at);
    if (parsed == null) return null;

    return SosEvent(
      id: id,
      at: parsed,
      label: json['label'] is String ? json['label'] as String : 'Emergency',
    );
  }
}
