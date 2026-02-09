const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");
const { v4: uuidv4 } = require("uuid");
require("dotenv").config();

admin.initializeApp({
  storageBucket: "kitahack2026-3d5f3.firebasestorage.app"
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

// UPDATED: Matches the name in your screenshot
const GEMINI_KEY = process.env.GEMINI_API_KEY;

exports.verifyComplaint = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") return res.status(204).send("");

  try {
    const { imageBase64, userClaimLabel, mlPrediction, userId } = req.body;

    if (!imageBase64 || !userClaimLabel || !mlPrediction || !userId) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    // NEW FIX: Strip 'data:image/...;base64,' prefix before processing
    // Gemini only accepts raw base64 bytes
    const rawBase64 = imageBase64.split(',').pop(); 

    console.log("Uploading image...");
    const buffer = Buffer.from(rawBase64, "base64");
    const filename = `complaint_images/${uuidv4()}.png`;
    const file = bucket.file(filename);
    
    await file.save(buffer, { 
      contentType: "image/png",
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
              { inline_data: { mime_type: "image/png", data: rawBase64 } } 
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
        user_id: userId,
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
      verdict,
      confidence: ai.confidence,
      accuracy_info: "Stats updated",
      message: verdict === "ML_WRONG" ? "Complaint recorded." : "Prediction verified.",
      image_url: imageUrl,
    });

  } catch (err) {
    console.error("❌ Final Catch:", err.message);
    return res.status(500).json({ error: err.message });
  }
});
