# 🧠 Studious

A completely custom, cross-platform Spaced Repetition engine built with Flutter. Studious uses Google Sheets as a headless database and Google Drive for cloud asset storage, allowing for a completely decentralized, personal study ecosystem.

Currently compiled for **Android** and **Windows Desktop**.

## ✨ Features

* **Algorithmic Spaced Repetition:** Custom mathematical engine that calculates review intervals ($Gap = 2^{(stage - 1)}$ days) to optimize memory retention.
* **Google Cloud Integration:** * **Sheets API:** Acts as the structured database for instant remote mutations.
    * **Drive API:** Handles direct binary file streaming for reference attachments (PDFs, Images).
* **Study Health Gamification:** An interactive dashboard with a daily health bar and a custom native Android Home Screen Widget to track daily review completion.
* **Context-Aware Capture Zone:** "Auto-Folder" logic that binds new entries directly to the active academic semester (e.g., S5, S6) saved securely in device memory.
* **Exam Cram Mode:** An algorithmic escape hatch to bypass spaced intervals and grind specific modules on demand before a test.
* **Cross-Platform Sync:** Start reviewing on a Windows PC and finish on an Android phone seamlessly or vice versa.

---

## 🛠️ Tech Stack

* **Frontend:** Flutter & Dart
* **Backend/Database:** Google Sheets API v4
* **Asset Storage:** Google Drive API v3
* **Local Storage:** `shared_preferences` (App State), `home_widget` (Native Android Widget)
* **Authentication:** GCP Service Accounts & OAuth

---
