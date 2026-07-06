import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:image_picker/image_picker.dart';

export 'package:image_picker/image_picker.dart' show ImageSource;

/// Picks an image from [source], then opens the pure-Dart crop screen.
///
/// Returns a record with the cropped [bytes] and the original [name],
/// or null if the user cancelled at any step.
Future<({Uint8List bytes, String name})?> pickAndCropImage({
  required BuildContext context,
  ImageSource source = ImageSource.gallery,
}) async {
  // 1. Pick image
  final XFile? picked = await ImagePicker().pickImage(
    source: source,
    imageQuality: 90,
  );
  if (picked == null) return null;

  final originalBytes = await picked.readAsBytes();

  if (!context.mounted) return null;

  // 2. Open crop screen (pure Dart, no native SDK required)
  final Uint8List? croppedBytes = await Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _CropScreen(imageBytes: originalBytes),
    ),
  );

  if (croppedBytes == null) return null;
  return (bytes: croppedBytes, name: picked.name);
}

// ---------------------------------------------------------------------------
// Internal Crop Screen
// ---------------------------------------------------------------------------

class _CropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  const _CropScreen({required this.imageBytes});

  @override
  State<_CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<_CropScreen> {
  final _controller = CropController();
  bool _isCropping = false;

  void _doCrop() {
    setState(() => _isCropping = true);
    _controller.crop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Batal',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Atur Foto Profil',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          _isCropping
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF0D9488),
                        ),
                      ),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _doCrop,
                  child: Text(
                    'Simpan',
                    style: TextStyle(
                      color: const Color(0xFF0D9488),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ],
      ),
      body: Column(
        children: [
          // ─── Crop Area ───────────────────────────────────────────────────
          Expanded(
            child: Crop(
              image: widget.imageBytes,
              controller: _controller,
              onCropped: (result) {
                if (!mounted) return;
                switch (result) {
                  case CropSuccess(:final croppedImage):
                    Navigator.of(context).pop(croppedImage);
                  case CropFailure():
                    setState(() => _isCropping = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gagal memotong foto, coba lagi.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                }
              },
              aspectRatio: 1, // Square 1:1
              maskColor: Colors.black.withValues(alpha: 0.7),
              baseColor: const Color(0xFF0F172A),
              radius: 200, // high radius = visually circular crop frame
              interactive: true,
              withCircleUi: true,
            ),
          ),

          // ─── Controls ────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 24.w),
            color: const Color(0xFF1E293B),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Geser dan cubit untuk menyesuaikan foto',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
