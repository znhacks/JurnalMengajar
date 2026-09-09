import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

export 'package:image_picker/image_picker.dart' show ImageSource;

/// Picks an image from [source], then opens the interactive profile photo cropper.
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
    imageQuality: 95,
  );
  if (picked == null) return null;

  final originalBytes = await picked.readAsBytes();

  if (!context.mounted) return null;

  // 2. Open custom, proportional profile crop screen
  final Uint8List? croppedBytes = await Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ProfileCropScreen(imageBytes: originalBytes),
    ),
  );

  if (croppedBytes == null) return null;
  return (bytes: croppedBytes, name: picked.name);
}

// ---------------------------------------------------------------------------
// Proportional Profile Crop Screen
// ---------------------------------------------------------------------------

class _ProfileCropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  const _ProfileCropScreen({required this.imageBytes});

  @override
  State<_ProfileCropScreen> createState() => _ProfileCropScreenState();
}

class _ProfileCropScreenState extends State<_ProfileCropScreen> {
  img.Image? _decodedImage;
  Uint8List? _displayBytes;
  bool _isLoading = true;
  bool _isCropping = false;
  String? _errorMessage;

  // Viewport & crop geometry
  double _circleDiameter = 280.0;
  Offset _cropCenter = Offset.zero;

  // Scale and translation state (direct, deterministic coordinates)
  double _scale = 1.0;
  Offset _translation = Offset.zero;

  // Scale bounds
  double _minScale = 1.0;
  double _maxScale = 3.0;

  // Gesture tracking
  double _gestureStartScale = 1.0;
  Offset _gestureStartFocalPoint = Offset.zero;
  Offset _gestureStartTranslation = Offset.zero;

  bool _isLayoutInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final decoded = await compute(_decodeAndOrientTask, widget.imageBytes);
      if (decoded == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Format gambar tidak didukung atau rusak.';
          });
        }
        return;
      }

      final displayJpg = await compute(_encodeDisplayTask, decoded);

      if (mounted) {
        setState(() {
          _decodedImage = decoded;
          _displayBytes = displayJpg;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat gambar: $e';
        });
      }
    }
  }

  void _initTransform(BoxConstraints constraints) {
    if (_isLayoutInitialized || _decodedImage == null) return;
    _isLayoutInitialized = true;

    final viewW = constraints.maxWidth;
    final viewH = constraints.maxHeight;

    // Center crop circle symmetrically within the viewport
    _circleDiameter = math.min(viewW * 0.82, viewH * 0.82).clamp(200.0, 360.0);
    _cropCenter = Offset(viewW / 2, viewH / 2);

    final imgW = _decodedImage!.width.toDouble();
    final imgH = _decodedImage!.height.toDouble();

    // Scale image so it naturally and completely covers the crop circle
    final scaleX = _circleDiameter / imgW;
    final scaleY = _circleDiameter / imgH;
    _minScale = math.max(scaleX, scaleY);
    _maxScale = _minScale * 3.0;
    _scale = _minScale;

    // Initial position: center horizontally, center vertically with portrait face bias
    final tx = _cropCenter.dx - (imgW * _scale) / 2;
    double ty;
    if (imgH > imgW * 1.15) {
      // In portrait photos, people's heads/faces are placed in the upper half.
      // Bias slightly upward so head/face is nicely centered in the circle.
      final minTy = _cropCenter.dy + (_circleDiameter / 2) - (imgH * _scale);
      final maxTy = _cropCenter.dy - (_circleDiameter / 2);
      final centerTy = _cropCenter.dy - (imgH * _scale) / 2;
      ty = (centerTy + (maxTy - centerTy) * 0.35).clamp(minTy, maxTy);
    } else {
      ty = _cropCenter.dy - (imgH * _scale) / 2;
    }

    _translation = _clampTranslation(Offset(tx, ty), _scale);
  }

  Offset _clampTranslation(Offset t, double s) {
    if (_decodedImage == null) return t;
    final imgW = _decodedImage!.width.toDouble();
    final imgH = _decodedImage!.height.toDouble();
    final r = _circleDiameter / 2;

    // Bounds ensuring the image completely covers the crop circle
    final maxTx = _cropCenter.dx - r;
    final minTx = _cropCenter.dx + r - (imgW * s);
    final maxTy = _cropCenter.dy - r;
    final minTy = _cropCenter.dy + r - (imgH * s);

    final clampedX = minTx <= maxTx
        ? t.dx.clamp(minTx, maxTx)
        : _cropCenter.dx - (imgW * s) / 2;

    final clampedY = minTy <= maxTy
        ? t.dy.clamp(minTy, maxTy)
        : _cropCenter.dy - (imgH * s) / 2;

    return Offset(clampedX, clampedY);
  }

  void _resetTransform() {
    if (_decodedImage == null) return;
    final imgW = _decodedImage!.width.toDouble();
    final imgH = _decodedImage!.height.toDouble();

    final tx = _cropCenter.dx - (imgW * _minScale) / 2;
    double ty;
    if (imgH > imgW * 1.15) {
      final minTy = _cropCenter.dy + (_circleDiameter / 2) - (imgH * _minScale);
      final maxTy = _cropCenter.dy - (_circleDiameter / 2);
      final centerTy = _cropCenter.dy - (imgH * _minScale) / 2;
      ty = (centerTy + (maxTy - centerTy) * 0.35).clamp(minTy, maxTy);
    } else {
      ty = _cropCenter.dy - (imgH * _minScale) / 2;
    }

    setState(() {
      _scale = _minScale;
      _translation = _clampTranslation(Offset(tx, ty), _minScale);
    });
  }

  void _applyZoom(double targetScale) {
    if (_decodedImage == null || _scale == 0) return;
    final newScale = targetScale.clamp(_minScale, _maxScale);
    if (newScale == _scale) return;

    final scaleFactor = newScale / _scale;

    // Scale centered on the crop circle focal point (_cropCenter)
    // Ensures face stays locked at current position without jumping
    final newTx = _cropCenter.dx - scaleFactor * (_cropCenter.dx - _translation.dx);
    final newTy = _cropCenter.dy - scaleFactor * (_cropCenter.dy - _translation.dy);

    setState(() {
      _scale = newScale;
      _translation = _clampTranslation(Offset(newTx, newTy), newScale);
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartScale = _scale;
    _gestureStartFocalPoint = details.localFocalPoint;
    _gestureStartTranslation = _translation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_decodedImage == null || _gestureStartScale == 0) return;

    // 1. Calculate new zoom scale
    final newScale = (_gestureStartScale * details.scale).clamp(_minScale, _maxScale);
    final scaleFactor = newScale / _gestureStartScale;

    // 2. Focal point zoom + pan
    final f = _gestureStartFocalPoint;
    final panDelta = details.localFocalPoint - _gestureStartFocalPoint;
    final rawTx = f.dx - scaleFactor * (f.dx - _gestureStartTranslation.dx) + panDelta.dx;
    final rawTy = f.dy - scaleFactor * (f.dy - _gestureStartTranslation.dy) + panDelta.dy;

    final clamped = _clampTranslation(Offset(rawTx, rawTy), newScale);

    setState(() {
      _scale = newScale;
      _translation = clamped;
    });
  }

  Future<void> _doCrop() async {
    if (_decodedImage == null || _isCropping) return;

    setState(() => _isCropping = true);

    try {
      final cropRadius = _circleDiameter / 2;
      final leftScreen = _cropCenter.dx - cropRadius;
      final topScreen = _cropCenter.dy - cropRadius;

      // Map screen crop rect into source image coordinates
      final srcX = (leftScreen - _translation.dx) / _scale;
      final srcY = (topScreen - _translation.dy) / _scale;
      final srcSize = _circleDiameter / _scale;

      final imgW = _decodedImage!.width;
      final imgH = _decodedImage!.height;

      // Safe clamp inside original image boundaries
      final clampedX = srcX.round().clamp(0, imgW - 1);
      final clampedY = srcY.round().clamp(0, imgH - 1);
      final clampedSize = srcSize.round().clamp(1, math.min(imgW - clampedX, imgH - clampedY));

      final croppedBytes = await compute(_cropAndEncodeTask, {
        'bytes': widget.imageBytes,
        'x': clampedX,
        'y': clampedY,
        'width': clampedSize,
        'height': clampedSize,
      });

      if (mounted) {
        Navigator.of(context).pop(croppedBytes);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memproses foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
          onPressed: _isCropping ? null : () => Navigator.of(context).pop(),
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
                          Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _isLoading || _errorMessage != null ? null : _doCrop,
                  child: Text(
                    'Simpan',
                    style: TextStyle(
                      color: _isLoading || _errorMessage != null
                          ? Colors.white30
                          : const Color(0xFF38BDF8),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image_rounded, size: 56, color: Colors.redAccent),
                        SizedBox(height: 16.h),
                        Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // ─── Interactive Crop Viewport ─────────────────────
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          _initTransform(constraints);
                          final imgW = _decodedImage!.width.toDouble();
                          final imgH = _decodedImage!.height.toDouble();

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              // 1. Pan/Pinch Gesture Surface
                              Listener(
                                onPointerSignal: (pointerSignal) {
                                  if (pointerSignal is PointerScrollEvent) {
                                    final step = (_maxScale - _minScale) * 0.06;
                                    final target = pointerSignal.scrollDelta.dy > 0
                                        ? _scale - step
                                        : _scale + step;
                                    _applyZoom(target);
                                  }
                                },
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onScaleStart: _onScaleStart,
                                  onScaleUpdate: _onScaleUpdate,
                                  child: ClipRect(
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          left: _translation.dx,
                                          top: _translation.dy,
                                          width: imgW * _scale,
                                          height: imgH * _scale,
                                          child: Image.memory(
                                            _displayBytes!,
                                            width: imgW * _scale,
                                            height: imgH * _scale,
                                            fit: BoxFit.fill,
                                            filterQuality: FilterQuality.medium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // 2. Circular Overlay Mask (Touches pass through to gesture layer)
                              IgnorePointer(
                                child: CustomPaint(
                                  size: Size(constraints.maxWidth, constraints.maxHeight),
                                  painter: _CircularCropOverlayPainter(
                                    center: _cropCenter,
                                    radius: _circleDiameter / 2,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // ─── Modern Controls Bar ───────────────────────────
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 18.w),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E293B),
                        border: Border(
                          top: BorderSide(color: Color(0xFF334155), width: 1),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Zoom Status Header
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10.w),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Perbesaran',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(10.r),
                                      border: Border.all(color: const Color(0xFF334155)),
                                    ),
                                    child: Text(
                                      '${_minScale > 0 ? ((_scale / _minScale) * 100).round() : 100}%',
                                      style: TextStyle(
                                        color: const Color(0xFF38BDF8),
                                        fontSize: 11.5.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 6.h),

                            // Zoom Slider & Control Buttons
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.zoom_out_rounded, color: Colors.white70),
                                  tooltip: 'Perkecil',
                                  onPressed: () {
                                    final step = (_maxScale - _minScale) * 0.08;
                                    _applyZoom(_scale - step);
                                  },
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: const Color(0xFF38BDF8),
                                      inactiveTrackColor: const Color(0xFF334155),
                                      thumbColor: const Color(0xFF38BDF8),
                                      overlayColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                                      trackHeight: 4.h,
                                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 9.r),
                                      overlayShape: RoundSliderOverlayShape(overlayRadius: 20.r),
                                    ),
                                    child: Slider(
                                      value: _scale.clamp(_minScale, _maxScale),
                                      min: _minScale,
                                      max: _maxScale,
                                      onChanged: (val) => _applyZoom(val),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.zoom_in_rounded, color: Colors.white70),
                                  tooltip: 'Perbesar',
                                  onPressed: () {
                                    final step = (_maxScale - _minScale) * 0.08;
                                    _applyZoom(_scale + step);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.restart_alt_rounded, color: Colors.white70),
                                  tooltip: 'Pusatkan Posisi',
                                  onPressed: _resetTransform,
                                ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Geser foto atau gunakan slider untuk menyesuaikan posisi wajah',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11.sp,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Circular Overlay Painter
// ---------------------------------------------------------------------------

class _CircularCropOverlayPainter extends CustomPainter {
  final Offset center;
  final double radius;

  _CircularCropOverlayPainter({required this.center, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()
      ..addRect(rect)
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;

    final scrimPaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, scrimPaint);

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius, borderPaint);

    // Subtle alignment guide circles inside frame
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.65, guidePaint);
  }

  @override
  bool shouldRepaint(covariant _CircularCropOverlayPainter oldDelegate) {
    return oldDelegate.center != center || oldDelegate.radius != radius;
  }
}

// ---------------------------------------------------------------------------
// Background Processing Tasks
// ---------------------------------------------------------------------------

img.Image? _decodeAndOrientTask(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  return img.bakeOrientation(decoded);
}

Uint8List _encodeDisplayTask(img.Image image) {
  return Uint8List.fromList(img.encodeJpg(image, quality: 92));
}

Uint8List _cropAndEncodeTask(Map<String, dynamic> params) {
  final Uint8List bytes = params['bytes'];
  final int x = params['x'];
  final int y = params['y'];
  final int width = params['width'];
  final int height = params['height'];

  img.Image? image = img.decodeImage(bytes);
  if (image == null) return bytes;
  image = img.bakeOrientation(image);

  final clampX = x.clamp(0, image.width - 1);
  final clampY = y.clamp(0, image.height - 1);
  final clampW = width.clamp(1, image.width - clampX);
  final clampH = height.clamp(1, image.height - clampY);
  final cropDim = math.min(clampW, clampH);

  img.Image cropped = img.copyCrop(
    image,
    x: clampX,
    y: clampY,
    width: cropDim,
    height: cropDim,
  );

  // Resize proportionally if dimensions exceed 1024x1024 to preserve memory
  if (cropped.width > 1024 || cropped.height > 1024) {
    cropped = img.copyResize(
      cropped,
      width: 1024,
      height: 1024,
      interpolation: img.Interpolation.average,
    );
  }

  return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
}
