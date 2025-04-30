import 'dart:developer';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:set_card_game_app/color_analysis.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:opencv_core/opencv.dart' as cv2;
import 'card.dart';

class ObjectDetection {
  static const String _cardDetectionModelPath = 'assets/models/tflite/model_card_detection.tflite';
  static const String _shapeDetectionModelPath = 'assets/models/tflite/model_shape_detection.tflite';
  static const String _shapeDetectionLabelPath = 'assets/models/tflite/shape_detection_labels.txt';

  static const int _imageDimension = 320;
  static const int _imageWidth = _imageDimension;
  static const int _imageHeight = _imageDimension;

  static const double _cardDetectionThreshold = 0.5;
  static const double _cardOverlapThreshold = 0.3;
  static const double _shapeDetectionThreshold = 0.3;
  static const double _shapeOverlapThreshold = 0.3;

  late Interpreter _cardDetectionInterpreter;
  late Interpreter _shapeDetectionInterpreter;
  late List<String> _shapeDetectionLabels;

  ObjectDetection() {
    _loadModels();
    _loadLabels();
    log('Done.');
  }

  Future<void> _loadModels() async {
    log('Loading interpreter options...');
    final interpreterOptions = InterpreterOptions();

    // Use XNNPACK Delegate
    if (Platform.isAndroid) {
      interpreterOptions.addDelegate(XNNPackDelegate());
    }

    // Use Metal Delegate
    if (Platform.isIOS) {
      interpreterOptions.addDelegate(GpuDelegate());
    }

    _cardDetectionInterpreter = await Interpreter.fromAsset(_cardDetectionModelPath, options: interpreterOptions);
    _shapeDetectionInterpreter = await Interpreter.fromAsset(_shapeDetectionModelPath, options: interpreterOptions);
    log('Loaded models');
  }

  Future<void> _loadLabels() async {
    log('Loading labels...');
    final labelsRaw = await rootBundle.loadString(_shapeDetectionLabelPath);
    _shapeDetectionLabels = labelsRaw.split('\n');
  }

  Uint8List analyseImage(String imagePath) {
    log('Analysing image...');
    // Reading image bytes from file
    final imageData = File(imagePath).readAsBytesSync();
    final image = img.decodeImage(imageData)!;

    final detectedCardObjects = _detectCards(imageData);
    final extractedCardImages = _extractObjects(image, detectedCardObjects);

    for (var i = 0; i < detectedCardObjects.length; i++) {
      final detectedCardObject = detectedCardObjects[i];
      final cardImage = extractedCardImages[i];
      final colors = ColorAnalysis.extractColors(img.encodeJpg(cardImage));

      final cv2Img = cv2.imdecode(img.encodeJpg(cardImage), cv2.IMREAD_COLOR);
      final grayImage = cv2.imencode(".jpeg", cv2.cvtColor(cv2Img, cv2.COLOR_BGR2GRAY)).$2;

      final detectedShapes = _detectShapes(grayImage);
      if (colors.isNotEmpty && detectedShapes.isNotEmpty) {
        final [shape, filling] = detectedShapes[0].classLabel.split('-');
        final card = Card(colors[0].color, Shape.fromLong(shape), Filling.fromLong(filling), detectedShapes.length);
        log('Detected card is $card');
        img.drawString(
          image,
          card.toString(),
          font: img.arial48,
          x: (detectedCardObject.boundingBox.left * image.width).toInt() + 7,
          y: (detectedCardObject.boundingBox.top * image.height).toInt() + 7,
          color: img.ColorRgb8(255, 0, 0),
        );
      } else {
        log('Colors was $colors, shapes was $detectedShapes');
      }
      // final colors = List<img.ColorRgb8>.filled(_shapeDetectionLabels.length, img.ColorRgb8(255, 0, 0));
      // _drawResults(colors, card, detectedShapes);
    }

    // _drawResults([img.ColorRgb8(255, 0, 0)], image, detectedCards);
    return img.encodeJpg(image);
  }

  List<DetectedObject> _detectCards(Uint8List imageData) {
    final image = img.decodeImage(imageData)!;
    final detectedObjects = _runInference(_cardDetectionInterpreter, ['card'], image, _cardDetectionThreshold);
    final filteredObjects = _filterObjectsByOverlap(detectedObjects, _cardOverlapThreshold);
    log('Found ${filteredObjects.length} cards (${detectedObjects.length} before filtering)');
    return filteredObjects;
  }

  List<DetectedObject> _detectShapes(Uint8List imageData) {
    final image = img.decodeImage(imageData)!;
    final detectedObjects = _runInference(_shapeDetectionInterpreter, _shapeDetectionLabels, image, _shapeDetectionThreshold);
    final filteredObjects = _filterObjectsByOverlap(detectedObjects, _shapeOverlapThreshold);
    log('Found ${filteredObjects.length} shapes (${detectedObjects.length} before filtering)');
    return filteredObjects;
  }

  List<DetectedObject> _filterObjectsByOverlap(List<DetectedObject> objects, double overlapThreshold) {
    final keep = List<bool>.filled(objects.length, true);

    for (int i = 0; i < objects.length; i++) {
      if (!keep[i]) {
        continue; // Already marked for removal
      }

      final objectI = objects[i];

      for (int j = i + 1; j < objects.length; j++) {
        if (!keep[j]) {
          continue; // Already marked for removal
        }

        final objectJ = objects[j];
        final overlapI = objectI.overlap(objectJ);
        final overlapJ = objectJ.overlap(objectI);

        if (overlapI > overlapThreshold || overlapJ > overlapThreshold) {
          if (objectI.score > objectJ.score) {
            keep[j] = false; // Keep i, remove j
          } else {
            keep[i] = false; // Keep j, remove i
            break; // No need to check i further, it’s removed
          }
        }
      }
    }

    List<DetectedObject> filteredObjects = [];
    for (int i = 0; i < objects.length; i++) {
      if (keep[i]) {
        filteredObjects.add(objects[i]);
      }
    }
    return filteredObjects;
  }

  List<DetectedObject> _runInference(Interpreter interpreter, List<String> labels, img.Image originalImage, double threshold) {
    log('Running inference...');

    final resizedImage = img.copyResize(
      originalImage,
      width: _imageWidth,
      height: _imageHeight,
    );

    // Creating matrix representation, [_imageWidth, _imageHeight, 3]
    final imageMatrix = List.generate(
      resizedImage.height,
      (y) => List.generate(
        resizedImage.width,
        (x) {
          final pixel = resizedImage.getPixel(x, y);
          return [pixel.r, pixel.g, pixel.b];
        },
      ),
    );

    // Set input tensor [1, _imageWidth, _imageHeight, 3]
    final input = [imageMatrix];

    // Set output tensor
    // Scores: [1, 25],
    // Locations: [1, 25, 4],
    // Number of detections: [1],
    // Classes: [1, 25],
    final output = {
      0: [List<num>.filled(25, 0)],
      1: [List<List<num>>.filled(25, List<num>.filled(4, 0))],
      2: [0.0],
      3: [List<num>.filled(25, 0)],
    };

    interpreter.runForMultipleInputs([input], output);

    // Process Tensors from the output
    final scoresTensor = output[0]!.first as List<double>;
    final boxesTensor = output[1]!.first as List<List<double>>;
    final numberOfDetections = output[2]!.first as double;
    final classesTensor = output[3]!.first as List<double>;

    final detectedObjects = <DetectedObject>[];
    for (int i = 0; i < numberOfDetections; i++) {
      final score = scoresTensor[i];
      if (score < threshold) {
        continue;
      }
      final classId = classesTensor[i].toInt();
      final boundingBox = boxesTensor[i];
      detectedObjects.add(
        DetectedObject(
          classId,
          labels[classId],
          score,
          Rect.fromLTRB(boundingBox[1], boundingBox[0], boundingBox[3], boundingBox[2]),
        ),
      );
    }

    return detectedObjects;
  }

  void _drawResults(List<img.ColorRgb8> colors, img.Image image, List<DetectedObject> results) {
    for (final object in results) {
      final xMin = (object.boundingBox.left * image.width).toInt();
      final xMax = (object.boundingBox.right * image.width).toInt();
      final yMin = (object.boundingBox.top * image.height).toInt();
      final yMax = (object.boundingBox.bottom * image.height).toInt();
      // Rectangle drawing
      img.drawRect(
        image,
        x1: xMin,
        y1: yMin,
        x2: xMax,
        y2: yMax,
        color: colors[object.classId],
        thickness: 8,
      );
      // Label drawing
      img.drawString(
        image,
        '${object.classLabel} ${object.score}',
        font: img.arial48,
        x: xMin + 7,
        y: yMin + 7,
        color: colors[object.classId],
      );
    }
  }

  List<img.Image> _extractObjects(img.Image image, List<DetectedObject> objects) {
    return objects.map((object) {
      final xMin = (object.boundingBox.left * image.width).toInt();
      final yMin = (object.boundingBox.top * image.height).toInt();
      final width = (object.boundingBox.width * image.width).toInt();
      final height = (object.boundingBox.height * image.height).toInt();
      return img.copyCrop(image, x: xMin, y: yMin, width: width, height: height);
    }).toList();
  }
}

class DetectedObject {
  final int _classId;
  final String _classLabel;
  final double _score;
  final Rect _boundingBox;

  DetectedObject(this._classId, this._classLabel, this._score, this._boundingBox);

  double overlap(DetectedObject other) {
    final thisArea = _boundingBox.width * _boundingBox.height;
    if (thisArea == 0) {
      return 0;
    }
    final intersection = _boundingBox.intersect(other._boundingBox);
    if (intersection.isEmpty) {
      return 0;
    }
    final intersectionArea = intersection.width * intersection.height;
    return intersectionArea / thisArea;
  }

  int get classId => _classId;
  String get classLabel => _classLabel;
  double get score => _score;
  Rect get boundingBox => _boundingBox;

  @override
  String toString() {
    return 'DetectedObject($classLabel,$score)';
  }
}
