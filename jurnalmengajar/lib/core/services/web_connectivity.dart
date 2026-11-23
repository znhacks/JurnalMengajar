import 'web_connectivity_stub.dart'
    if (dart.library.html) 'web_connectivity_web.dart' as platform_impl;

/// Status koneksi browser (hanya aktif di Web, selalu bernilai true di Native)
bool get isWebBrowserOnline => platform_impl.isWebBrowserOnline;

/// Mendaftarkan listener real-time koneksi browser online/offline
void initWebOnlineListeners(void Function(bool isOnline) onStatusChange) =>
    platform_impl.initWebOnlineListeners(onStatusChange);
