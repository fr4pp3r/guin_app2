import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/models/incident_report.dart';
import 'package:guin_app/services/incident_report_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

IncidentReport _report(String id) => IncidentReport.fromJson({
      'id': id,
      'report_number': 'RPT-001',
      'submitted_by': 'user-1',
      'report_type': 'noise',
      'title': 'Loud noise',
      'description': 'Loud music late at night',
      'location': 'Purok 2',
      'incident_datetime': '2026-10-01T20:00:00.000Z',
      'is_sensitive': false,
      'is_anonymous': false,
      'identity_visibility': 'visible',
      'priority': 'normal',
      'status': 'submitted',
      'created_at': '2026-10-01T20:05:00.000Z',
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load returns null when nothing is cached', () async {
    final cache = IncidentReportCacheService();
    expect(await cache.loadMyReports('user-1'), isNull);
  });

  test('round-trips saved reports with a timestamp', () async {
    final cache = IncidentReportCacheService();
    await cache.saveMyReports('user-1', [_report('a'), _report('b')]);

    final cached = await cache.loadMyReports('user-1');
    expect(cached, isNotNull);
    expect(cached!.reports, hasLength(2));
    expect(cached.reports.first.id, 'a');
    expect(cached.reports.first.title, 'Loud noise');
    expect(cached.reports.first.status, 'submitted');
    expect(cached.cachedAt, isNotNull);
  });

  test('cache is isolated per user', () async {
    final cache = IncidentReportCacheService();
    await cache.saveMyReports('user-1', [_report('a')]);
    expect(await cache.loadMyReports('user-2'), isNull);
  });

  test('clear removes cached reports', () async {
    final cache = IncidentReportCacheService();
    await cache.saveMyReports('user-1', [_report('a')]);
    await cache.clearMyReports('user-1');
    expect(await cache.loadMyReports('user-1'), isNull);
  });
}
