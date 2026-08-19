/// A signed-in user's session — everything the app needs to make authenticated
/// requests and to remember the login across restarts.
class AuthSession {
  const AuthSession({
    required this.uid,
    required this.email,
    required this.idToken,
    required this.refreshToken,
  });

  /// The Firebase user id — also the key under which this user's board is
  /// stored (`/users/{uid}`).
  final String uid;
  final String email;

  /// Short-lived token (about an hour) sent with each database request.
  final String idToken;

  /// Long-lived token used to obtain a fresh [idToken] when it expires.
  final String refreshToken;

  AuthSession copyWith({String? idToken, String? refreshToken}) {
    return AuthSession(
      uid: uid,
      email: email,
      idToken: idToken ?? this.idToken,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'uid': uid,
    'email': email,
    'idToken': idToken,
    'refreshToken': refreshToken,
  };

  static AuthSession? fromJson(Map<String, dynamic> json) {
    final Object? uid = json['uid'];
    final Object? email = json['email'];
    final Object? idToken = json['idToken'];
    final Object? refreshToken = json['refreshToken'];
    if (uid is! String ||
        email is! String ||
        idToken is! String ||
        refreshToken is! String) {
      return null;
    }
    return AuthSession(
      uid: uid,
      email: email,
      idToken: idToken,
      refreshToken: refreshToken,
    );
  }
}
