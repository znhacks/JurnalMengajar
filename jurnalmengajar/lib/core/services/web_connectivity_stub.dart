/// Stub implementation for non-web platforms (Mobile, Desktop, CLI)
bool get isWebBrowserOnline => true;

void initWebOnlineListeners(void Function(bool isOnline) onStatusChange) {
  // No-op on non-web platforms
}
