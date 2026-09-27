import 'package:flutter/foundation.dart';

class FramePhotoSlot {
  final double left;
  final double top;
  final double width;
  final double height;

  const FramePhotoSlot({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

class FrameDefinition {
  final String asset;
  final List<FramePhotoSlot> slots;

  const FrameDefinition({
    required this.asset,
    required this.slots,
  });

  int get photoCount => slots.length;
}

const List<FrameDefinition> kAvailableFrames = [
  FrameDefinition(
    asset: 'assets/frames/photostrip1.png',
    slots: [
      FramePhotoSlot(
        left: 0.1066,
        top: 0.0779,
        width: 0.7869,
        height: 0.1852,
      ),
      FramePhotoSlot(
        left: 0.1066,
        top: 0.3087,
        width: 0.7869,
        height: 0.1852,
      ),
      FramePhotoSlot(
        left: 0.1066,
        top: 0.5401,
        width: 0.7869,
        height: 0.1852,
      ),
      FramePhotoSlot(
        left: 0.1066,
        top: 0.7754,
        width: 0.7869,
        height: 0.1852,
      ),
    ],
  ),

  FrameDefinition(
    asset: 'assets/frames/photostrip2.png',
    slots: [
      FramePhotoSlot(
        left: 0.1032,
        top: 0.1100,
        width: 0.7937,
        height: 0.1580,
      ),
      FramePhotoSlot(
        left: 0.1032,
        top: 0.3172,
        width: 0.7937,
        height: 0.1580,
      ),
      FramePhotoSlot(
        left: 0.1032,
        top: 0.5248,
        width: 0.7937,
        height: 0.1580,
      ),
      FramePhotoSlot(
        left: 0.1032,
        top: 0.7319,
        width: 0.7937,
        height: 0.1580,
      ),
    ],
  ),

  FrameDefinition(
    asset: 'assets/frames/photostrip3.png',
    slots: [
      FramePhotoSlot(
        left: 0.1168,
        top: 0.0446,
        width: 0.7666,
        height: 0.2201,
      ),
      FramePhotoSlot(
        left: 0.1168,
        top: 0.3172,
        width: 0.7666,
        height: 0.2201,
      ),
      FramePhotoSlot(
        left: 0.1066,
        top: 0.5898,
        width: 0.7767,
        height: 0.2201,
      ),
    ],
  ),

  FrameDefinition(
    asset: 'assets/frames/photostrip4.png',
    slots: [
      FramePhotoSlot(
        left: 0.0998,
        top: 0.0553,
        width: 0.7987,
        height: 0.2144,
      ),
      FramePhotoSlot(
        left: 0.0998,
        top: 0.3002,
        width: 0.7987,
        height: 0.2144,
      ),
      FramePhotoSlot(
        left: 0.0998,
        top: 0.5446,
        width: 0.7987,
        height: 0.2150,
      ),
    ],
  ),
];

void validateFrameDefinitions() {
  assert(() {
    for (final frame in kAvailableFrames) {
      for (final slot in frame.slots) {
        if (slot.left < 0 ||
            slot.top < 0 ||
            slot.width <= 0 ||
            slot.height <= 0 ||
            slot.left + slot.width > 1 ||
            slot.top + slot.height > 1) {
          debugPrint(
            'Frame slot di luar batas 0..1: ${frame.asset}',
          );
        }
      }
    }

    return true;
  }());
}
