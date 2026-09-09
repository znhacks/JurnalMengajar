import 'dart:math' as math;
import 'package:flutter/foundation.dart';
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
  final TransformationController _transformController = TransformationController();

  img.Image? _decodedImage;
  Uint8List? _displayBytes;
  bool _isLoading = true;
  bool _isCropping = false;
  String? _errorMessage;

  double _circleDiameter = 280.0;
  Offset _cropCenter = Offset.zero;
  double _baseScale = 1.0;
  double _minScale = 0.2;
  double _maxScale = 4.0;
  double _sliderScale = 1.0;
  bool _isLayoutInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
    _transformController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
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

  void _onTransformChanged() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    if (_minScale < _maxScale && currentScale != _sliderScale) {
      setState(() {
        _sliderScale = currentScale.clamp(_minScale, _maxScale);
      });
    }
  }

  Matrix4 _matrixFromTransform(double tx, double ty, double scale) {
    final m = Matrix4.identity();
    m.storage[0] = scale;
    m.storage[5] = scale;
    m.storage[12] = tx;
    m.storage[13] = ty;
    return m;
  }

  void _initTransform(BoxConstraints constraints) {
    if (_isLayoutInitialized || _decodedImage == null) return;
    _isLayoutInitialized = true;

    final viewW = constraints.maxWidth;
    final viewH = constraints.maxHeight;

    // Calculate comfortable crop circle diameter
    _circleDiameter = math.min(viewW * 0.82, viewH * 0.58).clamp(200.0, 360.0);
    _cropCenter = Offset(viewW / 2, viewH * 0.44);

    final imgW = _decodedImage!.width.toDouble();
    final imgH = _decodedImage!.height.toDouble();

    // Scale image so it naturally covers the crop circle without over-zooming
    final scaleX = _circleDiameter / imgW;
    final scaleY = _circleDiameter / imgH;
    _baseScale = math.max(scaleX, scaleY);

    _minScale = _baseScale * 0.5;
    _maxScale = _baseScale * 4.0;
    _sliderScale = _baseScale;

    // Center image over the crop circle
    final tx = _cropCenter.dx - (imgW * _baseScale) / 2;
    final ty = _cropCenter.dy - (imgH * _baseScale) / 2;

    _transformController.value = _matrixFromTransform(tx, ty, _baseScale);
  }

  void _resetTransform() {
    if (_decodedImage == null) return;
    final imgW = _decodedImage!.width.toDouble();
    final imgH = _decodedImage!.height.toDouble();

    final tx = _cropCenter.dx - (imgW * _baseScale) / 2;
    final ty = _cropCenter.dy - (imgH * _baseScale) / 2;

    setState(() {
      _sliderScale = _baseScale;
      _transformController.value = _matrixFromTransform(tx, ty, _baseScale);
    });
  }

  void _applyZoom(double targetScale) {
    if (_decodedImage == null) return;
    final currentMatrix = _transformController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    if (currentScale == 0) return;

    final scaleFactor = targetScale / currentScale;
    final currentTx = currentMatrix.storage[12];
    final currentTy = currentMatrix.storage[13];

    // Scale centered on the crop circle
    final newTx = _cropCenter.dx - scaleFactor * (_cropCenter.dx - currentTx);
    final newTy = _cropCenter.dy - scaleFactor * (_cropCenter.dy - currentTy);

    setState(() {
      _sliderScale = targetScale.clamp(_minScale, _maxScale);
      _transformController.value = _matrixFromTransform(newTx, newTy, targetScale);
    });
  }

  Future<void> _doCrop() async {
    if (_decodedImage == null || _isCropping) return;

    setState(() => _isCropping = true);

    try {
      final matrix = _transformController.value;
      final scale = matrix.getMaxScaleOnAxis();
      final tx = matrix.storage[12];
      final ty = matrix.storage[13];

      final cropRadius = _circleDiameter / 2;
      final leftScreen = _cropCenter.dx - cropRadius;
      final topScreen = _cropCenter.dy - cropRadius;

      final srcX = (leftScreen - tx) / scale;
      final srcY = (topScreen - ty) / scale;
      final srcSize = _circleDiameter / scale;

      final croppedBytes = await compute(_cropAndEncodeTask, {
        'bytes': widget.imageBytes,
        'x': srcX.round(),
        'y': srcY.round(),
        'width': srcSize.round(),
        'height': srcSize.round(),
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
              : LayoutBuilder(
                  builder: (context, constraints) {
                    _initTransform(constraints);
                    final imgW = _decodedImage!.width.toDouble();
                    final imgH = _decodedImage!.height.toDouble();

                    return Column(
                      children: [
                        // ─── Interactive Crop Viewport ─────────────────────
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // 1. Pan/Zoom Layer
                              InteractiveViewer(
                                transformationController: _transformController,
                                minScale: _minScale,
                                maxScale: _maxScale,
                                boundaryMargin: EdgeInsets.all(_circleDiameter * 2.0),
                                constrained: false,
                                child: SizedBox(
                                  width: imgW,
                                  height: imgH,
                                  child: Image.memory(
                                    _displayBytes!,
                                    width: imgW,
                                    height: imgH,
                                    fit: BoxFit.fill,
                                    filterQuality: FilterQuality.medium,
                                  ),
                                ),
                              ),

                              // 2. Circular Overlay Mask (Passes touches through)
                              IgnorePointer(
                                child: CustomPaint(
                                  painter: _CircularCropOverlayPainter(
                                    center: _cropCenter,
                                    radius: _circleDiameter / 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ─── Modern Controls Bar ───────────────────────────
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 20.w),
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
                                // Zoom Slider & Quick Buttons
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.zoom_out, color: Colors.white70),
                                      tooltip: 'Perkecil',
                                      onPressed: () {
                                        final target = (_sliderScale - (_maxScale - _minScale) * 0.1)
                                            .clamp(_minScale, _maxScale);
                                        _applyZoom(target);
                                      },
                                    ),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          activeTrackColor: const Color(0xFF38BDF8),
                                          inactiveTrackColor: const Color(0xFF334155),
                                          thumbColor: const Color(0xFF38BDF8),
                                          overlayColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                                          trackHeight: 3.h,
                                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7.r),
                                        ),
                                        child: Slider(
                                          value: _sliderScale.clamp(_minScale, _maxScale),
                                          min: _minScale,
                                          max: _maxScale,
                                          onChanged: (val) => _applyZoom(val),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.zoom_in, color: Colors.white70),
                                      tooltip: 'Perbesar',
                                      onPressed: () {
                                        final target = (_sliderScale + (_maxScale - _minScale) * 0.1)
                                            .clamp(_minScale, _maxScale);
                                        _applyZoom(target);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.crop_free, color: Colors.white70),
                                      tooltip: 'Pusatkan',
                                      onPressed: _resetTransform,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'Geser foto atau gunakan slider untuk menyesuaikan posisi wajah',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11.5.sp,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
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
