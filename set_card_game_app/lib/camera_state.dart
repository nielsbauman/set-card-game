import 'package:flutter/material.dart' hide Card;
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:developer';

import 'set_matcher.dart';
import 'object_detection.dart';
import 'card.dart';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _showCapturedPhoto = false;
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  late ObjectDetection objectDetection;

  List<List<(Card, DetectedObject)>> _detectedSets = [];
  bool _showSetPrompt = false;
  bool _showCurrentSet = false;
  int _currentSetIndex = 0;
  int _currentCardIndex = 0;
  double _imageDisplayWidth = 0;
  double _imageDisplayHeight = 0;
  double _imageOffsetX = 0;
  double _imageOffsetY = 0;

  final GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initCamera();
    objectDetection = ObjectDetection();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _controller = CameraController(firstCamera, ResolutionPreset.high, enableAudio: false);
    _initializeControllerFuture = _controller.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();

      await _runAnalysis(image);

      setState(() {
        _imageFile = image;
        _showCapturedPhoto = true;
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _runAnalysis(image);

      setState(() {
        _imageFile = image;
        _showCapturedPhoto = true;
      });
    }
  }

  Future<void> _runAnalysis(XFile image) async {
    final imageData = File(image.path).readAsBytesSync();
    final (drawnImage, detectedCards) = objectDetection!.analyseImage(imageData);
    final computedSets = SetMatcher.computeBruteForce(detectedCards);
    setState(() {
      _detectedSets = computedSets.map((e) => e.toList()).toList();
      _showSetPrompt = computedSets.isNotEmpty;
    });
  }

  void _handleTap() {
    setState(() {
      if (_currentCardIndex < 2) {
        _currentCardIndex++;
      } else {
        _currentCardIndex = 0;
        if (_currentSetIndex < _detectedSets.length - 1) {
          _currentSetIndex++;
        } else {
          _currentSetIndex = 0;
        }
      }
    });
  }

  void _updateImageLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _imageKey.currentContext;
      if (context != null && mounted) {
        final renderBox = context.findRenderObject() as RenderBox;
        final size = renderBox.size;
        final offset = renderBox.localToGlobal(Offset.zero);

        setState(() {
          _imageDisplayWidth = size.width;
          _imageDisplayHeight = size.height;
          _imageOffsetX = offset.dx;
          _imageOffsetY = offset.dy;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _showCapturedPhoto && _imageFile != null
                        ? GestureDetector(
                            onTap: _showCurrentSet ? _handleTap : null,
                            child: Stack(
                              children: [
                                Center(
                                  child: Image.file(
                                    File(_imageFile!.path),
                                    key: _imageKey,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                Builder(
                                  builder: (context) {
                                    _updateImageLayout();
                                    return const SizedBox.shrink();
                                  },
                                ),
                                if (_showCurrentSet)
                                  ...List.generate(
                                    _currentCardIndex + 1,
                                    (i) => CustomPaint(
                                      painter: HighlightPainter(
                                        _detectedSets[_currentSetIndex][i].$2.boundingBox,
                                        _imageDisplayWidth,
                                        _imageDisplayHeight,
                                        _imageOffsetX,
                                        _imageOffsetY,
                                      ),
                                      child: Container(),
                                    ),
                                  ),
                                if (_showSetPrompt && !_showCurrentSet)
                                  Center(
                                    child: AlertDialog(
                                      title: Text("Found ${_detectedSets.length} sets!"),
                                      content: Text("Would you like to view them one by one?"),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _showSetPrompt = false;
                                            });
                                          },
                                          child: Text("No"),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _showSetPrompt = false;
                                              _showCurrentSet = true;
                                              _currentSetIndex = 0;
                                              _currentCardIndex = 0;
                                            });
                                          },
                                          child: Text("Yes"),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : CameraPreview(_controller),
                    Positioned(
                      bottom: 30,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _showCapturedPhoto
                            ? [
                                FloatingActionButton(
                                  heroTag: "retakeBtn",
                                  mini: true,
                                  onPressed: () {
                                    setState(() {
                                      _showCapturedPhoto = false;
                                      _imageFile = null;
                                      _showSetPrompt = false;
                                      _showCurrentSet = false;
                                      _detectedSets = [];
                                    });
                                  },
                                  child: Icon(Icons.refresh),
                                ),
                              ]
                            : [
                                FloatingActionButton(
                                  heroTag: "galleryBtn",
                                  mini: true,
                                  onPressed: _pickFromGallery,
                                  child: Icon(Icons.photo_library),
                                ),
                                SizedBox(width: 20),
                                FloatingActionButton(
                                  heroTag: "cameraBtn",
                                  onPressed: _takePhoto,
                                  child: Icon(Icons.camera_alt),
                                ),
                              ],
                      ),
                    ),
                  ],
                );
              },
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

class HighlightPainter extends CustomPainter {
  final Rect normalizedRect;
  final double imageWidth;
  final double imageHeight;
  final double offsetX;
  final double offsetY;
  HighlightPainter(this.normalizedRect, this.imageWidth, this.imageHeight, this.offsetX, this.offsetY);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final scaledRect = Rect.fromLTWH(
      offsetX + normalizedRect.left * imageWidth,
      offsetY + normalizedRect.top * imageHeight,
      normalizedRect.width * imageWidth,
      normalizedRect.height * imageHeight,
    );

    canvas.drawRect(scaledRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
