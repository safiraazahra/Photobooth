import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/camera/camera_service.dart';
import '../../core/photo/frame_definition.dart';
import '../../core/theme/app_theme.dart';
import 'photo_preview_page.dart';

class PhotoBoothPage extends StatefulWidget {
  const PhotoBoothPage({super.key});

  @override
  State<PhotoBoothPage> createState() => _PhotoBoothPageState();
}

class _PhotoBoothPageState extends State<PhotoBoothPage> {
  final CameraService _cameraService = CameraService();

  int _selectedFrameIndex = 0;

  bool _isInitializing = true;
  bool _isShooting = false;

  int _countdown = 0;

  String? _errorMessage;

  final List<Uint8List> _photos = [];

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cameraService.dispose();
    super.dispose();
  }

 
  Future<void> _initializeCamera() async {
    if (!mounted) return;

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      await _cameraService.initialize();

      if (!mounted) return;

      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isInitializing = false;
        _errorMessage = 'Kamera gagal dibuka.\n$e';
      });
    }
  }

  Future<void> _restartCamera() async {
    try {
      await _cameraService.restartCamera();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Kamera gagal dimulai ulang.\n$e';
      });
    }
  }

  FrameDefinition get _selectedFrame {
    return kAvailableFrames[_selectedFrameIndex];
  }

  int get _requiredPhotoCount {
    return _selectedFrame.photoCount;
  }

  Future<void> _startSession() async {
    if (_isShooting) return;

    if (!_cameraService.isInitialized) {
      await _initializeCamera();

      if (!_cameraService.isInitialized) {
        return;
      }
    }

    if (!mounted) return;

    setState(() {
      _isShooting = true;
      _photos.clear();
      _errorMessage = null;
    });

    try {
      for (int i = 0; i < _requiredPhotoCount; i++) {
        await _runCountdown();

        if (!mounted) return;

        final XFile? picture = await _cameraService.takePicture();

        if (picture == null) {
          throw Exception('Foto ke-${i + 1} gagal diambil.');
        }

        final Uint8List bytes = await picture.readAsBytes();

        _photos.add(bytes);

        if (mounted) {
          setState(() {});
        }

        if (i < _requiredPhotoCount - 1) {
          await Future.delayed(const Duration(milliseconds: 600));
        }
      }

      await _finishSession();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Terjadi kesalahan saat mengambil foto.\n$e';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isShooting = false;
        _countdown = 0;
      });
    }
  }

  Future<void> _runCountdown() async {
    for (int number = 3; number >= 1; number--) {
      if (!mounted) return;

      setState(() {
        _countdown = number;
      });

      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;

    setState(() {
      _countdown = 0;
    });
  }

  Future<void> _finishSession() async {
    if (_photos.length < _requiredPhotoCount) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          return PhotoPreviewPage(
            photos: List<Uint8List>.from(_photos),
            frame: _selectedFrame,
          );
        },
      ),
    );

    if (!mounted) return;

    await _restartCamera();

    if (!mounted) return;

    setState(() {
      _photos.clear();
    });
  }

  Widget _buildCameraPreview() {
    final CameraController? controller = _cameraService.controller;

    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: CameraPreview(controller),
      ),
    );
  }


  Widget _buildFrameSelector() {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kAvailableFrames.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final FrameDefinition frame = kAvailableFrames[index];
          final bool selected = index == _selectedFrameIndex;

          return GestureDetector(
            onTap: _isShooting
                ? null
                : () {
                    setState(() {
                      _selectedFrameIndex = index;
                      _photos.clear();
                    });
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 68,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                border: Border.all(
                  color: selected ? AppColors.accent : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm - 2),
                child: Image.asset(
                  frame.asset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return const ColoredBox(
                      color: AppColors.surfaceRaised,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: AppColors.textFaint,
                        size: 18,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Choose a frame',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Needs $_requiredPhotoCount photos',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFrameSelector(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _isShooting ? null : _startSession,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                disabledBackgroundColor: AppColors.surfaceRaised,
                disabledForegroundColor: AppColors.textFaint,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                ),
              ),
              child: Text(
                _isShooting ? 'Taking photos…' : 'Take photos',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
           
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  const Text(
                    'Photobooth',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (!_isShooting)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Camera ready',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Photo ${_photos.length + 1} of $_requiredPhotoCount',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),

          
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _isInitializing
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.accent,
                                ),
                              )
                            : _buildCameraPreview(),

                        if (_countdown > 0)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.45),
                              child: Center(
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.7, end: 1.0),
                                  duration: const Duration(
                                    milliseconds: 700,
                                  ),
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: child,
                                    );
                                  },
                                  child: Text(
                                    '$_countdown',
                                    style: const TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 104,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

           
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                  ),
                ),
              ),

            const SizedBox(height: 10),

          
            _buildControls(),
          ],
        ),
      ),
    );
  }
}
