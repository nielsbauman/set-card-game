import 'package:opencv_core/opencv.dart' as cv2;
import 'card.dart';

class ColorAnalysis {
  static const COLOR_PIXEL_THRESHOLD = 0.01;

  static List<DetectedColor> extractColors(cv2.Mat cv2Image) {
    final height = cv2Image.height;
    final width = cv2Image.width;

    final hsvImage = cv2.cvtColor(cv2Image, cv2.COLOR_BGR2HSV);

    final lowerRed = range([0, 100, 100]);
    final upperRed = range([10, 255, 255]);
    final lowerRed2 = range([167, 100, 100]);
    final upperRed2 = range([180, 255, 255]);
    final lowerGreen = range([30, 50, 30]);
    final upperGreen = range([90, 255, 255]);
    final lowerPurple = range([110, 35, 20]);
    final upperPurple = range([165, 255, 255]);

    final colorMasks = {
      CardColor.RED: cv2.inRange(hsvImage, lowerRed, upperRed).add(cv2.inRange(hsvImage, lowerRed2, upperRed2)),
      CardColor.GREEN: cv2.inRange(hsvImage, lowerGreen, upperGreen),
      CardColor.PURPLE: cv2.inRange(hsvImage, lowerPurple, upperPurple)
    };

    final detectedColors = <DetectedColor>[];
    final colorThreshold = height * width * COLOR_PIXEL_THRESHOLD;
    colorMasks.forEach((color, mask) {
      final colorPixelCount = cv2.countNonZero(mask);
      if (colorPixelCount > colorThreshold) {
        detectedColors.add(DetectedColor(color, colorPixelCount));
      }
    });

    detectedColors.sort((a, b) => b._colorPixelCount - a._colorPixelCount);

    return detectedColors;
  }

  static cv2.Mat range(List<int> data) {
    return cv2.Mat.fromList(1, 3, cv2.MatType.CV_8UC1, data);
  }
}

class DetectedColor {
  final CardColor _color;
  final int _colorPixelCount;

  DetectedColor(this._color, this._colorPixelCount);

  CardColor get color => _color;

  @override
  String toString() {
    return 'DetectedColor($_color,$_colorPixelCount)';
  }
}
