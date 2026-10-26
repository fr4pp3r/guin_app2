import 'package:guin_app/models/announcement.dart';
import 'package:guin_app/utils/helpers.dart';

/// Pure, offline search for the announcement feed.
///
/// The board is global — every signed-in user loads the same list — so a search
/// simply narrows the rows already in memory. Nothing here hits Supabase, which
/// keeps the behaviour identical online and offline and makes it unit-testable.
class AnnouncementSearch {
  AnnouncementSearch._();

  /// Filters [announcements] by a free-text [query] and/or an exact calendar
  /// [day]. Both filters combine (AND); each is optional.
  ///
  /// [query] is matched case-insensitively against the announcement's **title**,
  /// body, poster name, and its date written either as `yyyy-MM-dd` (how the
  /// server stores it) or as the localized `MMM dd, yyyy` form the card prints —
  /// so "oct 20" and "2026-10-20" both find the same row.
  ///
  /// [day] keeps only announcements created on that calendar day, evaluated in
  /// Asia/Manila — the same timezone the cards render in, so the day the user
  /// sees is the day they can filter by.
  ///
  /// Pinned-first order is preserved: the input order is never re-sorted.
  static List<Announcement> filter(
    List<Announcement> announcements, {
    String query = '',
    DateTime? day,
  }) {
    final needle = _normalize(query);
    final hasQuery = needle.isNotEmpty;
    if (!hasQuery && day == null) return List<Announcement>.of(announcements);

    return announcements.where((announcement) {
      if (day != null && !_isSameDay(Helpers.toPh(announcement.createdAt), day)) {
        return false;
      }
      if (!hasQuery) return true;
      return _haystack(announcement).contains(needle);
    }).toList();
  }

  /// Everything a query is matched against, lowercased and joined once.
  static String _haystack(Announcement announcement) {
    final ph = Helpers.toPh(announcement.createdAt);
    final isoDate = '${ph.year.toString().padLeft(4, '0')}-'
        '${ph.month.toString().padLeft(2, '0')}-'
        '${ph.day.toString().padLeft(2, '0')}';

    return _normalize(
      [
        announcement.title,
        announcement.body,
        announcement.createdByName,
        isoDate,
        Helpers.formatDate(announcement.createdAt),
        Helpers.formatDateTime(announcement.createdAt),
      ].join(' '),
    );
  }

  static String _normalize(String value) => value.toLowerCase().trim();

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
