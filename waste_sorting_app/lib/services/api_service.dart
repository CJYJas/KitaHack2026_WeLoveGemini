import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cloud Functions Base URL
  static const String _baseUrl = 'https://us-central1-kitahack2026-3d5f3.cloudfunctions.net';
  static const String _verifyComplaintUrl = 'https://verifycomplaint-dttoblbq3q-uc.a.run.app';

  // Sign Up
  // Returns true if successful, throws exception otherwise
  Future<void> signUp(String email, String password, String username, String icNumber) async {
    final url = Uri.parse('$_baseUrl/signUp');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'username': username,
          'icNumber': icNumber,
        }),
      );

      if (response.statusCode == 200) {
        // Backend created the user. Now allow the user to sign in immediately 
        // using the credentials to get the Firebase ID Token for subsequent requests.
        await _auth.signInWithEmailAndPassword(email: email, password: password);
        
        // Save IC number locally for future API calls
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_ic', icNumber);
        await prefs.setString('username', username);
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Failed to sign up');
      }
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  // Login
  // Uses Firebase Auth to sign in, then validates with backend if needed.
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // 1. Sign in with Firebase Auth client-side
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      String? token = await userCredential.user?.getIdToken();
      if (token == null) throw Exception("Failed to retrieve ID Token");

      // 2. Call backend login endpoint (optional, but good for getting extra user data like IC)
      final url = Uri.parse('$_baseUrl/login');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Save IC number and other data locally
        final prefs = await SharedPreferences.getInstance();
        if (data['icNumber'] != null) await prefs.setString('user_ic', data['icNumber']);
        if (data['username'] != null) await prefs.setString('username', data['username']);
        
        return data;
      } else {
         // Fallback: if backend fails but firebase auth succeeded, we might still want to proceed
         // or throw. For now, let's throw to ensure data consistency.
         final data = jsonDecode(response.body);
         throw Exception(data['error'] ?? 'Backend login validation failed');
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Get Current User ID Token
  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }
  
  // Submit Image for Classification
  Future<Map<String, dynamic>> submitImage({
    required File imageFile,
    required String userClaim,
    required String mlPrediction, // This would come from TFLite on device ideally, simulating for now
  }) async {
    try {
      final token = await getIdToken();
      if (token == null) throw Exception("User not authenticated");

      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      final userId = _auth.currentUser?.uid ?? "";

      // Construct payload matching backend expectations
      // Note: Backend requires imageBase64 to include data URI scheme sometimes? 
      // Checking index.js: `const mimeMatch = imageBase64.match(/^data:(image\/\w+);base64,/)`
      // It expects a data URI.
      
      String mimeType = 'image/jpeg'; // Assuming JPEG from camera
      String base64DataUri = 'data:$mimeType;base64,$base64Image';

      final payload = {
        "imageBase64": base64DataUri,
        "userClaimLabel": userClaim,
        "mlPrediction": mlPrediction,
        "userId": userId,
      };

      final response = await http.post(
        Uri.parse(_verifyComplaintUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Classification failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Error submitting image: $e');
    }
  }

  // Feature 1: Record Scan
  Future<void> recordScan({
    required String category,
    required double confidence,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final icNumber = prefs.getString('user_ic');
      if (icNumber == null) throw Exception("IC Number not found");

      final url = Uri.parse('$_baseUrl/recordScan');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'icNumber': icNumber,
          'category': category,
          'confidence': confidence,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to record scan: ${response.body}');
      }
    } catch (e) {
      throw Exception('Record scan error: $e');
    }
  }

  // Feature 3: Get Leaderboard
  Future<Map<String, dynamic>> getLeaderboard({required String type}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final icNumber = prefs.getString('user_ic');
      if (icNumber == null) throw Exception("IC Number not found");

      final url = Uri.parse('$_baseUrl/getLeaderboard?icNumber=$icNumber&type=$type');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get leaderboard: ${response.body}');
      }
    } catch (e) {
      throw Exception('Leaderboard error: $e');
    }
  }

  // Feature 4: Redeem Voucher
  Future<Map<String, dynamic>> redeemVoucher() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final icNumber = prefs.getString('user_ic');
      if (icNumber == null) throw Exception("IC Number not found");

      final url = Uri.parse('$_baseUrl/redeemVoucher');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'icNumber': icNumber}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Redemption error: $e');
    }
  }

  // Feature 5: Get Scan History
  Future<List<dynamic>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final icNumber = prefs.getString('user_ic');
      if (icNumber == null) throw Exception("IC Number not found");

      final url = Uri.parse('$_baseUrl/getScans?icNumber=$icNumber');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['scans'] ?? [];
      } else {
        throw Exception('Failed to get history: ${response.body}');
      }
    } catch (e) {
      throw Exception('History error: $e');
    }
  }
  // Get User Profile (latest points/username)
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final icNumber = prefs.getString('user_ic');
      if (icNumber == null) throw Exception("IC Number not found");

      final url = Uri.parse('$_baseUrl/getUserProfile?icNumber=$icNumber');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Update local cache as well
        if (data['points'] != null) await prefs.setInt('total_marks', data['points']);
        if (data['username'] != null) await prefs.setString('username', data['username']);
        
        return data;
      } else {
        throw Exception('Failed to get user profile: ${response.body}');
      }
    } catch (e) {
      throw Exception('Profile fetch error: $e');
    }
  }
}
