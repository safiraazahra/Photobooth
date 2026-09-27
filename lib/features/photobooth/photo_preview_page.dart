import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/photo/frame_definition.dart';
import '../../core/photo/photo_composer_service.dart';
import '../../core/storage/photo_storage_service.dart';
import '../../core/storage/photo_upload_service.dart';
import '../../core/theme/app_theme.dart';
import 'final_preview_page.dart';

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
  Uint8List? _composedPhoto;

  bool _isProcessing = true;
  bool _isUploading = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _composePreview();
  }

  // ==========================================================
  // COMPOSE PREVIEW
  // ==========================================================

  Future<void> _composePreview() async {
    try {
      final Uint8List result = await PhotoComposerService.compose(
        photos: widget.photos,
        frame: widget.frame,
      );

      if (!mounted) return;

      setState(() {
        _composedPhoto = result;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _errorMessage = 'Preview gagal dibuat.\n$e';
      });
    }
  }

  // ==========================================================
  // CONFIRM
  // ==========================================================

  Future<void> _usePhoto() async {
    if (_composedPhoto == null || _isUploading) {
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final Uint8List photo = _composedPhoto!;

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

  // ==========================================================
  // RETAKE
  // ==========================================================

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
                    onPressed: _isProcessing || _isUploading ? null : _retake,
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
                ],
              ),
            ),

            // --------------------------------------------------
            // PHOTO
            // --------------------------------------------------

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(child: _buildPreview()),
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

  Widget _buildPreview() {
    if (_isProcessing) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.accent),
          SizedBox(height: 16),
          Text(
            'Putting your photos in the frame…',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      );
    }

    if (_composedPhoto == null) {
      return const Text(
        'Preview isn\u2019t available.',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Image.memory(
        _composedPhoto!,
        fit: BoxFit.contain,
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
                onPressed: _isProcessing || _isUploading ? null : _retake,
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
                onPressed:
                    _isProcessing || _isUploading || _composedPhoto == null
                        ? null
                        : _usePhoto,
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
