import 'package:guin_app/config/routes.dart';
import 'package:guin_app/models/notification.dart';
import 'package:guin_app/utils/role_access.dart';

/// Where a notification deep-link should land.
///
/// Pure: no BuildContext, no I/O, no navigation. The enum exists so the
/// resolver can return a stable value that the navigator (Task 5) maps to a
/// route. `routeName` is `null` for values whose AppRoutes constant is added
/// by a later task (documentViewer, announcements) — the navigator treats
/// null as "no route yet".
enum NotificationDestination {
  documentViewer,
  pendingRequests,
  pendingPayments,
  captainApproval,
  incidentReports,
  announcements,
  pendingUsers,
  myRequests,
  myReports,
  none;

  String? get routeName {
    switch (this) {
      case NotificationDestination.documentViewer:
        return null; // AppRoutes.documentViewer added in Task 4
      case NotificationDestination.pendingRequests:
        return AppRoutes.pendingRequests;
      case NotificationDestination.pendingPayments:
        return AppRoutes.pendingPayments;
      case NotificationDestination.captainApproval:
        return AppRoutes.captainApproval;
      case NotificationDestination.incidentReports:
        return AppRoutes.incidentReports;
      case NotificationDestination.announcements:
        return null; // AppRoutes.announcements added in Task 4
      case NotificationDestination.pendingUsers:
        return AppRoutes.pendingUsers;
      case NotificationDestination.myRequests:
        return AppRoutes.myRequests;
      case NotificationDestination.myReports:
        return AppRoutes.myReports;
      case NotificationDestination.none:
        return null;
    }
  }
}

/// Maps a notification + the viewer's role to a destination.
///
/// Discrimination rules (see plan):
/// - `announcement` / `incident_report` references are role-agnostic.
/// - `user_registration` to an official → pendingUsers; to a citizen → none.
/// - `document_request` to a citizen → documentViewer; to an official the
///   queue is picked from the notification `type` and message substring.
/// - null referenceType falls back to the `type` prefix.
NotificationDestination resolveDestination(
  AppNotification notification,
  String role,
) {
  final refType = notification.referenceType;
  final message = notification.message;
  final type = notification.type;

  if (refType == 'announcement') {
    return NotificationDestination.announcements;
  }
  if (refType == 'incident_report') {
    return NotificationDestination.incidentReports;
  }
  if (refType == 'user_registration') {
    return AppRoles.isOfficial(role)
        ? NotificationDestination.pendingUsers
        : NotificationDestination.none;
  }
  if (refType == 'document_request') {
    if (!AppRoles.isOfficial(role)) {
      return NotificationDestination.documentViewer;
    }
    final lowerMessage = message.toLowerCase();
    if (type == 'payment_verified' ||
        lowerMessage.contains('payment')) {
      return NotificationDestination.pendingPayments;
    }
    if (type == 'request_approved' ||
        lowerMessage.contains('approval')) {
      return NotificationDestination.captainApproval;
    }
    return NotificationDestination.pendingRequests;
  }

  // Null or unknown referenceType: fall back to the notification type prefix.
  if (type.startsWith('request_') ||
      type.startsWith('payment_') ||
      type == 'system') {
    return NotificationDestination.myRequests;
  }
  if (type.startsWith('incident_')) {
    return NotificationDestination.myReports;
  }
  if (type.startsWith('registration_')) {
    return NotificationDestination.none;
  }
  return NotificationDestination.none;
}