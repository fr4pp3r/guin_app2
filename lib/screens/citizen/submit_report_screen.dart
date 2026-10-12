import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/providers/auth_provider.dart';
import 'package:guin_app/providers/incident_report_provider.dart';
import 'package:guin_app/services/ai_incident_classifier.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';

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
  bool _aiClassifying = false;
  bool _aiSuggestionApplied = false;
  final _aiClassifier = AiIncidentClassifier();

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type a short description first')),
      );
      return;
    }
    setState(() => _aiClassifying = true);
    try {
      final suggestion = await _aiClassifier.suggest(title, description);
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
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiSuggestion = null;
        _aiSuggestionApplied = false;
      });
    } finally {
      if (mounted) setState(() => _aiClassifying = false);
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
        incidentDateTime: DateTime.now(),
        isSensitive: _isSensitive,
        isAnonymous: _isAnonymous,
        priority: _priority,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incident report submitted successfully'),
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Submit Incident Report',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Report an incident to Barangay Guion',
                            style: TextStyle(
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
                  _sectionLabel('Report Details'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _reportType,
                          decoration: const InputDecoration(
                            labelText: 'Type',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'complaint',
                              child: Text('Complaint'),
                            ),
                            DropdownMenuItem(
                              value: 'disturbance',
                              child: Text('Disturbance'),
                            ),
                            DropdownMenuItem(
                              value: 'threat',
                              child: Text('Threat'),
                            ),
                            DropdownMenuItem(
                              value: 'emergency',
                              child: Text('Emergency'),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('Other'),
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
                          decoration: InputDecoration(
                            labelText: 'Priority',
                            prefixIcon: Icon(
                              Icons.flag_outlined,
                              color: _priorityColor(_priority),
                            ),
                          ),
                          items: [
                            _priorityItem('low', 'Low', Colors.green),
                            _priorityItem(
                              'normal',
                              'Normal',
                              AppColors.primary,
                            ),
                            _priorityItem('high', 'High', Colors.orange),
                            _priorityItem('urgent', 'Urgent', Colors.red),
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
                        label: const Text('AI suggest category'),
                      ),
                    ],
                  ),
                  if (_aiSuggestionApplied && _aiSuggestion != null) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Category and priority suggested by AI — you can still change them.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Incident Title',
                      prefixIcon: Icon(Icons.title),
                      hintText: 'Brief, clear title',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      hintText: 'Where did this happen?',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Location is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description_outlined),
                      hintText: 'Describe the incident in detail...',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Description is required'
                        : null,
                  ),
                  const SizedBox(height: 24),

                  // Privacy options
                  _sectionLabel('Privacy Options'),
                  const SizedBox(height: 8),
                  _optionTile(
                    icon: Icons.lock_outlined,
                    iconColor: Colors.orange,
                    title: 'Mark as Sensitive',
                    subtitle:
                        'Use for threats or safety-risk reports requiring restricted access',
                    value: _isSensitive,
                    onChanged: (v) => setState(() => _isSensitive = v),
                  ),
                  const SizedBox(height: 8),
                  _optionTile(
                    icon: Icons.visibility_off_outlined,
                    iconColor: Colors.purple,
                    title: 'Submit Anonymously',
                    subtitle:
                        'Your identity is hidden; all access is audited by admin',
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
              _isSubmitting ? 'Submitting...' : 'Submit Report',
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
          Text(label),
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
}
