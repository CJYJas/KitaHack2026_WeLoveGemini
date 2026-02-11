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

#### 3. Emotional Gamification: The Polar Bear Habitat
To drive retention, users nurture a digital polar bear environment:
* **High Scores:** The ice cap grows and thrives.
* **Low Activity:** The ice melts, providing a visual cue of environmental impact.
This pairs **Intrinsic Motivation** (emotional connection) with **Extrinsic Rewards**, making sustainable habits engaging.

#### 4. Multi-Stakeholder Reward Loop
The platform connects residents, businesses, and sustainability goals:
* **Residents:** Earn high-value vouchers (Grab, Shopee) by maintaining 14-day streaks.
* **Vendors:** Provide rewards in exchange for **ESG Credits** and visibility, creating a self-funding ecosystem independent of government grants.
* **Environment:** Verified separation reduces landfill methane and resource loss (**SDG 12 & 13**).

---

## 4. Overview of Technologies Used

### **Google Technologies**
* **Flutter:** Cross-platform mobile UI with smooth 60FPS animations.
* **Firebase (Firestore & Storage):** Real-time data syncing for points and elastic hosting for "Proof-of-Separation" images.
* **Google Cloud Functions & Cloud Run:** Serverless backend handling daily mean calculations and reward logic.
* **Teachable Machine (TensorFlow):** High-speed material classification model.
* **Gemini API:** Multimodal reasoning for the automated complaint verification system.

### **Other Supporting Tools**
* **Node.js 24:** Backend runtime for cloud functions.
* **Python:** Used for initial model training and data preprocessing.
* **GitHub:** Version control and CI/CD.

---

## 5. Implementation Details & Innovation

### **System Architecture**
The architecture is **serverless and event-driven**. When a user uploads a photo to Cloud Storage, it triggers a Cloud Function that invokes the Vertex AI/Gemini endpoint for classification. Results are stored in Firestore, where a real-time listener updates the Flutter UI instantly.

### **Workflow**
1. **Input:** User captures waste image via **Flutter**.
2. **Analysis:** **Teachable Machine (TensorFlow)** model returns a purity percentage.
3. **Aggregation:** The `submitTrashScore` Cloud Function saves scores and calculates the **Daily Mean**.
4. **Reward Logic:** If the mean exceeds **90%**, 1 mark is awarded. Upon reaching **14 marks**, a reward is triggered and counters are reset.
5. **Audit:** Disputes are routed to the **Gemini API** for context-aware reasoning to determine if the ML was incorrect.

---

## 6. Challenges Faced
*(To be completed - Example: Dealing with API versioning (v1beta) and environment variable configurations for the Gemini API.)*

---

## 7. Installation & Setup
*(To be completed - Example: Flutter pub get, Firebase CLI login, etc.)*

---

## 8. Future Roadmap

### **Phase 1: Smart City Integration (B2G)**
Partner with local municipal councils (e.g., **DBKL, MBPJ**) to integrate AI "Purity Scoring" data with official waste collection schedules to identify "Green Zones" and optimize truck routes.

### **Phase 2: "Smart Bin" Hardware Licensing**
Transition AI models into physical hardware. License image recognition models to manufacturers of "Smart Bins" for high-traffic areas like malls and transit hubs for instant scanning and rewards.

### **Phase 3: Hyper-Local Vendor Networks**
Scale the reward ecosystem to include "Micro-Vendors" (e.g., *pasar malam* sellers and neighborhood cafes) to offer "Green Discounts," driving local economic growth while reducing plastic waste.
