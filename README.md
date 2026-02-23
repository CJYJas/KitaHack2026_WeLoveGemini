# 🌍 WeLoveGemini: AI-Powered Waste Verification & Rewards

## 1. Repository Overview & Team Introduction
Welcome to the official repository for **WeLoveGemini**. Our project is an AI-driven ecosystem designed to gamify recycling and bridge the "Action Gap" in Malaysia's waste management through intelligent verification.

**Team Members:**
* **Jasmine Chin Jia Yee** 
* **Zoey Wong Zi Xin** 
* **Josephine Ding Jie Yu** 

---

## 2. Project Overview

### **Problem Statement**
Despite national campaigns, Malaysia struggles with a **37.9% recycling rate**, far below the 40% target. The "Confusion Gap" (not knowing what is recyclable) and the "Trust Gap" (lack of incentive verification) lead to high contamination. Currently, **RM291 million** is lost annually because high-value recyclables end up in landfills due to poor source separation.

### **SDG Alignment**
* **SDG 3 (Good Health & Well-being):** By incentivizing proper waste disposal, the system reduces the accumulation of haphazardly thrown plastic and tires. These items often collect stagnant water, serving as primary breeding grounds for **Aedes mosquitoes**, thereby helping to lower the incidence of **Dengue and Zika** in urban communities.
* **SDG 11 (Sustainable Cities):** Reducing the burden on municipal waste infrastructure.
* **SDG 12 (Responsible Consumption):** Automating waste classification to reduce contamination.
* **SDG 13 (Climate Action):** Diverting organic waste to reduce methane emissions from landfills.
* **SDG 17 (Partnerships):** Creating an ESG-funded reward loop between vendors and citizens.


### **Solution Description**
Our solution is a mobile application that uses **Computer Vision (TensorFlow)** to identify waste and **Generative AI (Gemini)** to handle disputes.

---

## 3. Key Features

#### 1. Instant AI Classification (Snap-to-Classify)
Unlike apps requiring manual searches, this solution uses real-time Computer Vision. A simple photo instantly identifies material types, eliminating the "Confusion Gap" and making recycling accessible to all age groups.

#### 2. AI “Proof-of-Separation” & Purity Scoring
While other platforms rely on trust, this system introduces **Visual Verification**:
* **Submission:** Users photograph their sorted waste bags.
* **Analysis:** AI assigns a **Purity Score** .
* **Validation:** Rewards are only granted for verified, clean recycling, ensuring data integrity for sponsors.

#### 3. Multi-Stakeholder Reward Loop
The platform connects residents, businesses, and sustainability goals:
* **Residents:** Earn high-value vouchers (Grab, Shopee) by maintaining 14-day streaks.
* **Vendors:** Provide rewards in exchange for **ESG Credits** and visibility, creating a self-funding ecosystem independent of government grants.
* **Environment:** Verified separation reduces landfill methane and resource loss (**SDG 12 & 13**).

---

## 4. Overview of Technologies Used (to be completed)

### **Google Technologies**
* **Flutter:** Cross-platform mobile UI with smooth 60FPS animations.
* **Firebase (Firestore & Storage):** Real-time data syncing for points and elastic hosting for "Proof-of-Separation" images.
* **Google Cloud Functions & Cloud Run:** Serverless backend logic using firebase-functions (v7.0.0).
* **Teachable Machine (TensorFlow):** High-speed material classification model.
* **Gemini API:** Multimodal reasoning for the automated complaint verification system.

### Backend Runtime & Dependencies
* **Node.js 20: The official LTS runtime for the cloud functions.
* **Firebase Admin SDK (v13.6.0): Used for server-side Firestore and Batch operations.
* **Dotenv: Managing environment variables and API keys securely.

---

## 5. Implementation Details & Innovation

### **System Architecture**
The architecture is **serverless and event-driven**. When a user uploads a photo to Cloud Storage, it triggers a Cloud Function that invokes the Vertex AI/Gemini endpoint for classification. Results are stored in Firestore, where a real-time listener updates the Flutter UI instantly.

### **Workflow**
1.  **Identity Handshake:** Upon **Login**, the backend retrieves the user's `icNumber`. The Flutter app persists this locally to automate all subsequent verification and leaderboard requests.
2.  **AI Waste Consultant (Pre-Scan):** To eliminate the "Confusion Gap," users can ask the in-app AI assistant what category a specific item belongs to. This uses the **Gemini API** to provide instant, conversational guidance on proper disposal before the user performs a formal "Purity Scan."
3.  **Snapshot Classification:** Users capture waste images via the **Flutter** interface. The integrated **Teachable Machine** model returns a material category and confidence score.
4.  **Real-Time Aggregation (`recordScan`):** Every scan adds the confidence value to a `sumConfidence` bucket and increments a `count` in the `daily_stats` collection.
5.  **The "80% Purity" Reward (`dailyRewardCron`):** A scheduled Cloud Function runs at midnight to calculate the **Daily Mean** ($\frac{sumConfidence}{count}$).
    * **Reward:** If the mean exceeds **80%**, the user earns **1 point** toward their 14-day streak.
6.  **Complaint & Dispute Verification:** Users can submit a **Complaint** if they believe the AI misclassified their waste.
    * **Gemini Auditor:** The **Gemini API** analyzes the disputed image against the initial classification to identify "False Negatives."
    * **Manual Override:** Validated complaints trigger an automatic score correction and update the user's points in Firestore.
7.  **Gamified Redemption (`redeemVoucher`):** Upon reaching **14 points**, users can claim rewards (e.g., Grab/Shopee vouchers).
    * **Reset Logic:** The spendable `points` balance resets to **0**, while `totalAccumulatedPoints` and `weeklyPoints` are preserved for global **Leaderboard** standing.

---

## 6. Challenges Faced
*(To be completed - Example: Dealing with API versioning (v1beta) and environment variable configurations for the Gemini API.)*

---

## 7. Installation & Setup

### Prerequisites
Before you begin, ensure you have the following installed on your system:

1. **Flutter SDK**: [Install Flutter](https://flutter.dev/docs/get-started/install) and ensure it is added to your system PATH.
2. **Dart SDK**: Comes bundled with Flutter.
3. **Android Studio** (for Android development):
   - Install Android Studio from [here](https://developer.android.com/studio).
   - Ensure you have the latest Android SDK and Android Virtual Device (AVD) installed.
4. **Xcode** (for iOS development, macOS only):
   - Install Xcode from the Mac App Store.
   - Ensure you have the latest iOS SDK installed.
5. **Node.js and npm**: Install from [Node.js official website](https://nodejs.org/).
6. **Firebase CLI**: Install Firebase CLI by running:
   ```bash
   npm install -g firebase-tools
   ```
7. **Git**: Install Git from [Git official website](https://git-scm.com/).

### Clone the Repository
Clone the repository to your local machine using the following command:
```bash
git clone https://github.com/CJYJas/KitaHack2026_WeLoveGemini.git
```

### Backend Setup
1. Navigate to the backend folder:
   ```bash
   cd complaint_backend/functions
   ```
2. Install the required Node.js dependencies:
   ```bash
   npm install
   ```
3. Deploy the Firebase functions:
   ```bash
   firebase deploy --only functions
   ```

### Frontend Setup
1. Navigate to the frontend folder:
   ```bash
   cd waste_sorting_app
   ```
2. Install the required Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app on your desired platform:
   - For Android:
     ```bash
     flutter run -d <device_id>
     ```
   - For iOS (macOS only):
     ```bash
     flutter run -d ios
     ```
   - For Web:
     ```bash
     flutter run -d chrome
     ```

### Additional Notes
- Ensure your Android device has **USB debugging** enabled if deploying to a physical device.
- For iOS deployment, ensure you have a valid Apple Developer account and the necessary provisioning profiles.
- If you encounter any issues, refer to the [Flutter documentation](https://flutter.dev/docs) or the [Firebase documentation](https://firebase.google.com/docs).

---

## 8. Future Roadmap

### **Phase 1: Smart University Integration (B2U)**
Partner with university (e.g., **University Malaya**) to integrate AI "Purity Scoring" data with official waste collection schedules to identify "Green Zones" and optimize truck routes.

### **Phase 2: "Smart Bin" Hardware Licensing**
Transition AI models into physical hardware. License image recognition models to manufacturers of "Smart Bins" for high-traffic areas like malls and transit hubs for instant scanning and rewards.

### **Phase 3: Hyper-Local Vendor Networks**
Scale the reward ecosystem to include "Micro-Vendors" (e.g., *pasar malam* sellers and neighborhood cafes) to offer "Green Discounts," driving local economic growth while reducing plastic waste.
