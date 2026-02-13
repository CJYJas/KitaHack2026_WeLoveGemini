const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");
const { v4: uuidv4 } = require("uuid");
const { user } = require("firebase-functions/v1/auth");
require("dotenv").config();

admin.initializeApp({
  storageBucket: "kitahack2026-3d5f3.firebasestorage.app"
});

const db = admin.firestore();
const bucket = admin.storage().bucket();
const GEMINI_KEY = process.env.GEMINI_API_KEY;

//sign up function
exports.signUp = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.status(204).send("");

  try {
    const { email, password, username, icNumber } = req.body;
    if (!email || !password || !username || !icNumber) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: username,
    });

    await db.collection("users").doc(icNumber).set({
      username : username,
      email: email,
      icNumber: icNumber,
      firebaseUid : userRecord.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    return res.json({
      success : true,
      icKey : icNumber,
      message: "User created successfully",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error("Error creating user:", error);
    return res.status(500).json({ error: error.message });
  }
});

//login function
exports.login = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") return res.status(204).send("");

  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({ error: "No token provided" });
    }

    const idToken = authHeader.split("Bearer ")[1];
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const firebaseUid = decodedToken.uid;

    const userQuery = await db.collection("users").where("firebaseUid", "==", firebaseUid).limit(1).get();
    
    if (userQuery.empty) {
      return res.status(404).json({ error: "User not found" });
    }

    const userDoc = userQuery.docs[0];
    const userData = userDoc.data();

    return res.json({
      success: true,
      icKey: userData.icNumber,
      username: userData.username,
      email: userData.email,
    });

  } catch (error) {
    console.error("Error logging in:", error);
    if(error.code === "auth/id-token-expired") {
      return res.status(401).json({ error: "Token has expired" });
    }
    return res.status(500).json({ error: "Internal server error"});
  }
});

//Verify Complaint Function
exports.verifyComplaint = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") return res.status(204).send("");

  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({ error: "Unauthorized : No token provided" });
    }

    const idToken = authHeader.split("Bearer ")[1];
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const firebaseUid = decodedToken.uid;

    const userQuery = await db.collection("users").where("firebaseUid", "==", firebaseUid).limit(1).get();
    if (userQuery.empty) {
      return res.status(404).json({ error: "User not found" });
    }

    const userDoc = userQuery.docs[0];
    const userData = userDoc.data();
    const user_ic = userData.icNumber;
    const user_email = userData.email;

    const { imageBase64, userClaimLabel, mlPrediction} = req.body;

    if (!imageBase64 || !userClaimLabel || !mlPrediction) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    const mimeMatch = imageBase64.match(/^data:(image\/\w+);base64,/);
    const mimeType = mimeMatch ? mimeMatch[1] : "image/png"; 
    const extension = mimeType.split('/')[1];

    const rawBase64 = imageBase64.split(',').pop().replace(/\s/g, ''); 
    console.log("Uploading image...");
    const buffer = Buffer.from(rawBase64, "base64");
    const filename = `complaint_images/${uuidv4()}.${extension}`;
    const file = bucket.file(filename);
    
    await file.save(buffer, { 
      contentType: mimeType,
      public: true 
    });

    const imageUrl = `https://storage.googleapis.com/${bucket.name}/${filename}`;
    
    // Gemini API Call
    const prompt = `ML predicted: ${mlPrediction}\nUser claims: ${userClaimLabel}\nAnalyze image and return JSON ONLY: {"object": "", "ml_wrong": "YES/NO", "confidence": 0, "reason": "", "category": "", "tags": []}`;

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{
            parts: [
              { text: prompt },
              // Use rawBase64 here for Gemini
              { inline_data: { mime_type: mimeType, data: rawBase64 } } 
            ]
          }]
        }),
      }
    );

    const respJson = await response.json();

    if (!respJson.candidates || !respJson.candidates[0]) {
      console.error("Gemini Failure:", respJson);
      throw new Error("Gemini API failed to return content");
    }

    const rawText = respJson.candidates[0].content.parts[0].text;
    const jsonMatch = rawText.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error("No JSON found in AI response");
    
    const ai = JSON.parse(jsonMatch[0]);

    const verdict = ai.ml_wrong === "YES" ? "ML_WRONG" : "CORRECT";
    const lowConfidence = ai.confidence < 60;

    const statsRef = db.collection("system_stats").doc("global");
    await db.runTransaction(async (t) => {
      const statsDoc = await t.get(statsRef);
      const data = statsDoc.exists ? statsDoc.data() : { total_checked: 0, total_wrong: 0 };
      
      const newTotal = data.total_checked + 1;
      const newWrong = verdict === "ML_WRONG" ? data.total_wrong + 1 : data.total_wrong;
      
      t.set(statsRef, {
        total_checked: newTotal,
        total_wrong: newWrong,
        accuracy: Math.round(((newTotal - newWrong) / newTotal) * 10000) / 100,
        last_updated: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    if (verdict === "ML_WRONG") {
      await db.collection("complaints").add({
        user_ic: user_ic,
        user_email: user_email,
        firebaseUid: firebaseUid,
        image_url: imageUrl,
        user_claim_label: userClaimLabel,
        ml_prediction: mlPrediction,
        gemini_object: ai.object,
        confidence_score: ai.confidence,
        low_confidence_flag: lowConfidence,
        category: ai.category,
        auto_tags: ai.tags,
        ai_reason: ai.reason,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return res.json({
      save: verdict === "ML_WRONG",
      verdict : verdict,
      confidence: ai.confidence,
      ai_thought: `I think this is a ${ai.object}. ${ai.reason}`,
      accuracy_info: "Stats updated",
      message: verdict === "ML_WRONG" ? "Complaint successfully recorded." : "The ML prediction appears to be correct.",
      image_url: imageUrl,
    });

  } catch (err) {
    console.error("❌ Final Catch:", err.message);
    return res.status(500).json({ error: err.message });
  }
});
