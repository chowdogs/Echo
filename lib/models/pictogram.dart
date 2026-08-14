/// One communication symbol returned by the ARASAAC API.
///
/// The API gives us a numeric id and a list of keywords; the image itself
/// lives on a separate static host, addressed by that id.
class Pictogram {
  const Pictogram({required this.id, required this.keyword});

  final int id;
  final String keyword;

  /// The pictogram image. 300 px is plenty for a tile and keeps downloads
  /// light on mobile data.
  String get imageUrl =>
      'https://static.arasaac.org/pictograms/$id/${id}_300.png';

  /// Builds a [Pictogram] from one ARASAAC search-result entry, or returns
  /// null if the entry is missing the fields we rely on.
  static Pictogram? fromJson(Map<String, dynamic> json) {
    final Object? id = json['_id'];
    if (id is! int) return null;

    // `keywords` is a list of objects, each with its own `keyword` string.
    String keyword = '';
    final Object? keywords = json['keywords'];
    if (keywords is List && keywords.isNotEmpty) {
      final Object? first = keywords.first;
      if (first is Map && first['keyword'] is String) {
        keyword = first['keyword'] as String;
      }
    }

    return Pictogram(id: id, keyword: keyword);
  }
}
