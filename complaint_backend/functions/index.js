const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");
const { v4: uuidv4 } = require("uuid");
require("dotenv").config();

admin.initializeApp();

const db = admin.firestore();
const bucket = admin.storage().bucket();
const GEMINI_KEY = process.env.GEMINI_KEY;

// HTTPS Request Function (works with Dart HTTP POST or Flutter)
exports.verifyComplaint = functions.https.onRequest(async (req, res) => {
  // CORS headers to allow requests from anywhere (for testing/hackathon)
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }

  try {
    const { imageBase64, userClaimLabel, mlPrediction, userId } = req.body;

    if (!imageBase64 || !userClaimLabel || !mlPrediction || !userId) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    // Upload image to Firebase Storage
    const buffer = Buffer.from(imageBase64, "base64");
    const filename = `complaint_images/${uuidv4()}.jpg`;
    const file = bucket.file(filename);
    await file.save(buffer, { contentType: "image/jpeg" });

    const [imageUrl] = await file.getSignedUrl({
      action: "read",
      expires: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
    });

    // Gemini Prompt
    const prompt = `
ML predicted: ${mlPrediction}
User claims: ${userClaimLabel}

Analyze the image and return JSON ONLY:
{
 "object": "",
 "ml_wrong": "YES/NO",
 "confidence": 0,
 "reason": "",
 "category": "",
 "tags": []
}
`;

    // Call Gemini API
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=${GEMINI_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                { text: prompt },
                { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }
              ]
            }
          ]
        }),
      }
    );

    const respJson = await response.json();
    const aiText = respJson.candidates[0].content.parts[0].text
      .replace("```json", "")
      .replace("```", "")
      .trim();

    const ai = JSON.parse(aiText);

    const verdict = ai.ml_wrong === "YES" ? "ML_WRONG" : "CORRECT";
    const lowConfidence = ai.confidence < 60;

    // Update system analytics
    const statsRef = db.collection("system_stats").doc("global");
    const statsDoc = await statsRef.get();
    let totalChecked = statsDoc.exists ? statsDoc.data().total_checked : 0;
    let totalWrong = statsDoc.exists ? statsDoc.data().total_wrong : 0;

    totalChecked++;
    if (verdict === "ML_WRONG") totalWrong++;
    const accuracy = ((totalChecked - totalWrong) / totalChecked) * 100;

    await statsRef.set({
      total_checked: totalChecked,
      total_wrong: totalWrong,
      accuracy: Math.round(accuracy * 100) / 100,
      last_updated: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Save complaint only if ML is wrong
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

    // Respond to user
    let userMessage = "";
    if (verdict === "ML_WRONG") {
      userMessage = "Sorry, the model made a mistake. Your complaint has been recorded.";
    } else {
      userMessage = "Prediction seems correct based on our AI check. No complaint saved.";
    }

    return res.json({
      save: verdict === "ML_WRONG",
      verdict,
      confidence: ai.confidence,
      low_confidence: lowConfidence,
      accuracy,
      message: userMessage,
      image_url: imageUrl,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Server error" });
  }
});

