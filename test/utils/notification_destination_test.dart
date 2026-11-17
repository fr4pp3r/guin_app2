import 'package:flutter_test/flutter_test.dart';
import 'package:guin_app/config/routes.dart';
import 'package:guin_app/models/notification.dart';
import 'package:guin_app/utils/notification_destination.dart';
import 'package:guin_app/utils/role_access.dart';

AppNotification n(String type, String? refType, String? refId,
    {String message = 'msg'}) {
  return AppNotification(
    id: '1',
    userId: 'u1',
    title: 't',
    message: message,
    type: type,
    isRead: false,
    createdAt: DateTime.utc(2026, 1, 1),
    referenceType: refType,
    referenceId: refId,
  );
}

void main() {
  group('resolveDestination', () {
    test('citizen + document_request -> documentViewer', () {
      expect(
        resolveDestination(
          n('request_submitted', 'document_request', 'r1'),
          AppRoles.citizen,
        ),
        NotificationDestination.documentViewer,
      );
    });

    test('secretary + document_request type system "New document request" -> pendingRequests', () {
      expect(
        resolveDestination(
          n('system', 'document_request', 'r1',
              message: 'New document request'),
          AppRoles.secretary,
        ),
        NotificationDestination.pendingRequests,
      );
    });

    test('treasurer + document_request type payment_verified -> pendingPayments', () {
      expect(
        resolveDestination(
          n('payment_verified', 'document_request', 'r1'),
          AppRoles.treasurer,
        ),
        NotificationDestination.pendingPayments,
      );
    });

    test('citizen + document_request type payment_verified -> documentViewer', () {
      expect(
        resolveDestination(
          n('payment_verified', 'document_request', 'r1'),
          AppRoles.citizen,
        ),
        NotificationDestination.documentViewer,
      );
    });

    test('captain + document_request + request_approved -> captainApproval', () {
      expect(
        resolveDestination(
          n('request_approved', 'document_request', 'r1'),
          AppRoles.captain,
        ),
        NotificationDestination.captainApproval,
      );
    });

    test('tanod + incident_report -> incidentReports', () {
      expect(
        resolveDestination(
          n('incident_submitted', 'incident_report', 'i1'),
          AppRoles.barangayTanod,
        ),
        NotificationDestination.incidentReports,
      );
    });

    test('any role + announcement -> announcements', () {
      for (final role in [
        AppRoles.citizen,
        AppRoles.captain,
        AppRoles.secretary,
      ]) {
        expect(
          resolveDestination(
            n('system', 'announcement', 'a1'),
            role,
          ),
          NotificationDestination.announcements,
        );
      }
    });

    test('captain + user_registration -> pendingUsers', () {
      expect(
        resolveDestination(
          n('registration_approved', 'user_registration', 'u1'),
          AppRoles.captain,
        ),
        NotificationDestination.pendingUsers,
      );
    });

    test('citizen + user_registration -> none', () {
      expect(
        resolveDestination(
          n('registration_approved', 'user_registration', 'u1'),
          AppRoles.citizen,
        ),
        NotificationDestination.none,
      );
    });

    test('null refType + request_*/payment_*/system -> myRequests', () {
      for (final type in ['request_submitted', 'request_approved', 'payment_verified', 'system']) {
        expect(
          resolveDestination(n(type, null, null), AppRoles.citizen),
          NotificationDestination.myRequests,
        );
      }
    });

    test('null refType + incident_* -> myReports', () {
      for (final type in ['incident_submitted', 'incident_updated']) {
        expect(
          resolveDestination(n(type, null, null), AppRoles.citizen),
          NotificationDestination.myReports,
        );
      }
    });

    test('null refType + registration_* -> none', () {
      for (final type in ['registration_approved', 'registration_rejected']) {
        expect(
          resolveDestination(n(type, null, null), AppRoles.citizen),
          NotificationDestination.none,
        );
      }
    });
  });

  group('routeName', () {
    test('non-none values map to AppRoutes constants', () {
      expect(NotificationDestination.documentViewer.routeName,
          AppRoutes.documentViewer);
      expect(NotificationDestination.pendingRequests.routeName,
          AppRoutes.pendingRequests);
      expect(NotificationDestination.pendingPayments.routeName,
          AppRoutes.pendingPayments);
      expect(NotificationDestination.captainApproval.routeName,
          AppRoutes.captainApproval);
      expect(NotificationDestination.incidentReports.routeName,
          AppRoutes.incidentReports);
      expect(NotificationDestination.announcements.routeName,
          AppRoutes.announcements);
      expect(NotificationDestination.pendingUsers.routeName,
          AppRoutes.pendingUsers);
      expect(NotificationDestination.myRequests.routeName, AppRoutes.myRequests);
      expect(NotificationDestination.myReports.routeName, AppRoutes.myReports);
      expect(NotificationDestination.none.routeName, isNull);
    });
  });
}