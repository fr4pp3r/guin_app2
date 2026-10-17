import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:guin_app/models/emergency_hotline.dart';
import 'package:guin_app/providers/hotline_provider.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';

/// Form to add a new emergency hotline or edit an existing one.
///
/// Reached from the directory's FAB (add) or a card's edit action — both
/// gated by `AppRoles.canManageHotlines`. Submit stays disabled until name
/// and number have content; success pops with `true` so the directory shows
/// the success snackbar (a snackbar shown here would die with this route).
class HotlineEditScreen extends StatefulWidget {
  final EmergencyHotline? existing;

  const HotlineEditScreen({super.key, this.existing});

  @override
  State<HotlineEditScreen> createState() => _HotlineEditScreenState();
}

class _HotlineEditScreenState extends State<HotlineEditScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isActive = true;
  bool _busy = false;
  bool _canSubmit = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _numberController.text = existing.number;
      _descriptionController.text = existing.description ?? '';
      _isActive = existing.isActive;
    }
    _nameController.addListener(_validate);
    _numberController.addListener(_validate);
    _validate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _validate() {
    final canSubmit =
        _nameController.text.trim().isNotEmpty &&
        _numberController.text.trim().isNotEmpty;
    if (canSubmit != _canSubmit) {
      setState(() => _canSubmit = canSubmit);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit || _busy) return;
    setState(() => _busy = true);

    final provider = context.read<HotlineProvider>();
    final ok = _isEdit
        ? await provider.updateHotline(
            id: widget.existing!.id,
            name: _nameController.text.trim(),
            number: _numberController.text.trim(),
            description: _descriptionController.text.trim(),
            isActive: _isActive,
          )
        : await provider.createHotline(
            name: _nameController.text.trim(),
            number: _numberController.text.trim(),
            description: _descriptionController.text.trim(),
            isActive: _isActive,
          );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _busy = false);
      Helpers.showErrorSnackBar(
        context,
        Helpers.parseSupabaseError(provider.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: Text(
          _isEdit ? l10n.hotlineEditTitle : l10n.hotlineAddTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFD32F2F), Color(0xFFC62828)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _canSubmit && !_busy ? _submit : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white54,
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      l10n.commonSave,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.07),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.hotlineNameLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    maxLength: 80,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: l10n.hotlineNameHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.hotlineNumberLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _numberController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    maxLength: 30,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: l10n.hotlineNumberHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.hotlineDescLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    maxLength: 200,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: l10n.hotlineDescHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Switch(
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.hotlineActiveLabel,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.hotlineActiveBody,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _canSubmit
                ? l10n.hotlineReadyToSave
                : l10n.hotlineNameNumberRequired,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
