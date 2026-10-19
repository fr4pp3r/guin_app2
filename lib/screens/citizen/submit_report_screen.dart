import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/incident_report_provider.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:guin_app/services/ai_incident_classifier.dart';
import 'package:guin_app/services/ai_incident_reviewer.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';
import 'package:guin_app/widgets/incident_location_picker.dart';

class SubmitReportScreen extends StatefulWidget {
  const SubmitReportScreen({super.key});

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  String _reportType = 'complaint';
  String _priority = 'normal';
  bool _isSensitive = false;
  bool _isAnonymous = false;
  bool _isSubmitting = false;
  IncidentSuggestion? _aiSuggestion;
  IncidentReview? _aiReview;
  bool _aiClassifying = false;
  bool _aiReviewing = false;
  bool _aiSuggestionApplied = false;
  final _aiClassifier = AiIncidentClassifier();
  final _aiReviewer = AiIncidentReviewer();
  LatLng? _pickedPin;
  bool _isLocating = false;
  final _pickerKey = GlobalKey<LocationPinPickerState>();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _suggestWithAi() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reportTypeDescriptionFirst)),
      );
      return;
    }
    setState(() {
      _aiClassifying = true;
      _aiReviewing = true;
    });
    try {
      final suggestionFuture = _aiClassifier.suggest(title, description);
      final reviewFuture = _aiReviewer.review(
        title: title,
        description: description,
        location: _locationController.text.trim(),
        reportType: _reportType,
        priority: _priority,
        isSensitive: _isSensitive,
        isAnonymous: _isAnonymous,
      );
      final results = await Future.wait([suggestionFuture, reviewFuture]);
      final suggestion = results[0] as IncidentSuggestion?;
      final review = results[1] as IncidentReview?;
      if (!mounted) return;
      setState(() {
        _aiSuggestion = suggestion;
        if (suggestion != null) {
          _reportType = suggestion.reportType;
          _priority = suggestion.priority;
          _aiSuggestionApplied = true;
        } else {
          _aiSuggestionApplied = false;
        }
        _aiReview = review;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiSuggestion = null;
        _aiReview = null;
        _aiSuggestionApplied = false;
      });
    } finally {
      if (mounted) setState(() {
        _aiClassifying = false;
        _aiReviewing = false;
      });
    }
  }

  Future<void> _useMyLocation() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isLocating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.reportMapServicesOff)),
        );
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.reportMapLocationDenied)),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      // setPin updates the parent's _pickedPin via onPinChanged and
      // recenters the map on the found position.
      _pickerKey.currentState?.setPin(
        LatLng(position.latitude, position.longitude),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reportMapLocationDenied)),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthProvider>().userProfile;
    if (user == null) return;
    setState(() => _isSubmitting = true);
    try {
      await context.read<IncidentReportProvider>().submitReport(
        submittedBy: user.id,
        reportType: _reportType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        incidentDateTime: Helpers.now(),
        isSensitive: _isSensitive,
        isAnonymous: _isAnonymous,
        priority: _priority,
        latitude: _pickedPin?.latitude,
        longitude: _pickedPin?.longitude,
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.reportSubmittedSuccess),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Helpers.parseSupabaseError(e)), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'low':
        return Colors.green;
      case 'high':
        return Colors.orange;
      case 'urgent':
        return Colors.red;
      default:
        return AppColors.primary;
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
                  Color(0xFFE53935),
                  Color(0xFFEF5350),
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
                      Icons.report_problem_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.reportTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            l10n.reportSubtitle,
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

          // Form
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                children: [
                  // Report type & priority row
                  _sectionLabel(l10n.reportSectionDetails),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _reportType,
                          // Let the selected item share the field width so a
                          // long label ellipsizes instead of overflowing the
                          // internal Row (prefix icon + item + arrow).
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l10n.reportTypeLabel,
                            prefixIcon: const Icon(Icons.category_outlined),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'complaint',
                              child: Text(
                                l10n.reportTypeComplaint,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'disturbance',
                              child: Text(
                                l10n.reportTypeDisturbance,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'threat',
                              child: Text(
                                l10n.reportTypeThreat,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'emergency',
                              child: Text(
                                l10n.reportTypeEmergency,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text(
                                l10n.commonOther,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _reportType = v!;
                              _aiSuggestionApplied = false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _priority,
                          // Same as the type dropdown: keep the selected item
                          // inside the field bounds on narrow screens.
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l10n.reportPriorityLabel,
                            prefixIcon: Icon(
                              Icons.flag_outlined,
                              color: _priorityColor(_priority),
                            ),
                          ),
                          items: [
                            _priorityItem(
                              'low',
                              l10n.reportPriorityLow,
                              Colors.green,
                            ),
                            _priorityItem(
                              'normal',
                              l10n.reportPriorityNormal,
                              AppColors.primary,
                            ),
                            _priorityItem(
                              'high',
                              l10n.reportPriorityHigh,
                              Colors.orange,
                            ),
                            _priorityItem(
                              'urgent',
                              l10n.reportPriorityUrgent,
                              Colors.red,
                            ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _priority = v!;
                              _aiSuggestionApplied = false;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: (_aiClassifying || _isSubmitting)
                            ? null
                            : _suggestWithAi,
                        icon: _aiClassifying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(l10n.reportAiSuggestCategory),
                      ),
                    ],
                  ),
                  if (_aiSuggestionApplied && _aiSuggestion != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.reportAiSuggestedNote,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: l10n.reportIncidentTitleLabel,
                      prefixIcon: const Icon(Icons.title),
                      hintText: l10n.reportIncidentTitleHint,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.reportTitleRequired
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: l10n.reportLocationLabel,
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      hintText: l10n.reportLocationHint,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.reportLocationRequired
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Optional map pin
                  _sectionLabel(l10n.reportMapSectionTitle),
                  const SizedBox(height: 8),
                  Text(
                    _pickedPin == null
                        ? l10n.reportMapPinHint
                        : '${_pickedPin!.latitude.toStringAsFixed(5)}, '
                            '${_pickedPin!.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 240,
                          child: LocationPinPicker(
                            key: _pickerKey,
                            initial: _pickedPin,
                            onPinChanged: (point) =>
                                setState(() => _pickedPin = point),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          // Wrap (not Row) so the buttons flow onto a second
                          // line on narrow phones instead of overflowing.
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    _isLocating ? null : _useMyLocation,
                                icon: _isLocating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.my_location, size: 18),
                                label: Text(
                                  _isLocating
                                      ? l10n.reportMapGettingLocation
                                      : l10n.reportMapUseMyLocation,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_pickedPin != null)
                                TextButton.icon(
                                  onPressed: () =>
                                      _pickerKey.currentState?.clearPin(),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  label: Text(
                                    l10n.reportMapRemovePin,
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: l10n.reportDescriptionLabel,
                      prefixIcon: const Icon(Icons.description_outlined),
                      hintText: l10n.reportDescriptionHint,
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.reportDescriptionRequired
                        : null,
                  ),
                  const SizedBox(height: 24),

                  // Privacy options
                  _sectionLabel(l10n.reportSectionPrivacy),
                  const SizedBox(height: 8),
                  _optionTile(
                    icon: Icons.lock_outlined,
                    iconColor: Colors.orange,
                    title: l10n.reportMarkSensitive,
                    subtitle: l10n.reportMarkSensitiveSubtitle,
                    value: _isSensitive,
                    onChanged: (v) => setState(() => _isSensitive = v),
                  ),
                  const SizedBox(height: 8),
                  _optionTile(
                    icon: Icons.visibility_off_outlined,
                    iconColor: Colors.purple,
                    title: l10n.reportSubmitAnonymously,
                    subtitle: l10n.reportSubmitAnonymouslySubtitle,
                    value: _isAnonymous,
                    onChanged: (v) => setState(() => _isAnonymous = v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(
              _isSubmitting ? l10n.reportSubmitting : l10n.reportSubmitButton,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
          ),
        ),
      ),
    );
  }

  DropdownMenuItem<String> _priorityItem(
    String value,
    String label,
    Color color,
  ) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          // Flexible so the label ellipsizes when isExpanded constrains the
          // selected item on narrow screens.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _optionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Color _riskColor(String level) {
    switch (level.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'moderate':
        return Colors.amber;
      case 'low':
        return Colors.green;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _escalationColor(String v) {
    switch (v.toLowerCase()) {
      case 'yes':
        return Colors.red;
      case 'review':
        return Colors.orange;
      case 'no':
        return Colors.green;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildReviewChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: ${value.isNotEmpty ? value[0].toUpperCase() + value.substring(1) : value}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
