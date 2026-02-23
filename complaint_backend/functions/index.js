const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");
const { v4: uuidv4 } = require("uuid");
const { user } = require("firebase-functions/v1/auth");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore } = require("firebase-admin/firestore");
const { initializeApp } = require("firebase-admin/app");
require("dotenv").config();

admin.initializeApp({
  storageBucket: "kitahack2026-3d5f3.firebasestorage.app"
});

const db = admin.firestore();
const bucket = admin.storage().bucket();
const GEMINI_KEY = process.env.GEMINI_API_KEY;

const handleCors = (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return true;
  }
  return false;
};

//sign up function
exports.signUp = functions.https.onRequest(async (req, res) => {
  if (handleCors(req, res)) return;

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
      username: username,
      email: email,
      icNumber: icNumber,
      firebaseUid: userRecord.uid,
      points: 0,
      weeklyPoints: 0,
      totalAccumulatedPoints: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.json({
      success: true,
      icKey: icNumber,
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
  if (handleCors(req, res)) return;

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
    if (error.code === "auth/id-token-expired") {
      return res.status(401).json({ error: "Token has expired" });
    }
    return res.status(500).json({ error: "Internal server error" });
  }
});

//record scan result function
exports.recordScan = functions.https.onRequest(async (req, res) => {
  if (handleCors(req, res)) return;

  try {
    const { icNumber, category, confidence, isComplaint } = req.body;
    if (!icNumber || !category || confidence === undefined) {
      return res.status(400).json({ error: "Missing fields" });
    }

    const today = new Date().toISOString().split('T')[0];
    const dailyStatId = `${icNumber}_${today}`;

    const batch = db.batch();

    // 1. Record the scan
    const scanRef = db.collection("scans").doc();
    batch.set(scanRef, {
      user_ic: icNumber,
      category,
      confidence,
      isComplaint: !!isComplaint,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    // 2. Update daily aggregator (ONLY if NOT a complaint)
    if (!isComplaint) {
      const dailyRef = db.collection("daily_stats").doc(dailyStatId);
      batch.set(dailyRef, {
        user_ic: icNumber,
        date: today,
        sumConfidence: admin.firestore.FieldValue.increment(confidence),
        count: admin.firestore.FieldValue.increment(1),
        rewardProcessed: false
      }, { merge: true });
    }

    await batch.commit();

    return res.json({ success: true, message: "Scan saved successfully" });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

//daily reward processing function
exports.dailyRewardCron = onSchedule("59 23 * * *", async (event) => {
  const today = new Date().toISOString().split('T')[0];
  const snapshot = await db.collection("daily_stats")
    .where("date", "==", today)
    .where("rewardProcessed", "==", false)
    .get();

  const batch = db.batch();

  snapshot.forEach(doc => {
    const data = doc.data();
    const average = data.sumConfidence / data.count;

    if (average >= 80) {
      const userRef = db.collection("users").doc(data.user_ic);
      batch.update(userRef, {
        points: admin.firestore.FieldValue.increment(1),
        weeklyPoints: admin.firestore.FieldValue.increment(1),
        totalAccumulatedPoints: admin.firestore.FieldValue.increment(1)
      });
    }
    batch.update(doc.ref, { rewardProcessed: true });
  });

  return batch.commit();
});

//leaderboard function
exports.getLeaderboard = functions.https.onRequest(async (req, res) => {
  if (handleCors(req, res)) return;

  try {
    const { icNumber, type } = req.query;

    // 1. Determine the correct field based on 'type'
    // Default to weekly if not specified for safety
    const field = type === 'total' ? 'totalAccumulatedPoints' : 'weeklyPoints';

    // 2. Get Top 5 (Parallelize this with the user fetch for speed)
    const top5Promise = db.collection("users")
      .orderBy(field, "desc")
      .limit(5)
      .get();

    const userDocPromise = db.collection("users").doc(icNumber).get();

    // Run both initial fetches simultaneously
    const [top5Snapshot, userDoc] = await Promise.all([top5Promise, userDocPromise]);

    if (!userDoc.exists) {
      return res.status(404).json({ error: "User not found" });
    }

    const userData = userDoc.data();
    const userPoints = userData[field] || 0;

    // 3. Get User Rank 
    // We count how many people have MORE points than the current user
    const rankSnapshot = await db.collection("users")
      .where(field, ">", userPoints)
      .count()
      .get();

    const top5 = top5Snapshot.docs.map(doc => ({
      username: doc.data().username,
      points: doc.data()[field] || 0
    }));

    return res.json({
      leaderboardType: type === 'total' ? 'Total Accumulated' : 'Weekly',
      top5,
      myRank: rankSnapshot.data().count + 1,
      myPoints: userPoints
    });

  } catch (error) {
    console.error("Leaderboard Error:", error);
    return res.status(500).json({ error: "Internal Server Error" });
  }
});

//voucher redemption function
exports.redeemVoucher = functions.https.onRequest(async (req, res) => {
  if (handleCors(req, res)) return;

  try {
    const { icNumber } = req.body;
    if (!icNumber) return res.status(400).json({ error: "IC Number is required" });

    const userRef = db.collection("users").doc(icNumber);
    const userDoc = await userRef.get();

    // 1. Safety Check: Does the user even exist?
    if (!userDoc.exists) {
      return res.status(404).json({ error: "User record not found in database." });
    }

    // 2. Extract points safely (default to 0 if the field is missing)
    const userData = userDoc.data();
    const currentPoints = userData.points || 0;

    // 3. Strict Logic Check
    if (currentPoints < 14) {
      return res.status(400).json({
        success: false,
        error: "Insufficient points",
        currentPoints: currentPoints,
        needed: 14
      });
    }

    // 4. Update the database
    await userRef.update({
      points: 0,
      totalVouchersClaimed: admin.firestore.FieldValue.increment(1)
    });

    return res.json({
      success: true,
      message: "Voucher redeemed successfully!"
    });

  } catch (error) {
    console.error("Redeem Error:", error);
    return res.status(500).json({ error: error.message });
  }
});

//reset weekly leaderboard every sunday at midnight
exports.resetWeeklyLeaderboard = onSchedule("0 0 * * 0", async (event) => {
  const users = await db.collection("users").get();
  const batch = db.batch();
  users.forEach(user => {
    batch.update(user.ref, { weeklyPoints: 0 });
  });
  return batch.commit();
});

//get all scans for a user
exports.getScans = functions.https.onRequest(async (req, res) => {
  if (handleCors(req, res)) return;

  try {
    const { icNumber } = req.query;
    if (!icNumber) return res.status(400).json({ error: "IC Number is required" });

    const snapshot = await db.collection("scans")
      .where("user_ic", "==", icNumber)
      .orderBy("timestamp", "desc")
      .get();

    const scans = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      scans.push({
        id: doc.id,
        category: data.category,
        confidence: data.confidence,
        isComplaint: !!data.isComplaint,
        timestamp: data.timestamp ? data.timestamp.toDate().toISOString() : null
      });
    });

    return res.json({ scans });
  } catch (error) {
    console.error("Get Scans Error:", error);
    return res.status(500).json({ error: error.message });
  }
});

//get user profile data
exports.getUserProfile = functions.https.onRequest(async (req, res) => {
  if (handleCors(req, res)) return;

  try {
    const { icNumber } = req.query;
    if (!icNumber) return res.status(400).json({ error: "IC Number is required" });

    const userDoc = await db.collection("users").doc(icNumber).get();
    if (!userDoc.exists) {
      return res.status(404).json({ error: "User not found" });
    }

    const userData = userDoc.data();
    return res.json({
      success: true,
      username: userData.username,
      email: userData.email,
      icNumber: userData.icNumber,
      points: userData.points || 0,
      weeklyPoints: userData.weeklyPoints || 0,
      totalAccumulatedPoints: userData.totalAccumulatedPoints || 0
    });
  } catch (error) {
    console.error("Get User Profile Error:", error);
    return res.status(500).json({ error: error.message });
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

    const { imageBase64, userClaimLabel, mlPrediction } = req.body;

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
      verdict: verdict,
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

// TEMPORARY: Use this to test rewards manually
exports.manualRewardTest = functions.https.onRequest(async (req, res) => {
  const today = new Date().toISOString().split('T')[0];
  const snapshot = await db.collection("daily_stats")
    .where("date", "==", today)
    .where("rewardProcessed", "==", false)
    .get();

  if (snapshot.empty) {
    return res.json({ message: "No pending rewards found for today." });
  }

  const batch = db.batch();
  let rewardedCount = 0;

  snapshot.forEach(doc => {
    const data = doc.data();
    const average = data.sumConfidence / data.count;

    if (average >= 80) {
      const userRef = db.collection("users").doc(data.user_ic);
      batch.update(userRef, {
        points: admin.firestore.FieldValue.increment(1),
        weeklyPoints: admin.firestore.FieldValue.increment(1),
        totalAccumulatedPoints: admin.firestore.FieldValue.increment(1)
      });
      rewardedCount++;
    }
    batch.update(doc.ref, { rewardProcessed: true });
  });

  await batch.commit();
  return res.json({
    success: true,
    message: `Processed ${snapshot.size} users. ${rewardedCount} users hit the 80% mark and got points!`
  });
});
