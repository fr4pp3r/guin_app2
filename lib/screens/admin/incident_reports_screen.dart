import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/models/incident_report.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/incident_report_provider.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';

class IncidentReportsScreen extends StatefulWidget {
  const IncidentReportsScreen({super.key});

  @override
  State<IncidentReportsScreen> createState() => _IncidentReportsScreenState();
}

class _IncidentReportsScreenState extends State<IncidentReportsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => context.read<IncidentReportProvider>().loadAllReports(),
    );
  }

  Future<void> _setStatus(IncidentReport report, String status) async {
    final user = context.read<AuthProvider>().userProfile;
    if (user == null) return;
    await context.read<IncidentReportProvider>().updateStatus(
      reportId: report.id,
      updatedBy: user.id,
      newStatus: status,
      remarks: 'Updated from mobile dashboard',
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'received':
        return Colors.blueGrey;
      case 'under_assessment':
        return AppColors.warning;
      case 'in_progress':
        return AppColors.primary;
      case 'endorsed':
        return Colors.indigo;
      case 'resolved':
        return AppColors.success;
      case 'closed':
        return Colors.grey;
      case 'dismissed':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'low':
        return Colors.green;
      case 'medium':
        return AppColors.warning;
      case 'high':
        return Colors.orange;
      case 'urgent':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'received':
        return Icons.inbox_outlined;
      case 'under_assessment':
        return Icons.manage_search_outlined;
      case 'in_progress':
        return Icons.construction_outlined;
      case 'endorsed':
        return Icons.forward_outlined;
      case 'resolved':
        return Icons.check_circle_outline;
      case 'closed':
        return Icons.lock_outline;
      case 'dismissed':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Gradient header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFB71C1C),
                  Color(0xFFE53935),
                  Color(0xFFEF9A9A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.assignment_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.aincTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            l10n.aincSubtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Body
          Expanded(
            child: Consumer<IncidentReportProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading)
                  return const Center(child: CircularProgressIndicator());

                if (provider.reports.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: provider.loadAllReports,
                    child: ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.assignment_outlined,
                                  size: 64,
                                  color: Colors.grey.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.aincNoReports,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: provider.loadAllReports,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    itemCount: provider.reports.length,
                    itemBuilder: (context, index) {
                      final report = provider.reports[index];
                      final statusColor = _statusColor(report.status);
                      final priorityColor = _priorityColor(report.priority);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _statusIcon(report.status),
                                      color: statusColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          report.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              report.reportType
                                                  .replaceAll('_', ' ')
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondary,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 4,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: priorityColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              report.priority.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: priorityColor,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Status chip + popup menu
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Text(
                                          report.status.replaceAll('_', ' '),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(
                                          Icons.more_vert,
                                          size: 20,
                                          color: AppColors.textSecondary,
                                        ),
                                        onSelected: (v) =>
                                            _setStatus(report, v),
                                        itemBuilder: (_) => [
                                          PopupMenuItem(
                                            value: 'received',
                                            child: Text(l10n.aincMarkReceived),
                                          ),
                                          PopupMenuItem(
                                            value: 'under_assessment',
                                            child:
                                                Text(l10n.aincUnderAssessment),
                                          ),
                                          PopupMenuItem(
                                            value: 'endorsed',
                                            child: Text(
                                              l10n.aincEndorseEscalate,
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'in_progress',
                                            child: Text(l10n.aincInProgress),
                                          ),
                                          PopupMenuItem(
                                            value: 'resolved',
                                            child: Text(l10n.aincResolve),
                                          ),
                                          PopupMenuItem(
                                            value: 'closed',
                                            child: Text(l10n.aincClose),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Details
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                10,
                                16,
                                14,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _infoRow(
                                    Icons.location_on_outlined,
                                    report.location,
                                  ),
                                  const SizedBox(height: 4),
                                  _infoRow(
                                    Icons.access_time_outlined,
                                    Helpers.formatDateTime(report.createdAt),
                                  ),
                                  if (report.isAnonymous ||
                                      report.isSensitive) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      children: [
                                        if (report.isAnonymous)
                                          _badge(
                                            l10n.commonAnonymous,
                                            Colors.purple,
                                          ),
                                        if (report.isSensitive)
                                          _badge(
                                            l10n.commonSensitive,
                                            Colors.orange,
                                          ),
                                      ],
                                    ),
                                  ],
                                  if (report.description.isNotEmpty) ...[
                                    const Divider(height: 14),
                                    Text(
                                      report.description,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
