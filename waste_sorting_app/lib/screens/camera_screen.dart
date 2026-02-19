import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'result_screen.dart';
import '../services/api_service.dart';
import '../services/waste_classifier_service.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _cameraController;
  late Future<void> _initializeControllerFuture;
  bool _isProcessing = false;
  List<WasteClassification>? _classifications;
  File? _capturedImageFile;
  final _apiService = ApiService();
  final _classifierService = WasteClassifierService();
  bool _modelInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeTFLite();
  }

  /// Initialize camera
  void _initializeCamera() {
    _cameraController = CameraController(
      widget.cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeControllerFuture = _cameraController.initialize();
  }

  /// Initialize classifier model
  Future<void> _initializeTFLite() async {
    try {
      await _classifierService.initialize();
      setState(() => _modelInitialized = true);
      print('[App] Classifier initialized successfully');
    } catch (e) {
      print('[App] Failed to initialize classifier: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load AI model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _classifierService.dispose();
    super.dispose();
  }

  /// Capture photo and run classification
  Future<void> _captureAndClassify() async {
    if (_isProcessing || !_modelInitialized) return;

    try {
      setState(() => _isProcessing = true);
      await _initializeControllerFuture;

      // Take picture
      final picture = await _cameraController.takePicture();
      final imageFile = File(picture.path);

      print('[Camera] Image captured: ${imageFile.path}');

      if (!mounted) return;

      // Run classification
      final classifications = await _classifierService.classifyImage(imageFile);

      setState(() {
        _classifications = classifications;
        _capturedImageFile = imageFile;
      });

      // Show results dialog
      _showClassificationDialog();
    } catch (e) {
      print('[Camera] Capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Show classification results dialog
  void _showClassificationDialog() {
    if (_classifications == null || _classifications!.isEmpty) return;

    final topResult = _classifications![0];
    final isHighConfidence =
        _classifierService.isHighConfidence(topResult.confidence);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Classification Result',
          style: TextStyle(
            color: Color(0xFF2E7D32),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main result
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isHighConfidence ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isHighConfidence ? Colors.green : Colors.orange,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      topResult.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isHighConfidence
                            ? Colors.green[700]
                            : Colors.orange[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Confidence: ${_classifierService.formatConfidence(topResult.confidence)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Detection Summary:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._classifications!.asMap().entries.map((entry) {
                int index = entry.key;
                WasteClassification c = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '${index + 1}. ${c.label}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        _classifierService.formatConfidence(c.confidence),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _classifications = null;
                _capturedImageFile = null;
              });
            },
            child: const Text('Retake'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showComplaintDialog();
            },
            child: const Text(
              'Complaint',
              style: TextStyle(color: Colors.orange),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              Navigator.pop(context);
              _submitToBackend(topResult);
            },
            child: const Text(
              'Confirm',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Show complaint dialog for incorrect classification
  /// Allows user to report false positives
  void _showComplaintDialog() {
    final complaintController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Report Incorrect Classification',
          style: TextStyle(color: Colors.orange),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What is the correct waste type?'),
            const SizedBox(height: 12),
            TextField(
              controller: complaintController,
              decoration: InputDecoration(
                hintText: 'Enter correct classification...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your feedback helps improve our model!',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            onPressed: () {
              Navigator.pop(context);
              _submitComplaint(complaintController.text);
            },
            child: const Text(
              'Submit Complaint',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Submit complaint to backend
  Future<void> _submitComplaint(String correctLabel) async {
    if (_classifications == null || _capturedImageFile == null) return;

    setState(() => _isProcessing = true);
    try {
      print('[Complaint] Submitting complaint...');
      print('[Complaint] Model predicted: ${_classifications![0].label}');
      print('[Complaint] Correct label: $correctLabel');

      // TODO: Call complaint_backend API
      // This should send:
      // - Image
      // - Model prediction
      // - User's correction
      // - User ID

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Complaint submitted. Thank you for helping!'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _classifications = null;
          _capturedImageFile = null;
        });
      }
    } catch (e) {
      print('[Complaint] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Submit classification to backend
  Future<void> _submitToBackend(WasteClassification classification) async {
    if (_capturedImageFile == null) return;

    setState(() => _isProcessing = true);
    try {
      print('[Backend] Submitting classification...');

      // Submit to backend API
      final result = await _apiService.submitImage(
        imageFile: _capturedImageFile!,
        userClaim: classification.label,
        mlPrediction: classification.label,
      );

      // Update local stats
      final prefs = await SharedPreferences.getInstance();
      int scanCount = prefs.getInt('scan_count') ?? 0;
      await prefs.setInt('scan_count', scanCount + 1);

      int totalPoints = prefs.getInt('total_points') ?? 0;
      await prefs.setInt('total_points', totalPoints + 10);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              result: result,
              imageFile: _capturedImageFile!,
            ),
          ),
        );
      }
    } catch (e) {
      print('[Backend] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                // Camera preview
                Positioned.fill(
                  child: CameraPreview(_cameraController),
                ),

                // Scanning guide overlay
                Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withOpacity(0.6),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),

                // Top bar with back button
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                ),

                // Processing indicator
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),

                // Status bar
                if (!_modelInitialized)
                  Positioned(
                    top: 60,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[900],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Loading AI model...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                // Bottom controls
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 30),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Position waste item in frame',
                          style: GoogleFonts.quicksand(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: (_isProcessing || !_modelInitialized)
                              ? null
                              : _captureAndClassify,
                          child: Container(
                            height: 80,
                            width: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                              color: Colors.white.withOpacity(0.3),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isProcessing)
                          const Text(
                            'Processing...',
                            style: TextStyle(
                              color: Colors.white,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
        },
      ),
    );
  }}