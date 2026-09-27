import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'frame_definition.dart';

class PhotoComposerService {
  static const int frameWidth = 533;
  static const int frameHeight = 1600;

  static Future<Uint8List> compose({
    required List<Uint8List> photos,
    required FrameDefinition frame,
  }) async {
    if (photos.length < frame.photoCount) {
      throw Exception(
        'Dibutuhkan ${frame.photoCount} foto.',
      );
    }

    // ==========================================================
    // LOAD FRAME
    // ==========================================================

    final ByteData frameData = await rootBundle.load(frame.asset);

    final Uint8List frameBytes = frameData.buffer.asUint8List(
      frameData.offsetInBytes,
      frameData.lengthInBytes,
    );

    final img.Image? decodedFrame = img.decodeImage(frameBytes);

    if (decodedFrame == null) {
      throw Exception(
        'Frame gagal dibaca: ${frame.asset}',
      );
    }

    final img.Image resizedFrame = img.copyResize(
      decodedFrame,
      width: frameWidth,
      height: frameHeight,
      interpolation: img.Interpolation.linear,
    );

    // ==========================================================
    // CANVAS DASAR
    //
    // PENTING: canvas dimulai dari kanvas KOSONG (putih), BUKAN
    // dari frame. Fotonya ditaruh dulu di canvas ini, baru
    // setelah itu frame (yang PNG-nya punya lubang transparan
    // di area foto) ditumpuk di ATAS. Dengan begitu, dekorasi
    // di frame (pita, border, dll) akan menutupi pinggiran foto
    // dengan rapi -- persis seperti tampilan live preview di
    // kamera.
    //
    // Kalau urutannya dibalik (frame dulu, foto ditimpa di atas
    // pakai BlendMode.direct), dekorasi frame yang seharusnya
    // "nutup" pinggiran foto malah ikut ketutupan foto.
    // ==========================================================

    img.Image canvas = img.Image(
      width: frameWidth,
      height: frameHeight,
      numChannels: 4,
    );

    img.fill(
      canvas,
      color: img.ColorRgba8(255, 255, 255, 255),
    );

    // ==========================================================
    // MASUKKAN FOTO KE SLOT (DI BAWAH / DASAR)
    // ==========================================================

    for (int i = 0; i < frame.slots.length; i++) {
      final Uint8List photoBytes = photos[i];

      final img.Image? decodedPhoto = img.decodeImage(photoBytes);

      if (decodedPhoto == null) {
        throw Exception(
          'Foto ${i + 1} gagal dibaca.',
        );
      }

      final FramePhotoSlot slot = frame.slots[i];

      final int left = (slot.left * frameWidth).round();

      final int top = (slot.top * frameHeight).round();

      final int width = (slot.width * frameWidth).round();

      final int height = (slot.height * frameHeight).round();

      final img.Image preparedPhoto = _cropCover(
        decodedPhoto,
        width,
        height,
      );

      img.compositeImage(
        canvas,
        preparedPhoto,
        dstX: left,
        dstY: top,
        dstW: width,
        dstH: height,
        // Foto dari kamera tidak punya transparansi, jadi aman
        // pakai direct (langsung timpa) di tahap ini.
        blend: img.BlendMode.direct,
      );
    }

    // ==========================================================
    // FRAME DI ATAS (dengan alpha blending)
    //
    // blend: alpha -> bagian frame yang transparan akan
    // menampilkan foto di bawahnya, bagian yang opaque (pita,
    // border, dekorasi) akan menutupi foto seperti biasa.
    // ==========================================================

    img.compositeImage(
      canvas,
      resizedFrame,
      dstX: 0,
      dstY: 0,
      dstW: frameWidth,
      dstH: frameHeight,
      blend: img.BlendMode.alpha,
    );

    // ==========================================================
    // EXPORT
    // ==========================================================

    return Uint8List.fromList(
      img.encodeJpg(
        canvas,
        quality: 95,
      ),
    );
  }

  static img.Image _cropCover(
    img.Image source,
    int targetWidth,
    int targetHeight,
  ) {
    final double sourceRatio = source.width / source.height;

    final double targetRatio = targetWidth / targetHeight;

    int cropWidth;
    int cropHeight;
    int cropX;
    int cropY;

    if (sourceRatio > targetRatio) {
      cropHeight = source.height;

      cropWidth = (source.height * targetRatio).round();

      cropX = (source.width - cropWidth) ~/ 2;

      cropY = 0;
    } else {
      cropWidth = source.width;

      cropHeight = (source.width / targetRatio).round();

      cropX = 0;

      cropY = (source.height - cropHeight) ~/ 2;
    }

    final img.Image cropped = img.copyCrop(
      source,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );

    return img.copyResize(
      cropped,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );
  }
}
