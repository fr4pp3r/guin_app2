import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/models/incident_report.dart';

Map<String, dynamic> _json(String id) => {
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
    };

void main() {
  test('fromJson parses latitude/longitude numbers as doubles', () {
    final report = IncidentReport.fromJson({
      ..._json('a'),
      'latitude': 14.5995,
      'longitude': 120.9842,
    });

    expect(report.latitude, 14.5995);
    expect(report.longitude, 120.9842);
  });

  test('fromJson parses integer-valued coordinates as doubles', () {
    final report = IncidentReport.fromJson({
      ..._json('a'),
      'latitude': 14,
      'longitude': 121,
    });

    expect(report.latitude, 14.0);
    expect(report.longitude, 121.0);
  });

  test('fromJson without geo keys yields null and does not throw', () {
    final report = IncidentReport.fromJson(_json('a'));

    expect(report.latitude, isNull);
    expect(report.longitude, isNull);
  });

  test('fromJson with explicit nulls yields null', () {
    final report = IncidentReport.fromJson({
      ..._json('a'),
      'latitude': null,
      'longitude': null,
    });

    expect(report.latitude, isNull);
    expect(report.longitude, isNull);
  });

  test('toJson → fromJson round-trip preserves coordinates', () {
    final original = IncidentReport.fromJson({
      ..._json('a'),
      'latitude': 14.5995,
      'longitude': 120.9842,
    });

    final restored = IncidentReport.fromJson(original.toJson());

    expect(restored.latitude, original.latitude);
    expect(restored.longitude, original.longitude);
  });

  test('toJson → fromJson round-trip preserves null coordinates', () {
    final original = IncidentReport.fromJson(_json('a'));

    final restored = IncidentReport.fromJson(original.toJson());

    expect(restored.latitude, isNull);
    expect(restored.longitude, isNull);
  });
}
