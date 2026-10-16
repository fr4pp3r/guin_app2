import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:guin_app/l10n/generated/app_localizations.dart';
import 'package:guin_app/providers/announcement_provider.dart';
import 'package:guin_app/utils/constants.dart';
import 'package:guin_app/utils/helpers.dart';

/// Form for officials to post a new barangay announcement.
///
/// Reached from the feed's FAB, which is itself gated by
/// `AppRoles.canPostAnnouncements`. Submit stays disabled until both fields
/// have content; success pops with `true` so the feed shows the success
/// snackbar (a snackbar shown here would die with this route).
class CreateAnnouncementScreen extends StatefulWidget {
  const CreateAnnouncementScreen({super.key});

  @override
  State<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  bool _pinned = false;
  bool _busy = false;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_validate);
    _bodyController.addListener(_validate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _validate() {
    final canSubmit =
        _titleController.text.trim().isNotEmpty &&
        _bodyController.text.trim().isNotEmpty;
    if (canSubmit != _canSubmit) {
      setState(() => _canSubmit = canSubmit);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit || _busy) return;
    setState(() => _busy = true);

    final provider = context.read<AnnouncementProvider>();
    final ok = await provider.createAnnouncement(
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      isPinned: _pinned,
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
          l10n.annCreateTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
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
                      l10n.annPost,
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
                    l10n.annTitleLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    maxLength: 120,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: l10n.annTitleHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.annBodyLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bodyController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 5,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: l10n.annBodyHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Switch(
                        value: _pinned,
                        onChanged: (value) => setState(() => _pinned = value),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.annPinToTop,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.annPinToTopBody,
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
                ? l10n.annReadyToPost
                : l10n.annTitleBodyRequired,
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
