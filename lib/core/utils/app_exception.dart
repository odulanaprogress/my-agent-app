/// A custom exception class whose message is always preserved in release
/// builds (unlike [StateError] which gets class-name-minified on Flutter Web).
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Extracts a human-readable message from any thrown object.
/// Works in both debug and release/minified Flutter Web builds.
String extractErrorMessage(Object e) {
  if (e is AppException) return e.message;
  // Exception (dart core) preserves its message even in release mode.
  if (e is Exception) {
    final raw = e.toString();
    // strip "Exception: " prefix added by dart:core
    if (raw.startsWith('Exception: ')) return raw.substring('Exception: '.length);
    return raw;
  }
  // For StateError and other Error subclasses the message is in .message
  try {
    final msg = (e as dynamic).message as String?;
    if (msg != null && msg.isNotEmpty) return msg;
  } catch (_) {}
  // Last resort – may look bad in release but at least doesn't crash
  return e.toString();
}
