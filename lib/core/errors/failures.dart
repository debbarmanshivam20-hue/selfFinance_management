/// Application level error type.
///
/// Repositories translate low level exceptions (SQLite errors, IO errors,
/// malformed backup files) into a [AppFailure] carrying a message that is safe
/// to show a user - it never contains raw amounts, SQL, or file paths.
class AppFailure implements Exception {
  final String message;
  final AppFailureKind kind;

  /// Technical detail kept for local debugging only. It is never rendered in
  /// the UI and never written to logs in release mode.
  final Object? cause;

  const AppFailure(
    this.message, {
    this.kind = AppFailureKind.unknown,
    this.cause,
  });

  const AppFailure.database(this.message, {this.cause})
      : kind = AppFailureKind.database;

  const AppFailure.validation(this.message)
      : kind = AppFailureKind.validation,
        cause = null;

  const AppFailure.notFound(this.message)
      : kind = AppFailureKind.notFound,
        cause = null;

  const AppFailure.storage(this.message, {this.cause})
      : kind = AppFailureKind.storage;

  const AppFailure.backup(this.message, {this.cause})
      : kind = AppFailureKind.backup;

  @override
  String toString() => 'AppFailure($kind): $message';
}

enum AppFailureKind { database, validation, notFound, storage, backup, unknown }

/// Turns any thrown object into a user-safe message.
String describeFailure(Object error) {
  if (error is AppFailure) return error.message;
  return 'Something went wrong. Please try again.';
}
