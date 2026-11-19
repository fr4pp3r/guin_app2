import 'package:guin_app/config/routes.dart';
import 'package:guin_app/models/notification.dart';
import 'package:guin_app/utils/role_access.dart';

/// Where a notification deep-link should land.
///
/// Pure: no BuildContext, no I/O, no navigation. The enum exists so the
/// resolver can return a stable value that the navigator (Task 5) maps to a
/// route. `routeName` is `null` only for [NotificationDestination.none].
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
        return AppRoutes.documentViewer;
      case NotificationDestination.pendingRequests:
        return AppRoutes.pendingRequests;
      case NotificationDestination.pendingPayments:
        return AppRoutes.pendingPayments;
      case NotificationDestination.captainApproval:
        return AppRoutes.captainApproval;
      case NotificationDestination.incidentReports:
        return AppRoutes.incidentReports;
      case NotificationDestination.announcements:
        return AppRoutes.announcements;
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
/// Deep-linking is intentionally limited to `document_request` notifications
/// for now. Every other reference type (announcement, incident_report,
/// user_registration) and the type-prefix fallbacks below return
/// [NotificationDestination.none] — the tap handler shows the "unavailable"
/// snackbar instead of opening a screen that isn't wired yet.
NotificationDestination resolveDestination(
  AppNotification notification,
  String role,
) {
  final refType = notification.referenceType;
  final message = notification.message;
  final type = notification.type;

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

  // Announcement / incident / registration / unknown refs: no redirect yet.
  return NotificationDestination.none;
}