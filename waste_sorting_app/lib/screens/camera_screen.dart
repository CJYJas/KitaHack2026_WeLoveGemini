import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'result_screen.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isProcessing = false;
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      setState(() => _isProcessing = true);
      await _initializeControllerFuture;

      final image = await _controller.takePicture();
      final File imageFile = File(image.path);

      // Simulate ML Prediction on device (or just pass a placeholder if server does it all)
      // The prompt says "Uses real-time Computer Vision", implying on-device logic?
      // But the architecture says "Cloud Function invokes... classification".
      // The backend code in `index.js` uses Gemini to VALIDATE the ML prediction.
      // It expects `mlPrediction` in the body.
      // For now, I'll hardcode a "user claim" or let the user type it in the next screen?
      // Or maybe I should just send a dummy prediction for now since I don't have the TF Lite model.
      
      if (!mounted) return;

      // Navigate to a preview/claim screen or directly submit?
      // Let's show a dialog to get User Claim and ML Prediction (simulated) for now.
      _showClaimDialog(imageFile);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showClaimDialog(File imageFile) {
    final claimController = TextEditingController();
    final predictionController = TextEditingController(text: 'Plastic'); // Default

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: claimController,
              decoration: const InputDecoration(labelText: 'What is this item? (User Claim)'),
            ),
            TextField(
              controller: predictionController,
              decoration: const InputDecoration(labelText: 'ML Prediction (Simulated)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _submitImage(imageFile, claimController.text, predictionController.text);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitImage(File image, String claim, String prediction) async {
    setState(() => _isProcessing = true);
    try {
      final result = await _apiService.submitImage(
        imageFile: image,
        userClaim: claim,
        mlPrediction: prediction,
      );

      // Increment scan count locally for the Iceberg scaling
      final prefs = await SharedPreferences.getInstance();
      int currentCount = prefs.getInt('scan_count') ?? 0;
      await prefs.setInt('scan_count', currentCount + 1);

      // Increment total points (10 points per scan)
      int currentPoints = prefs.getInt('total_points') ?? 0;
      await prefs.setInt('total_points', currentPoints + 10);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ResultScreen(result: result, imageFile: image),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e')),
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
                // Camera Preview
                Center(child: CameraPreview(_controller)),
                
                // Overlay for scanning guide
                Center(
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white54, width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),

                // Top Bar with Back Button
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ),
                ),

                // Processing Indicator
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),

                // Bottom Control Bar
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 30),
                    width: double.infinity,
                    decoration: const BoxDecoration(
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
                          'Center item in box',
                          style: GoogleFonts.quicksand(color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _isProcessing ? null : _takePicture,
                          child: Container(
                            height: 80,
                            width: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              color: Colors.white24,
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
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
