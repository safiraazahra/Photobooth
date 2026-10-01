import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

import '../../core/photo/frame_definition.dart';
import '../../core/storage/photo_storage_service.dart';
import '../../core/storage/photo_upload_service.dart';
import '../../core/theme/app_theme.dart';
import 'final_preview_page.dart';

// =================================================================
// TRANSFORM PER SLOT (zoom + geser)
// =================================================================
//
// `scale` dan `offset` ini tambahan DI ATAS "cover fit" dasar yang
// sudah otomatis dilakukan oleh BoxFit.cover (yang bikin foto penuh
// menutupi slot tanpa celah di scale 1.0). Jadi scale minimum
// selalu 1.0 (tidak bisa di-zoom out sampai ada celah kosong).

class _SlotTransform {
  double scale = 1.0;
  Offset offset = Offset.zero;

  // Nilai sementara, dipakai selama satu gesture pinch/geser berlangsung.
  double gestureStartScale = 1.0;
  Offset gestureStartOffset = Offset.zero;
  Offset gestureStartFocalPoint = Offset.zero;

  void reset() {
    scale = 1.0;
    offset = Offset.zero;
  }
}

class PhotoPreviewPage extends StatefulWidget {
  final List<Uint8List> photos;
  final FrameDefinition frame;

  const PhotoPreviewPage({
    super.key,
    required this.photos,
    required this.frame,
  });

  @override
  State<PhotoPreviewPage> createState() => _PhotoPreviewPageState();
}

class _PhotoPreviewPageState extends State<PhotoPreviewPage> {
  // Resolusi output akhir, sama seperti yang dipakai sebelumnya
  // di PhotoComposerService, supaya ukuran file akhir konsisten.
  static const double _frameWidth = 533;
  static const double _frameHeight = 1600;

  final GlobalKey _captureKey = GlobalKey();

  late final List<_SlotTransform> _transforms;

  bool _isUploading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _transforms = List.generate(
      widget.frame.slots.length,
      (_) => _SlotTransform(),
    );
  }

  // ==========================================================
  // GESTURE PER SLOT
  // ==========================================================

  void _onScaleStart(int index, ScaleStartDetails details) {
    final _SlotTransform t = _transforms[index];

    t.gestureStartScale = t.scale;
    t.gestureStartOffset = t.offset;
    t.gestureStartFocalPoint = details.focalPoint;
  }

  void _onScaleUpdate(
    int index,
    ScaleUpdateDetails details,
    Size slotSize,
  ) {
    final _SlotTransform t = _transforms[index];

    final double newScale = (t.gestureStartScale * details.scale).clamp(
      1.0,
      4.0,
    );

    final Offset focalDelta = details.focalPoint - t.gestureStartFocalPoint;

    Offset newOffset = t.gestureStartOffset + focalDelta;

    // Batasi geseran supaya foto tetap menutupi penuh slot
    // (tidak ada celah kosong di pinggir).
    final double maxDx = (newScale - 1) * slotSize.width / 2;
    final double maxDy = (newScale - 1) * slotSize.height / 2;

    newOffset = Offset(
      newOffset.dx.clamp(-maxDx, maxDx),
      newOffset.dy.clamp(-maxDy, maxDy),
    );

    setState(() {
      t.scale = newScale;
      t.offset = newOffset;
    });
  }

  // Dipakai oleh scroll wheel mouse (zoom tanpa pinch).
  void _applyZoom(int index, double scaleDelta, Size slotSize) {
    final _SlotTransform t = _transforms[index];

    final double newScale = (t.scale + scaleDelta).clamp(1.0, 4.0);

    final double maxDx = (newScale - 1) * slotSize.width / 2;
    final double maxDy = (newScale - 1) * slotSize.height / 2;

    final Offset newOffset = Offset(
      t.offset.dx.clamp(-maxDx, maxDx),
      t.offset.dy.clamp(-maxDy, maxDy),
    );

    setState(() {
      t.scale = newScale;
      t.offset = newOffset;
    });
  }

  void _resetSlot(int index) {
    setState(() {
      _transforms[index].reset();
    });
  }

  bool get _anySlotEdited {
    return _transforms.any((t) => t.scale != 1.0 || t.offset != Offset.zero);
  }

  void _resetAll() {
    setState(() {
      for (final t in _transforms) {
        t.reset();
      }
    });
  }

  // ==========================================================
  // CAPTURE -> SAVE -> UPLOAD
  //
  // Hasil akhir diambil persis dari apa yang terlihat di layar
  // (frame + foto + posisi zoom/geser), bukan dihitung ulang
  // manual. Jadi dijamin sama persis dengan preview.
  // ==========================================================

  Future<void> _usePhoto() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final RenderRepaintBoundary boundary = _captureKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      // Capture pada resolusi _frameWidth x _frameHeight, berapa pun
      // ukuran tampilan di layar (pixelRatio menyesuaikan otomatis).
      final double pixelRatio = _frameWidth / boundary.size.width;

      final ui.Image uiImage = await boundary.toImage(
        pixelRatio: pixelRatio,
      );

      final ByteData? pngData = await uiImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (pngData == null) {
        throw Exception('Gagal mengambil hasil capture.');
      }

      // Convert PNG (hasil capture) -> JPEG, supaya konsisten dengan
      // alur upload/simpan yang sudah ada (nama file .jpg, dsb).
      final img.Image? decoded = img.decodeImage(
        pngData.buffer.asUint8List(),
      );

      if (decoded == null) {
        throw Exception('Gagal memproses hasil capture.');
      }

      final Uint8List photo = Uint8List.fromList(
        img.encodeJpg(decoded, quality: 95),
      );

      final String photoId = await PhotoStorageService.savePhoto(photo);

      final String publicUrl = await PhotoUploadService.uploadPhoto(
        photoId: photoId,
        bytes: photo,
      );

      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) {
            return FinalPreviewPage(
              photo: photo,
              photoId: photoId,
              publicUrl: publicUrl,
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isUploading = false;
        _errorMessage = 'Foto gagal disimpan/upload.\n\n$e';
      });
    }
  }

  void _retake() {
    Navigator.of(context).pop();
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // --------------------------------------------------
            // HEADER
            // --------------------------------------------------

            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 20, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isUploading ? null : _retake,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    'Preview',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_anySlotEdited)
                    TextButton.icon(
                      onPressed: _isUploading ? null : _resetAll,
                      icon: const Icon(
                        Icons.center_focus_weak_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      label: const Text(
                        'Reset all',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // --------------------------------------------------
            // EDITOR (frame + foto yang bisa di-zoom/geser)
            // --------------------------------------------------

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(child: _buildEditor()),
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Pinch each photo to zoom \u00b7 drag to reposition',
                style: TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 11,
                ),
              ),
            ),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                  ),
                ),
              ),

            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // EDITOR
  // ==========================================================

  Widget _buildEditor() {
    const double aspectRatio = _frameWidth / _frameHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        double height = constraints.maxHeight;
        double width = height * aspectRatio;

        if (width > constraints.maxWidth) {
          width = constraints.maxWidth;
          height = width / aspectRatio;
        }

        return SizedBox(
          width: width,
          height: height,
          child: RepaintBoundary(
            key: _captureKey,
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: LayoutBuilder(
                builder: (context, inner) {
                  final Size displaySize = Size(
                    inner.maxWidth,
                    inner.maxHeight,
                  );

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Stack(
                      children: [
                        // Foto-foto dulu (di belakang), per slot.
                        for (int i = 0;
                            i < widget.photos.length &&
                                i < widget.frame.slots.length;
                            i++)
                          _buildEditableSlot(i, displaySize),

                        // Frame di atas (PNG dengan lubang transparan).
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Image.asset(
                              widget.frame.asset,
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditableSlot(int index, Size displaySize) {
    final FramePhotoSlot slot = widget.frame.slots[index];
    final _SlotTransform t = _transforms[index];

    final double left = slot.left * displaySize.width;
    final double top = slot.top * displaySize.height;
    final double w = slot.width * displaySize.width;
    final double h = slot.height * displaySize.height;

    final Size slotSize = Size(w, h);

    // Matrix ditulis eksplisit (bukan lewat `alignment` bawaan Transform)
    // supaya pasti benar: skala dari titik tengah slot, lalu digeser
    // sejumlah `offset`. Urutan baca Matrix4 chain adalah dari BAWAH
    // ke ATAS terhadap titik yang ditransformasi:
    //   1) translate(-cx, -cy)      -> pindahkan pusat slot ke origin
    //   2) scale(t.scale)           -> perbesar dari origin (= pusat slot)
    //   3) translate(cx+dx, cy+dy)  -> kembalikan ke posisi + geseran user
    final double cx = w / 2;
    final double cy = h / 2;

    final Matrix4 matrix = Matrix4.identity()
      ..translate(cx + t.offset.dx, cy + t.offset.dy)
      ..scale(t.scale)
      ..translate(-cx, -cy);

    return Positioned(
      left: left,
      top: top,
      width: w,
      height: h,
      child: ClipRect(
        child: Listener(
          // Scroll wheel mouse / trackpad (tanpa pinch) -> zoom.
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              const double sensitivity = 0.0022;
              final double delta = -event.scrollDelta.dy * sensitivity;
              _applyZoom(index, delta, slotSize);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Satu jari/klik-drag -> geser. Dua jari (touchscreen) -> zoom.
            onScaleStart: (details) => _onScaleStart(index, details),
            onScaleUpdate: (details) {
              _onScaleUpdate(index, details, slotSize);
            },
            onDoubleTap: () => _resetSlot(index),
            child: Transform(
              transform: matrix,
              child: Image.memory(
                widget.photos[index],
                width: w,
                height: h,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: _isUploading ? null : _retake,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                  ),
                ),
                child: const Text(
                  'Retake',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _isUploading ? null : _usePhoto,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  disabledBackgroundColor: AppColors.surfaceRaised,
                  disabledForegroundColor: AppColors.textFaint,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                  ),
                ),
                child: _isUploading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.onAccent,
                        ),
                      )
                    : const Text(
                        'Continue',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
