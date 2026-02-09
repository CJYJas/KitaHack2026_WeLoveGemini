import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// Function to send complaint
Future<void> sendComplaint({
  required String imagePath,
  required String userClaim,
  required String mlPrediction,
  required String userId,
}) async {
  final file = File(imagePath);
  if (!file.existsSync()) {
    print("❌ File not found: $imagePath");
    return;
  }

  final imageBytes = file.readAsBytesSync();
  final base64Image = base64Encode(imageBytes);

  final payload = {
    "imageBase64": base64Image,
    "userClaimLabel": userClaim,
    "mlPrediction": mlPrediction,
    "userId": userId,
  };

  // Replace with your deployed Cloud Function URL
  final uri = Uri.parse('https://verifycomplaint-dttoblbq3q-uc.a.run.app');

  try {
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print("\n✅ Verdict: ${data['verdict']}");
      print("Confidence: ${data['confidence']}");
      print("Low Confidence: ${data['low_confidence']}");
      print("Message: ${data['message']}");
      print("Image URL: ${data['image_url']}");
      print("Saved to Firestore: ${data['save']}");
      print("System Accuracy: ${data['accuracy']}%\n");
    } else {
      print("❌ Error ${response.statusCode}: ${response.body}");
    }
  } catch (e) {
    print("❌ Exception sending complaint: $e");
  }
}

void main() async {
  print("=== Interactive User Complaint Test ===");

  stdout.write("Enter user ID: ");
  String userId = stdin.readLineSync() ?? "user123";

  stdout.write("Enter ML prediction: ");
  String mlPrediction = stdin.readLineSync() ?? "plastic";

  stdout.write("Enter your claim (can be a sentence): ");
  String userClaim = stdin.readLineSync() ?? "";

  stdout.write("Enter path to image file: ");
  String imagePath = stdin.readLineSync() ?? "";

  await sendComplaint(
    imagePath: imagePath,
    userClaim: userClaim,
    mlPrediction: mlPrediction,
    userId: userId,
  );

  print("\n=== Test Complete ===");
}
