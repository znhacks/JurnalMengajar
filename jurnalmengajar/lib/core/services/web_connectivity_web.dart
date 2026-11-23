// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation using browser's native navigator.onLine and window events
bool get isWebBrowserOnline => html.window.navigator.onLine ?? true;

void initWebOnlineListeners(void Function(bool isOnline) onStatusChange) {
  try {
    html.window.onOnline.listen((_) => onStatusChange(true));
    html.window.onOffline.listen((_) => onStatusChange(false));
  } catch (_) {}
}
