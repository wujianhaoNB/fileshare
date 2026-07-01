import 'package:flutter/material.dart';
import 'app_exception.dart';

/// Global error handler that converts exceptions to user-friendly messages.
class ErrorHandler {
  ErrorHandler._();

  /// Show an error snackbar in the given context.
  static void showError(BuildContext context, Object error) {
    final message = getUserMessage(error);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Theme.of(context).colorScheme.onError,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  /// Convert any exception to a user-facing message.
  static String getUserMessage(Object error) {
    if (error is AppException) {
      return error.userMessage;
    }
    if (error is Exception) {
      return error.toString();
    }
    return 'An unexpected error occurred.';
  }

  /// Log the technical details of an error for debugging.
  static String getTechnicalMessage(Object error) {
    if (error is AppException) {
      return error.technicalMessage;
    }
    return error.toString();
  }
}
