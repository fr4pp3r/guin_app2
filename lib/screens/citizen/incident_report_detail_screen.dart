import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:guin_app/models/incident_report.dart';
import 'package:guin_app/providers/incident_report_provider.dart';
import 'package:guin_app/screens/tanod/incident_visuals.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/widgets/incident_location_map.dart';

/// Read-only, citizen-facing view of one of *their own* incident reports.
///
/// Opened from `MyReportsScreen` as the separate page for looking at a single
/// report in full: report number, incident time, complete description, the
/// pinned map spot (via the shared `IncidentLocationMap` / `IncidentCoordinatesRow`
/// widgets) and a plain-language progress strip so the reporter can see where
/// their report sits in the workflow.
///
/// Deliberately performs **no writes** — status changes stay with officials
/// (`AppRoles.canManageReports` on the tanod detail screen). Reporter identity
/// is never rendered; anonymity / sensitivity appear as badges only.
class CitizenIncidentReportDetailScreen extends StatelessWidget {
  const CitizenIncidentReportDetailScreen({super.key, required this.report});

  /// The report as it looked when the list row was tapped. When the provider
  /// still holds this report, [build] prefers that fresher copy.
  final IncidentReport report;

  /// Maps a workflow status onto the 4-phase journey citizens track:
  /// Submitted → Under Assessment → In Progress → Resolved.
  ///
  /// Returns `null` for statuses outside that linear flow (`rejected`, and any
  /// legacy value) — callers hide the strip instead of implying progress.
  static int? phaseOf(String status) {
    switch (status) {
      case 'submitted':
        return 0;
      case 'received':
      case 'under_assessment':
        return 1;
      case 'endorsed':
      case 'in_progress':
        return 2;
      case 'resolved':
      case 'closed':
        return 3;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Prefer the provider's copy so a refresh triggered while this page is
    // open still lands here; fall back to the row we were opened with.
    final live = context.watch<IncidentReportProvider>().reports.firstWhere(
      (r) => r.id == report.id,
      orElse: () => report,
    );

    final statusColor = IncidentVisuals.statusColor(live.status);
    final priorityColor = IncidentVisuals.priorityColor(live.priority);
    final phase = phaseOf(live.status);

    final sections = <Widget>[
      _heroCard(live, l10n, statusColor, priorityColor),
      if (phase != null) _progressCard(l10n, phase, statusColor),
      _detailsCard(live, l10n),
      _mapCard(live, l10n),
      _descriptionCard(live, l10n),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.tdetTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (live.reportNumber != null && live.reportNumber!.isNotEmpty)
              Text(
                live.reportNumber!,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.6,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE53935), Color(0xFFEF5350)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          for (var i = 0; i < sections.length; i++) _reveal(i, sections[i]),
        ],
      ),
    );
  }

  /// Cheap staggered entrance: cards fade + rise in reading order once, on the
  /// frame they are first built (no controllers, no timers).
  Widget _reveal(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final t = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // ── Hero: icon, type, title, status / priority / badge chips ──
  Widget _heroCard(
    IncidentReport r,
    AppLocalizations l10n,
    Color statusColor,
    Color priorityColor,
  ) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: 'incident-status-${r.id}',
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    IncidentVisuals.statusIcon(r.status),
                    color: statusColor,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  IncidentVisuals.typeLabel(l10n, r.reportType),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            r.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                IncidentVisuals.statusLabel(l10n, r.status),
                statusColor,
                IncidentVisuals.statusIcon(r.status),
              ),
              _chip(
                IncidentVisuals.priorityLabel(l10n, r.priority),
                priorityColor,
                Icons.flag_outlined,
              ),
              if (r.isAnonymous)
                _chip(
                  l10n.commonAnonymous,
                  Colors.purple,
                  Icons.hide_source_outlined,
                ),
              if (r.isSensitive)
                _chip(
                  l10n.commonSensitive,
                  const Color(0xFFEF6C00),
                  Icons.visibility_off_outlined,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Progress strip: where this report sits in the workflow ──
  Widget _progressCard(AppLocalizations l10n, int phase, Color statusColor) {
    final labels = [
      l10n.tdashStatusSubmitted,
      l10n.tdashStatusUnderAssessment,
      l10n.tdashStatusInProgress,
      l10n.tdashStatusResolved,
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.commonStatus,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (i > 0)
                            _stepLine(phase >= i)
                          else
                            const Expanded(child: SizedBox(height: 2)),
                          _stepDot(i, phase, statusColor),
                          if (i < labels.length - 1)
                            _stepLine(phase >= i + 1)
                          else
                            const Expanded(child: SizedBox(height: 2)),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.25,
                          fontWeight: i == phase
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: i <= phase
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepLine(bool done) {
    return Expanded(
      child: Container(
        height: 2,
        decoration: BoxDecoration(
          color: done
              ? AppColors.success.withValues(alpha: 0.75)
              : Colors.grey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _stepDot(int index, int phase, Color statusColor) {
    const size = 22.0;
    if (index < phase) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 14, color: Colors.white),
      );
    }
    if (index == phase) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: statusColor, width: 2.5),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
    );
  }

  // ── Facts: type, location, incident date, reported at ──
  Widget _detailsCard(IncidentReport r, AppLocalizations l10n) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow(
            Icons.category_outlined,
            l10n.reportTypeLabel,
            IncidentVisuals.typeLabel(l10n, r.reportType),
          ),
          _detailRow(
            Icons.location_on_outlined,
            l10n.reportLocationLabel,
            r.location,
          ),
          _detailRow(
            Icons.event_outlined,
            l10n.tdetIncidentDate,
            Helpers.formatDateTime(r.incidentDateTime),
          ),
          _detailRow(
            Icons.access_time_outlined,
            l10n.tdetReportedAt,
            '${Helpers.timeAgo(r.createdAt)} · ${Helpers.formatDateTime(r.createdAt)}',
            last: true,
          ),
        ],
      ),
    );
  }

  // ── Pinned spot on the map (shared widget, same as the tanod view) ──
  Widget _mapCard(IncidentReport r, AppLocalizations l10n) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tdetMapTitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          IncidentLocationMap(
            latitude: r.latitude,
            longitude: r.longitude,
            height: 220,
            emptyText: l10n.tdetNoMapPin,
          ),
          if (r.latitude != null && r.longitude != null) ...[
            const SizedBox(height: 10),
            IncidentCoordinatesRow(
              label: l10n.tdetCoordinates,
              latitude: r.latitude!,
              longitude: r.longitude!,
            ),
          ],
        ],
      ),
    );
  }

  // ── Full description (the list only shows the first 3 lines) ──
  Widget _descriptionCard(IncidentReport r, AppLocalizations l10n) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.reportDescriptionLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            r.description.isNotEmpty ? r.description : l10n.tdetNoDescription,
            style: const TextStyle(fontSize: 14, height: 1.55),
          ),
        ],
      ),
    );
  }

  // ── Shared bits ──
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
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
      child: child,
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

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    bool last = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
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
