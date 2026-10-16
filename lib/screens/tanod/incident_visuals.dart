import 'package:flutter/material.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:guin_app/models/incident_report.dart';
import 'package:guin_app/utils/constants.dart';

/// Status / priority visuals shared by the tanod incident screens.
///
/// Uses **only** the real DB values from `setup.sql`'s CHECK constraints:
/// statuses `submitted | received | under_assessment | endorsed | in_progress |
/// resolved | closed | rejected`, priorities `low | normal | high | urgent`.
/// (Deliberately avoids the `dismissed` / `medium` values that older screens
/// still reference — those are not written by anything.)
class IncidentVisuals {
  const IncidentVisuals._();

  /// The terminal statuses that mean an incident no longer needs action.
  static const Set<String> _terminalStatuses = {'resolved', 'closed', 'rejected'};

  /// Statuses a tanod may move a report to, in workflow order. Mirrors the
  /// menu in `IncidentReportsScreen` and the DB CHECK constraint.
  static const List<String> actionableStatuses = [
    'received',
    'under_assessment',
    'endorsed',
    'in_progress',
    'resolved',
    'closed',
  ];

  /// Open = not yet resolved, closed, or rejected.
  static bool isOpen(String status) => !_terminalStatuses.contains(status);

  /// Sort key: urgent first, then high, normal, low, unknown last.
  static int priorityRank(String priority) {
    switch (priority) {
      case 'urgent':
        return 0;
      case 'high':
        return 1;
      case 'normal':
        return 2;
      case 'low':
        return 3;
      default:
        return 4;
    }
  }

  static Color priorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return AppColors.error;
      case 'high':
        return const Color(0xFFF4511E); // deep orange, distinct from amber
      case 'normal':
        return AppColors.primary;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'submitted':
        return AppColors.accent; // new, not yet acknowledged
      case 'received':
        return Colors.blueGrey;
      case 'under_assessment':
        return AppColors.warning;
      case 'endorsed':
        return Colors.indigo;
      case 'in_progress':
        return AppColors.primary;
      case 'resolved':
        return AppColors.success;
      case 'closed':
        return Colors.grey;
      case 'rejected':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  static IconData statusIcon(String status) {
    switch (status) {
      case 'submitted':
        return Icons.outbox_outlined;
      case 'received':
        return Icons.inbox_outlined;
      case 'under_assessment':
        return Icons.manage_search_outlined;
      case 'endorsed':
        return Icons.forward_outlined;
      case 'in_progress':
        return Icons.construction_outlined;
      case 'resolved':
        return Icons.check_circle_outline;
      case 'closed':
        return Icons.lock_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  static String statusLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case 'submitted':
        return l10n.tdashStatusSubmitted;
      case 'received':
        return l10n.tdashStatusReceived;
      case 'under_assessment':
        return l10n.tdashStatusUnderAssessment;
      case 'endorsed':
        return l10n.tdashStatusEndorsed;
      case 'in_progress':
        return l10n.tdashStatusInProgress;
      case 'resolved':
        return l10n.tdashStatusResolved;
      case 'closed':
        return l10n.tdashStatusClosed;
      case 'rejected':
        return l10n.tdashStatusRejected;
      default:
        return status;
    }
  }

  static String priorityLabel(AppLocalizations l10n, String priority) {
    switch (priority) {
      case 'urgent':
        return l10n.tdashPriorityUrgent;
      case 'high':
        return l10n.tdashPriorityHigh;
      case 'normal':
        return l10n.tdashPriorityNormal;
      case 'low':
        return l10n.tdashPriorityLow;
      default:
        return priority;
    }
  }

  static String typeLabel(AppLocalizations l10n, String reportType) {
    switch (reportType) {
      case 'complaint':
        return l10n.reportTypeComplaint;
      case 'disturbance':
        return l10n.reportTypeDisturbance;
      case 'threat':
        return l10n.reportTypeThreat;
      case 'emergency':
        return l10n.reportTypeEmergency;
      case 'other':
        return l10n.commonOther;
      default:
        return reportType;
    }
  }

  /// Fallback display for a missing report number (older rows may be null).
  static String reportNumber(IncidentReport report) =>
      (report.reportNumber == null || report.reportNumber!.isEmpty)
      ? '—'
      : report.reportNumber!;
}
