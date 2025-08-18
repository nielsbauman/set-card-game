import 'package:flutter/material.dart' hide Card;
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:developer';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'set_matcher.dart';
import 'object_detection.dart';
import 'card.dart';

// --- Constants for UI layout and styling ---
const double _buttonRowBottomPadding = 30.0;
const double _cameraButtonSpacing = 20.0;

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // --- Camera and Image State ---
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _showCapturedPhoto = false;
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  late ObjectDetection objectDetection;

  // --- Set Detection and UI State ---
  List<(Card, DetectedObject)> _detectedCards = [];
  List<List<(Card, DetectedObject)>> _detectedSets = [];
  bool _showSetPrompt = false;
  bool _showCurrentSet = false;
  int _currentSetIndex = 0;
  int _currentCardIndex = 0;

  // --- Image Layout Calculation State ---
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- Core Logic Methods ---

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _controller = CameraController(firstCamera, ResolutionPreset.max, enableAudio: false);
    _initializeControllerFuture = _controller.initialize();
    if (mounted) setState(() {});
  }

  void _takePhoto() async {
    await _initializeControllerFuture;
    final image = await _controller.takePicture();
    _runAnalysis(image);
  }

  void _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _runAnalysis(image);
    }
  }

  void _runAnalysis(XFile image) {
    final imageData = File(image.path).readAsBytesSync();
    final (drawnImage, detectedCards) = objectDetection.analyseImage(imageData);
    final computedSets = SetMatcher.computeBruteForce(detectedCards);
    setState(() {
      _detectedCards = detectedCards;
      _detectedSets = computedSets.map((e) => e.toList()).toList();
      _showSetPrompt = computedSets.isNotEmpty;
      _imageFile = image;
      _showCapturedPhoto = true;
    });
  }

  Future<void> _saveImage() async {
    if (_imageFile == null) return;

    // 1. Request storage permission.
    // Note: For iOS, you must add NSPhotoLibraryAddUsageDescription to your Info.plist.
    // For Android 10+, no permission is needed for saving to gallery.
    final status = await Permission.storage.request();

    if (!status.isGranted) {
      log('Storage permission is required to save images.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to save images.')),
        );
      }
      return;
    }

    try {
      // 2. Find the downloads directory.
      // Note: getExternalStorageDirectory() is typically the root of the public
      // storage, which often contains the "Download" folder.
      Directory? downloadsDirectory = await getExternalStorageDirectory();
      if (downloadsDirectory == null) {
        throw Exception("Could not find the downloads directory.");
      }

      // On some Android versions, we might need a more specific path.
      // This is a common path for the public downloads folder.
      final String downloadPath = '/storage/emulated/0/Download';
      downloadsDirectory = Directory(downloadPath);

      // 3. Create the custom folder if it doesn't exist.
      final String customFolderPath = '${downloadsDirectory.path}/set-card-game/saved-images';
      final Directory customDir = Directory(customFolderPath);
      if (!await customDir.exists()) {
        await customDir.create(recursive: true);
      }

      // 4. Copy the image file to the new location.
      final String fileName = _imageFile!.path.split('/').last;
      final String newPath = '${customDir.path}/$fileName';
      final File originalFile = File(_imageFile!.path);
      await originalFile.copy(newPath);

      // 5. Show feedback to the user.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image saved to: $newPath')),
        );
      }
    } catch (e) {
      log('Error saving image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    }
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

  void _resetState() {
    setState(() {
      _showCapturedPhoto = false;
      _imageFile = null;
      _showSetPrompt = false;
      _showCurrentSet = false;
      _detectedCards = [];
      _detectedSets = [];
    });
  }

  // --- Widget Building Methods ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              fit: StackFit.expand,
              children: [
                _buildCameraView(),
                _buildActionButtons(),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  /// Builds the main view, switching between the camera preview and the photo viewer.
  Widget _buildCameraView() {
    if (_showCapturedPhoto && _imageFile != null) {
      return _buildPhotoViewer();
    } else {
      return CameraPreview(_controller);
    }
  }

  /// Builds the view for displaying the captured photo with overlays.
  Widget _buildPhotoViewer() {
    return GestureDetector(
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
          // This builder triggers the layout update after the image is rendered.
          Builder(
            builder: (context) {
              _updateImageLayout();
              return const SizedBox.shrink();
            },
          ),
          // Iterate over all detected cards to draw their text and potential highlight.
          ..._detectedCards.map((cardTuple) {
            bool isHighlighted = false;
            // Check if the card should be highlighted.
            if (_showCurrentSet && _detectedSets.isNotEmpty) {
              final currentSetSlice = _detectedSets[_currentSetIndex].sublist(0, _currentCardIndex + 1);
              if (currentSetSlice.contains(cardTuple)) {
                isHighlighted = true;
              }
            }
            return CustomPaint(
              painter: HighlightPainter(
                cardTuple: cardTuple,
                imageWidth: _imageDisplayWidth,
                imageHeight: _imageDisplayHeight,
                offsetX: _imageOffsetX,
                offsetY: _imageOffsetY,
                isHighlighted: isHighlighted,
              ),
              child: Container(),
            );
          }).toList(),
          if (_showSetPrompt && !_showCurrentSet)
            Center(
              child: AlertDialog(
                title: Text("Found ${_detectedSets.length} sets!"),
                content: const Text("Would you like to view them one by one?"),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => _showSetPrompt = false),
                    child: const Text("No"),
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
                    child: const Text("Yes"),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the floating action buttons at the bottom of the screen.
  Widget _buildActionButtons() {
    return Positioned(
      bottom: _buttonRowBottomPadding,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _showCapturedPhoto
            ? [
                FloatingActionButton(
                  heroTag: "retakeBtn",
                  mini: true,
                  onPressed: _resetState,
                  child: const Icon(Icons.refresh),
                ),
                const SizedBox(width: _cameraButtonSpacing),
                FloatingActionButton(
                  heroTag: "saveBtn",
                  mini: true,
                  onPressed: _saveImage,
                  child: const Icon(Icons.save_alt),
                ),
              ]
            : [
                FloatingActionButton(
                  heroTag: "galleryBtn",
                  mini: true,
                  onPressed: _pickFromGallery,
                  child: const Icon(Icons.photo_library),
                ),
                const SizedBox(width: _cameraButtonSpacing),
                FloatingActionButton(
                  heroTag: "cameraBtn",
                  onPressed: _takePhoto,
                  child: const Icon(Icons.camera_alt),
                ),
              ],
      ),
    );
  }
}

class HighlightPainter extends CustomPainter {
  final (Card, DetectedObject) cardTuple;
  final double imageWidth;
  final double imageHeight;
  final double offsetX;
  final double offsetY;
  final bool isHighlighted;
  final Rect rect;

  // --- Constants for styling the highlight ---
  static const double _highlightTextFontSize = 16.0;
  static const double _highlightTextTopPadding = 5.0;

  HighlightPainter({
    required this.cardTuple,
    required this.imageWidth,
    required this.imageHeight,
    required this.offsetX,
    required this.offsetY,
    required this.isHighlighted,
  }) : rect = cardTuple.$2.boundingBox;

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the actual on-screen coordinates for the highlight box
    final scaledRect = Rect.fromLTWH(
      offsetX + rect.left * imageWidth,
      offsetY + rect.top * imageHeight,
      rect.width * imageWidth,
      rect.height * imageHeight,
    );

    // Only draw the highlight rectangle if the card is part of the current set
    if (isHighlighted) {
      final paint = Paint()
        ..color = Colors.yellow.withOpacity(0.5)
        ..style = PaintingStyle.fill;
      canvas.drawRect(scaledRect, paint);
    }

    // Always draw the text description for the card
    _paintText(canvas, scaledRect);
  }

  /// Helper method to paint the text onto the canvas.
  void _paintText(Canvas canvas, Rect scaledRect) {
    const textStyle = TextStyle(
      color: Colors.black,
      fontSize: _highlightTextFontSize,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.white54,
    );

    final cardShortString = cardTuple.$1.toString();
    final textSpan = TextSpan(text: cardShortString, style: textStyle);

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(minWidth: 0, maxWidth: scaledRect.width);

    final textOffset = Offset(
      scaledRect.center.dx - (textPainter.width / 2),
      scaledRect.top + _highlightTextTopPadding,
    );

    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant HighlightPainter oldDelegate) {
    return rect != oldDelegate.rect ||
        imageWidth != oldDelegate.imageWidth ||
        imageHeight != oldDelegate.imageHeight ||
        offsetX != oldDelegate.offsetX ||
        offsetY != oldDelegate.offsetY ||
        cardTuple != oldDelegate.cardTuple ||
        isHighlighted != oldDelegate.isHighlighted;
  }
}
