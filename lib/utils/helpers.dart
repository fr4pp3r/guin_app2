import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:guin_app/l10n/app_l10n.dart';

class Helpers {
  static tz.Location? _phLocation;

  /// Initialize timezone support. Call once in main() before runApp.
  static void initialize() {
    tzdata.initializeTimeZones();
    _phLocation = tz.getLocation('Asia/Manila');
  }

  /// Get current time in PH timezone.
  static DateTime now() {
    if (_phLocation == null) return DateTime.now();
    return tz.TZDateTime.now(_phLocation!);
  }

  /// Convert any DateTime to PH timezone.
  static DateTime toPh(DateTime dt) {
    if (_phLocation == null) return dt;
    return tz.TZDateTime.from(dt, _phLocation!);
  }

  // Show snackbar
  static void showSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Show success snackbar
  static void showSuccessSnackBar(BuildContext context, String message) {
    showSnackBar(context, message, backgroundColor: Colors.green);
  }

  // Show error snackbar
  static void showErrorSnackBar(BuildContext context, String message) {
    showSnackBar(context, message, backgroundColor: Colors.red);
  }

  // Show loading dialog
  static void showLoadingDialog(BuildContext context, [String? message]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  message ?? AppL10n.current.splashLoading,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dismiss loading dialog
  static void dismissDialog(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  // Show confirmation dialog
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              cancelText == 'Cancel'
                  ? AppL10n.current.commonCancel
                  : cancelText,
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText == 'Confirm'
                  ? AppL10n.current.commonConfirm
                  : confirmText,
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // Format date
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(toPh(date));
  }

  // Format date with time
  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy hh:mm a').format(toPh(date));
  }

  // Format time ago
  static String timeAgo(DateTime date) {
    final now = (_phLocation == null) ? DateTime.now() : tz.TZDateTime.now(_phLocation!);
    final phDate = toPh(date);
    final difference = now.difference(phDate);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return AppL10n.current.utilYearsAgo(years);
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return AppL10n.current.utilMonthsAgo(months);
    } else if (difference.inDays > 0) {
      return AppL10n.current.utilDaysAgo(difference.inDays);
    } else if (difference.inHours > 0) {
      return AppL10n.current.utilHoursAgo(difference.inHours);
    } else if (difference.inMinutes > 0) {
      return AppL10n.current.utilMinutesAgo(difference.inMinutes);
    } else {
      return AppL10n.current.utilJustNow;
    }
  }

  // Parse Supabase error
  static String parseSupabaseError(dynamic error) {
    if (error == null) return AppL10n.current.utilErrorUnknown;

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('duplicate key')) {
      if (errorString.contains('username')) {
        return AppL10n.current.utilErrorUsernameExists;
      }
      if (errorString.contains('email')) {
        return AppL10n.current.utilErrorEmailExists;
      }
      return AppL10n.current.utilErrorRecordExists;
    }

    if (errorString.contains('invalid email')) {
      return AppL10n.current.utilErrorEmailInvalid;
    }

    if (errorString.contains('password')) {
      return AppL10n.current.utilErrorPasswordInvalid;
    }

    // Offline / connectivity failures surface in several shapes
    // (SocketException, ClientException, "Failed host lookup", timeouts) but
    // mean the same thing to the user.
    if (errorString.contains('socketexception') ||
        errorString.contains('clientexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('unable to resolve host') ||
        errorString.contains('connection') ||
        errorString.contains('network') ||
        errorString.contains('timeout')) {
      return AppL10n.current.utilErrorOffline;
    }

    if (errorString.contains('unauthorized') ||
        errorString.contains('not authorized')) {
      return AppL10n.current.utilErrorUnauthorized;
    }

    // Missing Supabase Storage bucket surfaces as a 404 "Record not found",
    // which is indistinguishable from a missing DB row by keyword alone. Pass
    // the actionable setup hint through instead of collapsing it to the
    // generic "Record not found" string.
    if (errorString.contains('storage bucket')) {
      final raw = error.toString();
      final index = raw.indexOf('Storage bucket');
      return index >= 0 ? raw.substring(index) : raw;
    }

    if (errorString.contains('not found')) {
      return AppL10n.current.utilErrorNotFound;
    }

    if (errorString.contains('user already registered')) {
      return AppL10n.current.utilErrorEmailRegistered;
    }

    return AppL10n.current.utilErrorGeneric;
  }

  // Validate file size (in MB)
  static bool isFileSizeValid(int bytes, {int maxSizeMB = 5}) {
    final sizeMB = bytes / (1024 * 1024);
    return sizeMB <= maxSizeMB;
  }

  // Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return AppL10n.current.utilSizeBytes(bytes);
    } else if (bytes < 1024 * 1024) {
      return AppL10n.current.utilSizeKB((bytes / 1024).toStringAsFixed(2));
    } else {
      return AppL10n.current.utilSizeMB(
        (bytes / (1024 * 1024)).toStringAsFixed(2),
      );
    }
  }

  // Get initials from name
  static String getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  // Capitalize first letter
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // Capitalize each word
  static String capitalizeWords(String text) {
    return text.split(' ').map((word) => capitalize(word)).join(' ');
  }
}
