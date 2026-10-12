import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/models/document_request.dart';
import 'package:guin_app/services/document_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

DocumentRequest _request(String id) => DocumentRequest.fromJson({
      'id': id,
      'user_id': 'user-1',
      'document_type': 'Barangay Clearance',
      'purpose': 'Employment',
      'document_data': <String, dynamic>{},
      'request_status': 'pending_review',
      'payment_amount': 50.0,
      'payment_status': 'unpaid',
      'requested_at': '2026-10-01T08:00:00.000Z',
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load returns null when nothing is cached', () async {
    final cache = DocumentCacheService();
    expect(await cache.loadMyRequests('user-1'), isNull);
  });

  test('round-trips saved requests with a timestamp', () async {
    final cache = DocumentCacheService();
    await cache.saveMyRequests('user-1', [_request('a'), _request('b')]);

    final cached = await cache.loadMyRequests('user-1');
    expect(cached, isNotNull);
    expect(cached!.requests, hasLength(2));
    expect(cached.requests.first.id, 'a');
    expect(cached.requests.first.documentType, 'Barangay Clearance');
    expect(cached.requests.first.requestStatus, 'pending_review');
    expect(cached.cachedAt, isNotNull);
  });

  test('cache is isolated per user', () async {
    final cache = DocumentCacheService();
    await cache.saveMyRequests('user-1', [_request('a')]);
    expect(await cache.loadMyRequests('user-2'), isNull);
  });

  test('save overwrites previous data', () async {
    final cache = DocumentCacheService();
    await cache.saveMyRequests('user-1', [_request('a'), _request('b')]);
    await cache.saveMyRequests('user-1', [_request('c')]);

    final cached = await cache.loadMyRequests('user-1');
    expect(cached!.requests, hasLength(1));
    expect(cached.requests.single.id, 'c');
  });

  test('clear removes cached data', () async {
    final cache = DocumentCacheService();
    await cache.saveMyRequests('user-1', [_request('a')]);
    await cache.clearMyRequests('user-1');
    expect(await cache.loadMyRequests('user-1'), isNull);
  });
}
