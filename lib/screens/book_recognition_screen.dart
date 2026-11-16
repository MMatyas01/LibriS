import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';
import 'book_details_screen.dart';

class BookRecognitionScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const BookRecognitionScreen({super.key, this.onNavigateToTab});

  @override
  State<BookRecognitionScreen> createState() => _BookRecognitionScreenState();
}

class _BookRecognitionScreenState extends State<BookRecognitionScreen>
    with WidgetsBindingObserver {
  // Kamera változók
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;

  // OCR
  late final TextRecognizer _textRecognizer;

  // UI állapotok
  bool _isScanningInsidePage = false;
  bool _isProcessing = false;
  String _statusText = 'No book identified yet';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _statusText = 'No cameras found on this device';
        });
        return;
      }

      final camera = _cameras[_selectedCameraIndex];
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusText = 'Error initializing camera: $e';
        });
      }
    }
  }

  void _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _isFlashOn = !_isFlashOn;
    });

    await _controller!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    setState(() {
      _isCameraInitialized = false;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    });

    await _controller?.dispose();
    await _initializeCamera();
  }

  // ---------- FŐ LOGIKA: KÉP RÖGZÍTÉSE ÉS FELISMERÉSE ----------

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôöő]'), 'o')
        .replaceAll(RegExp(r'[úùûüű]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '') 
        .replaceAll(RegExp(r'\s+'), ' ')        
        .trim();
  }

  List<String> _getWords(String text) {
    return _normalizeText(text)
        .split(' ')
        .where((w) => w.length >= 3)
        .toList();
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.filled(t.length + 1, 0);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < v0.length; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = _min3(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost);
      }
      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }

  int _min3(int a, int b, int c) {
    return (a < b) ? ((a < c) ? a : c) : ((b < c) ? b : c);
  }

  bool _isSimilar(String a, String b) {
    if (a == b) return true;
    if (a.contains(b) || b.contains(a)) return true;
    final dist = _levenshtein(a, b);
    return dist <= 2;
  }

  Future<void> _captureAndRecognize() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    try {
      final XFile image = await _controller!.takePicture();
      await _processImage(File(image.path));
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = 'Error capturing image: $e';
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        await _processImage(File(image.path));
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = 'Error picking image: $e';
      });
    }
  }

  Future<void> _processImage(File imageFile) async {
    setState(() {
      _isProcessing = true;
      _statusText = 'Processing image...';
    });

    try {
      final InputImage inputImage = InputImage.fromFilePath(imageFile.path);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      final String extractedText = recognizedText.text.trim();

      if (extractedText.isEmpty) {
        setState(() {
          _isProcessing = false;
          _statusText = 'No text found';
        });
        _showScanInsideDialog('');
        return;
      }

      final Map<String, dynamic>? foundBook =
          await _searchBookInFirestore(extractedText);

      if (foundBook == null) {
        setState(() {
          _isProcessing = false;
          _statusText = 'No matching book found';
        });
        _showScanInsideDialog(extractedText);
        return;
      }

      final String? status = await _getLibraryStatus(foundBook['id']);

      setState(() {
        _isProcessing = false;
        _statusText = 'Book found!';
      });

      _showBookFoundDialog(foundBook, status);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = 'Error processing image: $e';
      });
    }
  }

  Future<Map<String, dynamic>?> _searchBookInFirestore(String text) async {
    final booksRef = FirebaseFirestore.instance.collection('books');

    final isbnMatch = RegExp(r'\b(?:97[89])?\d{9,13}\b').firstMatch(text);
    if (isbnMatch != null) {
      final isbn = isbnMatch.group(0);
      final snapshot =
          await booksRef.where('isbn', isEqualTo: isbn).limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        data['id'] = snapshot.docs.first.id;
        return data;
      }
    }

    final ocrWords = _getWords(text);
    if (ocrWords.isEmpty) return null;

    final allBooksSnapshot = await booksRef.get();

    for (final doc in allBooksSnapshot.docs) {
      final data = doc.data();
      final titleWords = _getWords((data['title'] ?? '').toString());
      final authorWords = _getWords((data['author'] ?? '').toString());

      if (titleWords.isNotEmpty) {
        int matchedTitleWords = 0;
        for (final tWord in titleWords) {
          if (ocrWords.any((oWord) => _isSimilar(oWord, tWord))) {
            matchedTitleWords++;
          }
        }
        if (matchedTitleWords / titleWords.length >= 0.7) {
          data['id'] = doc.id;
          return data;
        }
      }

      if (authorWords.isNotEmpty) {
        int matchedAuthorWords = 0;
        for (final aWord in authorWords) {
          if (ocrWords.any((oWord) => _isSimilar(oWord, aWord))) {
            matchedAuthorWords++;
          }
        }
        if (matchedAuthorWords / authorWords.length >= 0.7) {
          data['id'] = doc.id;
          return data;
        }
      }
    }

    return null;
  }

  Future<String?> _getLibraryStatus(String bookId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection('library_entries')
        .where('userId', isEqualTo: userId)
        .where('bookId', isEqualTo: bookId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data()['status'] as String?;
    }
    return null;
  }

  // ---------- DIALÓGUSOK ----------

  void _showBookFoundDialog(Map<String, dynamic> book, String? status) {
    String statusText;
    if (status == null) {
      statusText = 'Not in your library';
    } else if (status == 'reading') {
      statusText = 'In your library · Reading';
    } else if (status == 'finished') {
      statusText = 'In your library · Finished';
    } else {
      statusText = 'In your library · Want to read';
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Book found!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book['title'] ?? 'Unknown Title',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(book['author'] ?? 'Unknown Author'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: const TextStyle(
                  color: AppColors.forest,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext); 
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookDetailsScreen(
                    bookId: book['id'],
                    bookData: book,
                    currentStatus: status,
                    onNavigateToTab: widget.onNavigateToTab ?? (index) {}, 
                  ),
                ),
              );
            },
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }

  void _showScanInsideDialog(String extractedText) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Book not found'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'We couldn\'t read the cover or find it in our catalogue. Would you like to scan the title page instead?',
              ),
              if (extractedText.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Text we found (Debug):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    extractedText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isScanningInsidePage = true;
                _statusText = 'Point at the title page';
              });
            },
            child: const Text('Scan Inside Page'),
          ),
        ],
      ),
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _isCameraInitialized && _controller != null
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize?.height ??
                            screenSize.width,
                        height: _controller!.value.previewSize?.width ??
                            screenSize.height,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),

          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth * 0.04,
                        vertical: constraints.maxHeight * 0.02,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: textColor),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'Recognize a book',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: screenSize.width * 0.05,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: screenSize.height * 0.005),
                                Text(
                                  'Point your camera at a book cover. We\'ll look for a match in the catalogue.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.8),
                                    fontSize: screenSize.width * 0.03,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isFlashOn ? Icons.flash_on : Icons.flash_off,
                              color: _isFlashOn ? Colors.yellow : textColor,
                            ),
                            onPressed: _toggleFlash,
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 3 / 4,
                          child: Container(
                            margin: EdgeInsets.symmetric(
                              horizontal: constraints.maxWidth * 0.1,
                              vertical: constraints.maxHeight * 0.05,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: screenSize.width * 0.005,
                              ),
                              borderRadius: BorderRadius.circular(
                                  screenSize.width * 0.04),
                            ),
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth * 0.04,
                        vertical: constraints.maxHeight * 0.02,
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              vertical: screenSize.height * 0.01,
                              horizontal: screenSize.width * 0.04,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(
                                  screenSize.width * 0.05),
                            ),
                            child: Text(
                              _isScanningInsidePage
                                  ? 'KEEP THE TITLE PAGE IN FRAME'
                                  : 'KEEP THE WHOLE COVER IN FRAME',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenSize.width * 0.03,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),

                          SizedBox(height: constraints.maxHeight * 0.03),

                          Text(
                            _statusText,
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.7),
                              fontSize: screenSize.width * 0.035,
                            ),
                          ),

                          SizedBox(height: constraints.maxHeight * 0.02),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildActionButton(
                                icon: Icons.photo_library,
                                onTap: _isProcessing ? () {} : _pickImageFromGallery,
                                size: screenSize.width * 0.12,
                              ),

                              GestureDetector(
                                onTap: _isProcessing || !_isCameraInitialized
                                    ? null
                                    : _captureAndRecognize,
                                child: Container(
                                  width: screenSize.width * 0.2,
                                  height: screenSize.width * 0.2,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: screenSize.width * 0.015,
                                    ),
                                  ),
                                  child: Center(
                                    child: _isProcessing
                                        ? SizedBox(
                                            width: screenSize.width * 0.08,
                                            height: screenSize.width * 0.08,
                                            child: const CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 3,
                                            ),
                                          )
                                        : Container(
                                            width: screenSize.width * 0.15,
                                            height: screenSize.width * 0.15,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: primaryColor,
                                            ),
                                          ),
                                  ),
                                ),
                              ),

                              _buildActionButton(
                                icon: Icons.flip_camera_ios,
                                onTap: _switchCamera,
                                size: screenSize.width * 0.12,
                              ),
                            ],
                          ),

                          SizedBox(height: constraints.maxHeight * 0.02),

                          TextButton(
                            onPressed: () {
                              // JAVÍTVA: Visszalépés a DiscoverScreen-re
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Search manually instead',
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.8),
                                fontSize: screenSize.width * 0.035,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.6,
        ),
      ),
    );
  }
}