import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final File imageFile;

  const ResultScreen({super.key, required this.result, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    bool isMLWrong = result['verdict'] == 'ML_WRONG';
    String aiThought = result['ai_thought'] ?? 'No analysis provided.';
    double confidence = (result['confidence'] ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: Text('Appraisal Result', style: GoogleFonts.poppins()),
        backgroundColor: isMLWrong ? Colors.orange : Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(imageFile, height: 300, fit: BoxFit.cover),
            ),
            const SizedBox(height: 24),
            Text(
              isMLWrong ? 'Correction Needed!' : 'Great Sorting!',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isMLWrong ? Colors.orange[800] : Colors.green[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Analysis',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      aiThought,
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Confidence:', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                        Text('${confidence.toStringAsFixed(1)}%', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.black87,
              ),
              child: Text('Scan Next Item', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
