import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/services/profile_photo_cache.dart';

/// Foto profil yang memakai cache lokal lebih dulu, sehingga tidak perlu
/// menunggu jaringan setiap kali aplikasi dibuka.
class ProfilePhotoView extends StatefulWidget {
  final String userId;
  final String? photoUrl;
  final Widget fallback;
  final BoxFit fit;
  final int cacheWidth;

  const ProfilePhotoView({
    super.key,
    required this.userId,
    required this.photoUrl,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.cacheWidth = 256,
  });

  @override
  State<ProfilePhotoView> createState() => _ProfilePhotoViewState();
}

class _ProfilePhotoViewState extends State<ProfilePhotoView> {
  Uint8List? _bytes;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    final photoUrl = widget.photoUrl;
    if (photoUrl != null && photoUrl.startsWith('http')) {
      _bytes = ProfilePhotoCache().cached(widget.userId, photoUrl);
    }
    _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant ProfilePhotoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId == widget.userId &&
        oldWidget.photoUrl == widget.photoUrl) {
      return;
    }
    _bytes = null;
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final photoUrl = widget.photoUrl;
    final token = ++_loadToken;

    if (photoUrl == null || !photoUrl.startsWith('http')) {
      if (_bytes != null && mounted) {
        setState(() => _bytes = null);
      }
      return;
    }

    final memoryBytes = ProfilePhotoCache().cached(widget.userId, photoUrl);
    if (memoryBytes != null) {
      if (!identical(_bytes, memoryBytes) && mounted) {
        setState(() => _bytes = memoryBytes);
      }
      return;
    }

    await ProfilePhotoCache().loadFromStorage(widget.userId, photoUrl);
    if (!mounted || token != _loadToken) return;

    final storedBytes = ProfilePhotoCache().cached(widget.userId, photoUrl);
    if (storedBytes != null) {
      setState(() => _bytes = storedBytes);
      return;
    }

    final fetchedBytes = await ProfilePhotoCache().fetch(
      widget.userId,
      photoUrl,
    );
    if (!mounted || token != _loadToken || fetchedBytes == null) return;
    setState(() => _bytes = fetchedBytes);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) return widget.fallback;

    return Image.memory(
      bytes,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return widget.fallback;
      },
      errorBuilder: (context, error, stackTrace) => widget.fallback,
    );
  }
}
