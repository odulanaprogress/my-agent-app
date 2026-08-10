# agent_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.



# AGENT PLATFORM (Flutter & Firebase)

A modern, high-performance Flutter mobile application for property rental, landlord-tenant operations, and secure Flutterwave Escrow payments.

---

## 📌 Features & System Overview

- **Flutterwave Live Escrow System**: Dedicated live NUBAN virtual accounts generated via Flutterwave API (`https://api.flutterwave.com/v3/virtual-account-numbers`) and resolved instantly via NIBSS across all Nigerian banking apps.
- **Dual PIN Handshake Settlement**: 6-digit Key Handover PIN system protecting both tenant and landlord during physical property delivery.
- **Automated Payout & Commission**: 95% rent payout to Landlord wallet/bank, 5% platform protection fee retained by AGENT LIMITED.
- **Identity & Verification**: Access control service restricting escrow transactions to verified accounts.
- **Real-Time Dashboards**: Separate tenant and landlord dashboards with analytics, saved properties, and transaction receipts.

---

## 🚀 Tech Stack & Integration

- **Framework**: Flutter (Dart) & Riverpod State Management
- **Database & Auth**: Firebase Firestore & Firebase Auth
- **Payment Gateway**: Flutterwave API v3 (Live & Test NUBAN Virtual Accounts) & Paystack
- **Media & Push Notifications**: Cloudinary & OneSignal

---

## 📁 Architecture & File Structure

```
lib/
 ├── core/
 │    ├── network/ (ApiClient)
 │    ├── services/ (EscrowApiService, FirebaseAuthService)
 ├── features/
 │    ├── payments/
 │    │    ├── data/ (PaymentRepository, TransactionModel)
 │    │    ├── domain/ (EscrowStatus, TransactionType)
 │    │    ├── presentation/ (PaymentScreen, EscrowDetailsScreen, PaymentReceiptDialog)
 │    │    └── providers/ (PaymentController, PaymentState)
 │    ├── properties/
 │    ├── verification/
 │    └── dashboard/
 └── main.dart
```

---

## 🔑 Environment Variables (`.env`)

```env
FLUTTERWAVE_PUBLIC_KEY=FLWPUBK-e4f3f2c0b31f1ce707262f74d5af9d78-X
FLUTTERWAVE_SECRET_KEY=FLWSECK-cf4c9e59021f2fcae57bd9398a17574d-19fdeda81acvt-X
FLUTTERWAVE_ENCRYPTION_KEY=cf4c9e59021fa8e749b8f82c
```

---

## 📄 Documentation

For full developer docs, prompt reference, and payment gateway technical specifications, see:
- [Developer Payment Gateway Guide](file:///c:/agent_app/docs/PAYMENT_GATEWAY_DOCS.md)
- [Implementation Checklist](file:///c:/agent_app/IMPLEMENTATION_CHECKLIST.md)