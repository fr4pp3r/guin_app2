import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Helpers {
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
              Text(message ?? 'Loading...'),
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
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // Format date
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  // Format date with time
  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy hh:mm a').format(date);
  }

  // Format time ago
  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  // Parse Supabase error
  static String parseSupabaseError(dynamic error) {
    if (error == null) return 'An unknown error occurred';

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('duplicate key')) {
      if (errorString.contains('username')) {
        return 'Username already exists';
      }
      if (errorString.contains('email')) {
        return 'Email already exists';
      }
      return 'This record already exists';
    }

    if (errorString.contains('invalid email')) {
      return 'Invalid email address';
    }

    if (errorString.contains('password')) {
      return 'Invalid password. Must be at least 6 characters';
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
      return 'You appear to be offline. Check your connection and try again';
    }

    if (errorString.contains('unauthorized') ||
        errorString.contains('not authorized')) {
      return 'You are not authorized to perform this action';
    }

    if (errorString.contains('not found')) {
      return 'Record not found';
    }

    if (errorString.contains('user already registered')) {
      return 'This email is already registered';
    }

    return 'An error occurred. Please try again';
  }

  // Validate file size (in MB)
  static bool isFileSizeValid(int bytes, {int maxSizeMB = 5}) {
    final sizeMB = bytes / (1024 * 1024);
    return sizeMB <= maxSizeMB;
  }

  // Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
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
