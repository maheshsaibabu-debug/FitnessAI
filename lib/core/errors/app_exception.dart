/// Base for exceptions that repositories/engines throw deliberately (as
/// opposed to letting an unexpected exception propagate). Kept small and
/// closed so UI code can exhaustively handle the cases that matter instead
/// of pattern-matching on library-specific exception types.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A local database operation failed. This should be rare — Drift I/O
/// errors are the main source — and is always a bug or a corrupted disk,
/// never expected user-facing flow control.
final class LocalStorageException extends AppException {
  const LocalStorageException(super.message);
}

/// A remote (Supabase) call failed. Never thrown for "we're offline" —
/// that's just skipped, not an error — only for a call that was attempted
/// and failed (auth rejected, server error, malformed response).
final class RemoteException extends AppException {
  const RemoteException(super.message, {this.statusCode});
  final int? statusCode;
}

/// Input failed a domain validation rule (e.g. onboarding step submitted
/// with a missing required field).
final class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// The AI gateway is unreachable or returned an error. Callers must catch
/// this and fall back to the rule-based provider — never surface it
/// directly as "AI unavailable, try again" (see docs/AI_ARCHITECTURE.md).
final class AiProviderException extends AppException {
  const AiProviderException(super.message);
}
