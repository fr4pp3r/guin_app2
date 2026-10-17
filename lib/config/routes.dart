import 'package:flutter/material.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:guin_app/models/document_request.dart';
import 'package:guin_app/models/incident_report.dart';
import 'package:guin_app/screens/splash_screen.dart';
import 'package:guin_app/screens/auth/login_screen.dart';
import 'package:guin_app/screens/auth/register_screen.dart';
import 'package:guin_app/screens/auth/pending_approval_screen.dart';
import 'package:guin_app/screens/citizen/dashboard_screen.dart';
import 'package:guin_app/screens/citizen/request_document_screen.dart';
import 'package:guin_app/screens/citizen/my_requests_screen.dart';
import 'package:guin_app/screens/citizen/my_reports_screen.dart';
import 'package:guin_app/screens/citizen/incident_report_detail_screen.dart';
import 'package:guin_app/screens/citizen/notifications_screen.dart';
import 'package:guin_app/screens/citizen/e_receipt_viewer_screen.dart';
import 'package:guin_app/screens/admin/dashboard_screen.dart' as admin;
import 'package:guin_app/screens/tanod/dashboard_screen.dart' as tanod;
import 'package:guin_app/screens/admin/manage_users_screen.dart';
import 'package:guin_app/screens/admin/pending_requests_screen.dart';
import 'package:guin_app/screens/admin/pending_payments_screen.dart';
import 'package:guin_app/screens/admin/settings_screen.dart';
import 'package:guin_app/screens/admin/all_requests_screen.dart';
import 'package:guin_app/screens/admin/document_fees_screen.dart';
import 'package:guin_app/screens/admin/document_formats_screen.dart';
import 'package:guin_app/screens/admin/captain_approval_screen.dart';
import 'package:guin_app/screens/verify_document_screen.dart';
import 'package:guin_app/screens/admin/incident_reports_screen.dart';
import 'package:guin_app/screens/citizen/submit_report_screen.dart';
import 'package:guin_app/screens/citizen/profile_screen.dart';
import 'package:guin_app/screens/admin/profile_screen.dart';

class AppRoutes {
  // Splash
  static const String splash = '/';

  // Auth Routes
  static const String login = '/login';
  static const String register = '/register';
  static const String pendingApproval = '/pending-approval';

  // Citizen Routes
  static const String citizenDashboard = '/citizen/dashboard';
  static const String requestDocument = '/citizen/request-document';
  static const String myRequests = '/citizen/my-requests';
  static const String myReports = '/citizen/my-reports';

  /// Read-only detail page for one of the citizen's own incident reports.
  /// Takes an [IncidentReport] via `Navigator.pushNamed` arguments.
  static const String citizenIncidentDetail = '/citizen/incident-detail';
  static const String notifications = '/citizen/notifications';
  static const String submitReport = '/citizen/submit-report';
  static const String profile = '/citizen/profile';
  static const String eReceipt = '/citizen/e-receipt';
  static const String incidentReports = '/admin/incident-reports';
  static const String verifyDocument = '/verify';

  // Admin Routes
  static const String adminDashboard = '/admin/dashboard';

  // Tanod Routes
  static const String tanodDashboard = '/tanod/dashboard';
  static const String pendingUsers = '/admin/pending-users';
  static const String pendingRequests = '/admin/pending-requests';
  static const String pendingPayments = '/admin/pending-payments';
  static const String pendingReviews = '/admin/pending-reviews';
  static const String allRequests = '/admin/all-requests';
  static const String settings = '/admin/settings';
  static const String documentFees = '/admin/document-fees';
  static const String documentFormats = '/admin/document-formats';
  static const String captainApproval = '/admin/captain-approval';
  static const String adminProfile = '/admin/profile';

  static Map<String, WidgetBuilder> get routes {
    return {
      splash: (context) => const SplashScreen(),
      login: (context) => const LoginScreen(),
      register: (context) => const RegisterScreen(),
      pendingApproval: (context) => const PendingApprovalScreen(),
      citizenDashboard: (context) => const CitizenDashboardScreen(),
      requestDocument: (context) => const RequestDocumentScreen(),
      myRequests: (context) => const MyRequestsScreen(),
      myReports: (context) => const MyReportsScreen(),
      notifications: (context) => const NotificationsScreen(),
      submitReport: (context) => const SubmitReportScreen(),
      profile: (context) => const ProfileScreen(),
      incidentReports: (context) => const IncidentReportsScreen(),
      verifyDocument: (context) => const VerifyDocumentScreen(),
      adminDashboard: (context) => const admin.AdminDashboardScreen(),
      tanodDashboard: (context) => const tanod.TanodDashboardScreen(),
      pendingUsers: (context) => const ManageUsersScreen(),
      pendingRequests: (context) => const PendingRequestsScreen(),
      pendingPayments: (context) => const PendingPaymentsScreen(),
      settings: (context) => const AdminSettingsScreen(),
      allRequests: (context) => const AllRequestsScreen(),
      documentFees: (context) => const DocumentFeesScreen(),
      documentFormats: (context) => const DocumentFormatsScreen(),
      captainApproval: (context) => const CaptainApprovalScreen(),
      adminProfile: (context) => const AdminProfileScreen(),
    };
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (context) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (context) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (context) => const RegisterScreen());
      case pendingApproval:
        return MaterialPageRoute(
          builder: (context) => const PendingApprovalScreen(),
        );
      case citizenDashboard:
        return MaterialPageRoute(
          builder: (context) => const CitizenDashboardScreen(),
        );
      case requestDocument:
        return MaterialPageRoute(
          builder: (context) => const RequestDocumentScreen(),
        );
      case myRequests:
        return MaterialPageRoute(
          builder: (context) => const MyRequestsScreen(),
        );
      case myReports:
        return MaterialPageRoute(builder: (context) => const MyReportsScreen());
      case citizenIncidentDetail:
        // Opened with `arguments: IncidentReport`. Anything else (a stray
        // deep link, say) degrades to a plain error page instead of crashing.
        final detailReport = settings.arguments;
        return MaterialPageRoute(
          builder: (context) {
            if (detailReport is IncidentReport) {
              return CitizenIncidentReportDetailScreen(report: detailReport);
            }
            final l10n = AppLocalizations.of(context);
            return Scaffold(
              appBar: AppBar(title: Text(l10n.tdetTitle)),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.citizenLoadReportsError,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
        );
      case notifications:
        return MaterialPageRoute(
          builder: (context) => const NotificationsScreen(),
        );
      case submitReport:
        return MaterialPageRoute(
          builder: (context) => const SubmitReportScreen(),
        );
      case profile:
        return MaterialPageRoute(builder: (context) => const ProfileScreen());
      case eReceipt:
        final args = settings.arguments as DocumentRequest?;
        return MaterialPageRoute(
          builder: (context) => EReceiptViewerScreen(request: args!),
        );
      case incidentReports:
        return MaterialPageRoute(
          builder: (context) => const IncidentReportsScreen(),
        );
      case verifyDocument:
        return MaterialPageRoute(
          builder: (context) => const VerifyDocumentScreen(),
        );
      case adminDashboard:
        return MaterialPageRoute(
          builder: (context) => const admin.AdminDashboardScreen(),
        );
      case tanodDashboard:
        return MaterialPageRoute(
          builder: (context) => const tanod.TanodDashboardScreen(),
        );
      case pendingUsers:
        return MaterialPageRoute(
          builder: (context) => const ManageUsersScreen(),
        );
      case pendingRequests:
        return MaterialPageRoute(
          builder: (context) => const PendingRequestsScreen(),
        );
      case pendingPayments:
        return MaterialPageRoute(
          builder: (context) => const PendingPaymentsScreen(),
        );
      case pendingReviews:
        return MaterialPageRoute(
          builder: (context) => const PendingRequestsScreen(),
        );
      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (context) => const AdminSettingsScreen(),
        );
      case AppRoutes.allRequests:
        return MaterialPageRoute(
          builder: (context) => const AllRequestsScreen(),
        );
      case AppRoutes.documentFees:
        return MaterialPageRoute(
          builder: (context) => const DocumentFeesScreen(),
        );
      case AppRoutes.documentFormats:
        return MaterialPageRoute(
          builder: (context) => const DocumentFormatsScreen(),
        );
      case AppRoutes.adminProfile:
        return MaterialPageRoute(
          builder: (context) => const AdminProfileScreen(),
        );
      default:
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
