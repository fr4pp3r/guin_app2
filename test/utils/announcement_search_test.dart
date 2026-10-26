import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/models/announcement.dart';
import 'package:guin_app/utils/announcement_search.dart';

Announcement _announcement({
  required String id,
  required String title,
  String body = 'body',
  String createdByName = 'Brgy Official',
  required DateTime createdAt,
}) {
  return Announcement(
    id: id,
    title: title,
    body: body,
    createdBy: 'user-1',
    createdByName: createdByName,
    isPinned: false,
    createdAt: createdAt,
  );
}

void main() {
  // Helpers.now()/toPh() fall back to local time when the timezone DB has not
  // been initialized, which is the case in these offline tests.
  final feed = [
    _announcement(
      id: '1',
      title: 'Barangay assembly',
      body: 'Meeting at the covered court.',
      createdByName: 'Juan Dela Cruz',
      createdAt: DateTime(2026, 10, 20, 9),
    ),
    _announcement(
      id: '2',
      title: 'Free anti-rabies shots',
      body: 'Bring your pets to the health center.',
      createdByName: 'Maria Santos',
      createdAt: DateTime(2026, 10, 18, 14),
    ),
    _announcement(
      id: '3',
      title: 'Road clearing operations',
      body: 'Expect traffic along Rizal Street.',
      createdByName: 'Juan Dela Cruz',
      createdAt: DateTime(2026, 9, 5, 8),
    ),
  ];

  group('AnnouncementSearch.filter — no filters', () {
    test('returns every announcement in the original order', () {
      final result = AnnouncementSearch.filter(feed);

      expect(result.map((a) => a.id), ['1', '2', '3']);
    });

    test('a blank or whitespace-only query is treated as no query', () {
      expect(AnnouncementSearch.filter(feed, query: '   ').length, 3);
    });
  });

  group('AnnouncementSearch.filter — by name', () {
    test('matches the title, case-insensitively and partially', () {
      final result = AnnouncementSearch.filter(feed, query: 'ASSEMBLY');

      expect(result.map((a) => a.id), ['1']);
    });

    test('matches the poster name', () {
      final result = AnnouncementSearch.filter(feed, query: 'santos');

      expect(result.map((a) => a.id), ['2']);
    });

    test('matches the body when the title does not', () {
      final result = AnnouncementSearch.filter(feed, query: 'traffic');

      expect(result.map((a) => a.id), ['3']);
    });

    test('returns an empty list when nothing matches', () {
      expect(AnnouncementSearch.filter(feed, query: 'zzzz'), isEmpty);
    });
  });

  group('AnnouncementSearch.filter — by date text', () {
    test('matches the server form yyyy-MM-dd', () {
      final result = AnnouncementSearch.filter(feed, query: '2026-10-18');

      expect(result.map((a) => a.id), ['2']);
    });

    test('matches the localized form the card prints', () {
      final result = AnnouncementSearch.filter(feed, query: 'oct 20');

      expect(result.map((a) => a.id), ['1']);
    });

    test('a partial ISO date matches the whole month', () {
      final result = AnnouncementSearch.filter(feed, query: '2026-10');

      expect(result.map((a) => a.id), ['1', '2']);
    });
  });

  group('AnnouncementSearch.filter — by calendar day', () {
    test('keeps only the rows created on the picked day', () {
      final result = AnnouncementSearch.filter(
        feed,
        day: DateTime(2026, 10, 18),
      );

      expect(result.map((a) => a.id), ['2']);
    });

    test('ignores the time component of the day', () {
      final result = AnnouncementSearch.filter(
        feed,
        day: DateTime(2026, 10, 20, 23, 59),
      );

      expect(result.map((a) => a.id), ['1']);
    });

    test('combines with the text query (AND)', () {
      final result = AnnouncementSearch.filter(
        feed,
        query: 'juan',
        day: DateTime(2026, 10, 20),
      );

      expect(result.map((a) => a.id), ['1']);
    });

    test('a day with no announcements yields an empty list', () {
      expect(
        AnnouncementSearch.filter(feed, day: DateTime(2026, 1, 1)),
        isEmpty,
      );
    });
  });
}
