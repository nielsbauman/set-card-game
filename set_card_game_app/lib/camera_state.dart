import 'package:flutter/material.dart' hide Card;
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:developer';
import 'package:path_provider/path_provider.dart';

import 'set_matcher.dart';
import 'object_detection.dart';
import 'card.dart';

// --- Constants for UI layout and styling ---
const double _buttonRowBottomPadding = 30.0;
const double _cameraButtonSpacing = 20.0;
const double _setsButtonLeftPadding = 10.0;

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
      _imageFile = image;
      _showCapturedPhoto = true;
    });
  }

  Future<void> _saveImage() async {
    if (_imageFile == null) return;

    try {
      // 1. Find the downloads directory.
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

      // 2. Create the custom folder if it doesn't exist.
      final String customFolderPath = '${downloadsDirectory.path}/set-card-game/saved-images';
      final Directory customDir = Directory(customFolderPath);
      if (!await customDir.exists()) {
        await customDir.create(recursive: true);
      }

      // 3. Copy the image file to the new location.
      final String fileName = _imageFile!.path.split('/').last;
      final String newPath = '${customDir.path}/$fileName';
      final File originalFile = File(_imageFile!.path);
      await originalFile.copy(newPath);

      // 4. Show feedback to the user.
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

  /// Handles cycling through cards and sets when viewing them.
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

  /// Handles long press gestures to allow for card correction.
  void _handleLongPress(LongPressStartDetails details) {
    if (_showCurrentSet) {
      setState(() {
        _showCurrentSet = false;
      });
    }
    final Offset tapPosition = details.localPosition;

    // Find which card (if any) was tapped by checking bounding boxes
    final (Card, DetectedObject)? tappedCardTuple = _detectedCards
        .cast()
        .firstWhere((cardTuple) => _calculateScaledRect(cardTuple.$2.boundingBox).contains(tapPosition), orElse: () => null);

    if (mounted == false) {
      return;
    }
    // A card was long-pressed, show the correction dialog
    final TextEditingController textController = TextEditingController(text: tappedCardTuple == null ? '' : tappedCardTuple.$1.toString());
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(tappedCardTuple == null ? "Add Card" : "Correct Card Label"),
          content: TextField(
            controller: textController,
            decoration: InputDecoration(hintText: "e.g., rof1"),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text("Confirm"),
              onPressed: () {
                final String inputText = textController.text.trim();
                if (inputText.isEmpty) {
                  Navigator.of(context).pop();
                  return;
                }

                final Card newCard;
                try {
                  newCard = Card.fromShort(inputText.toLowerCase());
                  log("Original card: ${tappedCardTuple?.$1}, New card: $newCard");
                } catch (e) {
                  log("Invalid card format: $e");
                  // Show an error message if the format is incorrect.
                  // The dialog remains open for the user to try again.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Invalid format. Use format like 'rof1'."),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (tappedCardTuple == null) {
                  // TODO: Implement adding new card
                  log("Didn't implement adding yet");
                } else {
                  // Find the index of the card to be replaced.
                  final int cardIndex = _detectedCards.indexOf(tappedCardTuple);
                  // Update the state to reflect the changes.
                  setState(() {
                    // 1. Create a new list with the corrected card.
                    final updatedDetectedCards = List<(Card, DetectedObject)>.from(_detectedCards);
                    updatedDetectedCards[cardIndex] = (newCard, tappedCardTuple!.$2);
                    _detectedCards = updatedDetectedCards;

                    // 2. Re-run the set matching logic on the updated list.
                    final newComputedSets = SetMatcher.computeBruteForce(_detectedCards);
                    _detectedSets = newComputedSets.map((e) => e.toList()).toList();

                    // 3. Ensure we are not in viewing mode after a correction.
                    _showCurrentSet = false;
                  });
                }

                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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
      _showCurrentSet = false;
      _detectedCards = [];
      _detectedSets = [];
    });
  }

  Rect _calculateScaledRect(Rect rect) {
    return Rect.fromLTWH(
      _imageOffsetX + rect.left * _imageDisplayWidth,
      _imageOffsetY + rect.top * _imageDisplayHeight,
      rect.width * _imageDisplayWidth,
      rect.height * _imageDisplayHeight,
    );
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
                if (_showCapturedPhoto) _buildSetsFoundButton(),
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
      onLongPressStart: _handleLongPress,
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
          if (_imageDisplayWidth == 0) Builder(
            builder: (context) {
              _updateImageLayout();
              return const SizedBox.shrink();
            },
          ),
          // Iterate over all detected cards to draw their text and potential highlight.
          if (_imageDisplayWidth != 0) ..._detectedCards.map((cardTuple) {
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
                calculateScaledRect: _calculateScaledRect,
                isHighlighted: isHighlighted,
              ),
              child: Container(),
            );
          }),
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

  /// Builds the button that shows the number of sets and starts the viewing process.
  Widget _buildSetsFoundButton() {
    return Positioned(
      bottom: _buttonRowBottomPadding,
      left: _setsButtonLeftPadding,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.style),
        label: Text("${_detectedSets.length} Sets"),
        onPressed: () {
          setState(() {
            if (_showCurrentSet) {
              _showCurrentSet = false;
              return;
            }
            _currentSetIndex = 0;
            _currentCardIndex = 0;
            _showCurrentSet = true;
          });
        },
      ),
    );
  }
}

class HighlightPainter extends CustomPainter {
  final Rect Function(Rect) calculateScaledRect;
  final (Card, DetectedObject) cardTuple;
  final bool isHighlighted;

  // --- Constants for styling the highlight ---
  static const double _highlightTextTopPadding = 5.0;
  static const double _shapeSize = 16.0;
  static const double _shapeSpacing = 2.0;

  HighlightPainter({
    required this.calculateScaledRect,
    required this.cardTuple,
    required this.isHighlighted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaledRect = calculateScaledRect(cardTuple.$2.boundingBox);

    if (isHighlighted) {
      final paint = Paint()
        ..color = Colors.yellow.withOpacity(0.5)
        ..style = PaintingStyle.fill;
      canvas.drawRect(scaledRect, paint);
    }

    _paintShapes(canvas, scaledRect, cardTuple.$1);
  }

  void _paintShapes(Canvas canvas, Rect scaledRect, Card card) {
    final count = card.count;

    final totalWidth = count * _shapeSize + (count - 1) * _shapeSpacing;
    final startX = scaledRect.center.dx - totalWidth / 2;
    final y = scaledRect.top + _highlightTextTopPadding;

    for (int i = 0; i < count; i++) {
      final x = startX + i * (_shapeSize + _shapeSpacing);
      final rect = Rect.fromLTWH(x, y, _shapeSize, _shapeSize);
      _drawShape(canvas, rect, card.shape, _getColor(card.color), card.filling);
    }
  }

  void _drawShape(Canvas canvas, Rect rect, Shape shape, Color color, Filling filling) {
    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final Paint strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final Path shapePath = switch (shape) {
      Shape.OVAL => Path()..addOval(rect),
      Shape.RHOMBUS => _rhombusPath(rect),
      Shape.WAVE => _wavePath(rect),
    };

    switch (filling) {
      case Filling.FILLED:
        canvas.drawPath(shapePath, fillPaint);
      case Filling.EMPTY:
        canvas.drawPath(shapePath, strokePaint);
      case Filling.PARTIAL:
        canvas.drawPath(shapePath, strokePaint);
        // Draw two vertical lines at 1/3 and 2/3 of the width, clipped to the shape
        final x1 = rect.left + rect.width / 3;
        final x2 = rect.left + 2 * rect.width / 3;
        canvas.save();
        canvas.clipPath(shapePath);
        canvas.drawLine(
          Offset(x1, rect.top),
          Offset(x1, rect.bottom),
          strokePaint,
        );
        canvas.drawLine(
          Offset(x2, rect.top),
          Offset(x2, rect.bottom),
          strokePaint,
        );
        canvas.restore();
    }
  }

  Path _rhombusPath(Rect rect) {
    final path = Path();
    path.moveTo(rect.center.dx, rect.top);
    path.lineTo(rect.right, rect.center.dy);
    path.lineTo(rect.center.dx, rect.bottom);
    path.lineTo(rect.left, rect.center.dy);
    path.close();
    return path;
  }

  Path _wavePath(Rect rect) {
    final path = Path();
    final left = rect.left;
    final top = rect.top;
    final width = rect.width;
    final height = rect.height;

    // Top wave curve
    path.moveTo(left, top + height * 0.35);
    path.cubicTo(
      left + width * 0.25, top,
      left + width * 0.75, top + height * 0.7,
      left + width, top + height * 0.35,
    );
    // Bottom wave curve (mirrored)
    path.cubicTo(
      left + width * 0.75, top + height * 0.7 + height * 0.3,
      left + width * 0.25, top + height,
      left, top + height * 0.35 + height * 0.3,
    );
    path.close();
    return path;
  }

  Color _getColor(CardColor cardColor) {
    switch (cardColor) {
      case CardColor.GREEN:
        return Colors.green;
      case CardColor.PURPLE:
        return Colors.purple;
      case CardColor.RED:
        return Colors.red;
    }
  }

  @override
  bool shouldRepaint(covariant HighlightPainter oldDelegate) {
    return cardTuple != oldDelegate.cardTuple || isHighlighted != oldDelegate.isHighlighted;
  }
}
