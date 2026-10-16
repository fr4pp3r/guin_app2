import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:guin_app/models/incident_report.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/incident_report_provider.dart';
import 'package:guin_app/screens/tanod/incident_visuals.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/utils/role_access.dart';

/// Full view of one incident report for field officers.
///
/// Shows everything the triage cards compress (description, incident time,
/// report number) and lets any official with `canManageReports` move the
/// report through the status workflow via `IncidentReportProvider.updateStatus`
/// — the only write this screen performs. Reporter identity is never shown;
/// anonymity / sensitivity are surfaced as badges only (see
/// `AppRoles.canRevealSensitiveReporter`, which is captain/admin-only).
class IncidentDetailScreen extends StatefulWidget {
  final IncidentReport report;

  const IncidentDetailScreen({super.key, required this.report});

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  bool _isUpdating = false;

  Future<void> _applyStatus(IncidentReport report, String newStatus) async {
    final l10n = AppLocalizations.of(context);
    final user = context.read<AuthProvider>().userProfile;
    if (user == null || newStatus == report.status) return;

    setState(() => _isUpdating = true);
    try {
      await context.read<IncidentReportProvider>().updateStatus(
        reportId: report.id,
        updatedBy: user.id,
        newStatus: newStatus,
        remarks: l10n.tdashUpdateStatusRemark,
      );
      if (!mounted) return;
      setState(() => _isUpdating = false);
      Helpers.showSuccessSnackBar(context, l10n.tdashStatusUpdated);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      Helpers.showErrorSnackBar(context, l10n.tdashStatusUpdateFailed);
    }
  }

  void _openStatusSheet(IncidentReport report, AppLocalizations l10n) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.tdashUpdateStatusTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.tdashUpdateStatusHint,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ...IncidentVisuals.actionableStatuses.map((status) {
                  final color = IncidentVisuals.statusColor(status);
                  final isCurrent = status == report.status;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        IncidentVisuals.statusIcon(status),
                        color: color,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      IncidentVisuals.statusLabel(l10n, status),
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    trailing: isCurrent
                        ? Icon(Icons.check_circle, color: color, size: 20)
                        : Icon(Icons.chevron_right, color: Colors.grey[400]),
                    onTap: isCurrent
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            _applyStatus(report, status);
                          },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final role = context.watch<AuthProvider>().userProfile?.role ?? '';
    final canUpdate = AppRoles.canManageReports(role);

    // The provider reloads every report after updateStatus — prefer the fresh
    // copy so the header chips flip immediately.
    final reports = context.watch<IncidentReportProvider>().reports;
    final report = reports.firstWhere(
      (r) => r.id == widget.report.id,
      orElse: () => widget.report,
    );

    final statusColor = IncidentVisuals.statusColor(report.status);
    final priorityColor = IncidentVisuals.priorityColor(report.priority);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        title: Text(
          l10n.tdetTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D3B66), Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Title card: report number, title, priority + status chips ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        IncidentVisuals.statusIcon(report.status),
                        color: statusColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        IncidentVisuals.reportNumber(report),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    report.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(
                        IncidentVisuals.priorityLabel(l10n, report.priority),
                        priorityColor,
                        Icons.flag_outlined,
                      ),
                      _chip(
                        IncidentVisuals.statusLabel(l10n, report.status),
                        statusColor,
                        IncidentVisuals.statusIcon(report.status),
                      ),
                      if (report.isAnonymous)
                        _chip(l10n.commonAnonymous, Colors.purple, Icons.hide_source_outlined),
                      if (report.isSensitive)
                        _chip(l10n.commonSensitive, const Color(0xFFEF6C00), Icons.visibility_off_outlined),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Details ──
          _sectionCard(
            children: [
              _detailRow(
                Icons.category_outlined,
                l10n.reportTypeLabel,
                IncidentVisuals.typeLabel(l10n, report.reportType),
              ),
              _detailRow(
                Icons.location_on_outlined,
                l10n.reportLocationLabel,
                report.location,
              ),
              _detailRow(
                Icons.event_outlined,
                l10n.tdetIncidentDate,
                Helpers.formatDateTime(report.incidentDateTime),
              ),
              _detailRow(
                Icons.access_time_outlined,
                l10n.tdetReportedAt,
                '${Helpers.timeAgo(report.createdAt)} · ${Helpers.formatDateTime(report.createdAt)}',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Description ──
          _sectionCard(
            children: [
              Text(
                l10n.reportDescriptionLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                report.description.isNotEmpty
                    ? report.description
                    : l10n.tdetNoDescription,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: canUpdate
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating
                      ? null
                      : () => _openStatusSheet(report, l10n),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF1976D2).withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  icon: _isUpdating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.swap_horiz_rounded, size: 20),
                  label: Text(
                    l10n.tdashUpdateStatusTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _chip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
