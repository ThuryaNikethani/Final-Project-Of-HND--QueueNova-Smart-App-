# QueueNova

**QueueNova** is a smart queue management mobile application built for government service centers. It replaces long physical queues with digital appointment booking, live queue tracking, and QR-based check-in — helping citizens save time and helping offices manage foot traffic more efficiently.

## Overview

Citizens can browse available government services, book appointments in advance, track their position in the queue in real time, and check in on arrival using a QR code — all from their phone. Office staff get live visibility into queue status and load, backed by a real-time backend.

## Key Features

- **Service Booking** — Browse government services and book appointments with available time slots
- **Live Queue Tracking** — Real-time queue status and position updates powered by Socket.IO
- **QR Check-In** — Quick, contactless check-in at the service counter via QR code scanning
- **Emergency Queue** — Priority queue handling for urgent cases
- **Document Vault** — Securely upload, store, and manage documents required for appointments
- **Request Tracking** — Track the status of submitted service requests end to end
- **Service History** — View a complete history of past visits and completed services
- **Wait-Time Prediction** — Estimated wait times to help citizens plan their visit
- **In-App Payments** — Secure service fee payments via Stripe
- **Notifications** — Timely updates on queue position, appointment status, and requests
- **Feedback** — Rate and review completed services
- **Multi-Language Support** — Available in English, Sinhala, and Tamil
- **Secure Authentication** — Firebase-powered sign-up, login, and account management

## Tech Stack

**Mobile App**
- [Flutter](https://flutter.dev/) (Dart) — cross-platform UI for Android, iOS, web, and desktop
- Provider — state management
- Firebase Authentication & Cloud Firestore
- Stripe — payment processing
- Socket.IO client — real-time queue updates
- Easy Localization — multi-language support

**Backend**
- Node.js with Express
- Socket.IO — real-time communication
- PostgreSQL / MySQL — data persistence
- Stripe API — payment processing
- JWT-based authentication with bcrypt

## Project Structure

```
queuenova_mobile/
├── lib/
│   ├── config/          # App-wide configuration
│   ├── models/          # Data models
│   ├── providers/       # State management (Provider)
│   ├── screens/         # UI screens
│   ├── services/        # API and business logic services
│   ├── utils/           # Helper utilities
│   ├── widgets/         # Reusable UI components
│   └── web/
│       └── backend_server/   # Node.js/Express backend server
├── assets/
│   ├── images/
│   ├── icons/
│   ├── animations/
│   └── translations/    # en / si / ta locale files
└── test/                # Unit and widget tests
```

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.0.0)
- [Node.js](https://nodejs.org/) (for the backend server)
- PostgreSQL or MySQL database
- A Firebase project (Authentication + Firestore enabled)
- A Stripe account (for payment processing)

### Mobile App Setup

1. Install dependencies:
   ```bash
   flutter pub get
   ```
2. Add your Firebase configuration files (`google-services.json` for Android, `GoogleService-Info.plist` for iOS) to the appropriate platform folders.
3. Run the app:
   ```bash
   flutter run
   ```

### Backend Setup

1. Navigate to the backend server directory:
   ```bash
   cd lib/web/backend_server
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Configure environment variables in a `.env` file (database credentials, Stripe keys, etc.).
4. Set up the database schema:
   ```bash
   # Run schema.sql against your PostgreSQL/MySQL instance
   ```
5. Start the server:
   ```bash
   npm start
   ```
   For development with auto-reload:
   ```bash
   npm run dev
   ```

## Building for Release

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## License

This project is developed as part of a Higher Diploma final project at NIBM City University.
