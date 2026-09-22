# 🚗 MechX — On-Demand Mechanic Marketplace

MechX is a professional, high-performance Flutter application that connects stranded drivers with expert mechanics in real-time. Built with a focus on speed, reliability, and security, it leverages **Supabase** for its backend and **Riverpod** for state management to provide a seamless marketplace experience.

## ✨ Key Features

### 🧑 For Customers
* **Emergency Booking Flow:** 5-step intuitive process: Select Vehicle ➔ Select Service ➔ Describe Issue ➔ Set Location ➔ Receive Bids.
* **Real-Time Bidding:** Receive instant price offers from multiple nearby mechanics.
* **Live GPS Tracking:** Watch your mechanic arrive on a live map with animated routes.
* **Secure Payments:** Multiple payment methods including Cash, Card, and local Mobile Wallets.
* **Service History:** Keep track of past bookings, costs, and reviews.

### 🔧 For Mechanics
* **Live Request Feed:** Real-time stream of incoming service requests in your vicinity.
* **Bid Management:** Send competitive price offers and estimated arrival times.
* **Seamless Navigation:** In-app GPS tracking of customer location to ensure fast arrival.
* **Performance Analytics:** Persistent dashboard showing total earnings, completed jobs, and live star ratings.
* **Integrated Communication:** Direct calling and real-time chat with customers during active jobs.

## 🛠️ Tech Stack & Architecture
* **Frontend:** Flutter (Dart)
* **State Management:** Riverpod 2.x (using Generators and AsyncNotifiers)
* **Backend & Auth:** Supabase (PostgreSQL, Realtime, Storage, and Edge Functions)
* **Maps:** Google Maps SDK with high-accuracy GPS tracking
* **Security:** Row-Level Security (RLS) policies enforcing role isolation and data privacy.

## 📂 Project Structure
```
lib/
  cores/
    models/       → Strongly-typed data schemas (User, Booking, Offer, etc.)
    providers/    → Riverpod state logic & Real-time Supabase streams
    repositories/ → Clean data access layers for Auth, Bookings, and Location
    theme/        → Semantic Teal & Amber design system (Dark/Light mode)
  widgets/        → Reusable UI components (Custom Buttons, Atomic Cards, Gauges)
  screens/        → Feature-specific portals for Customers and Mechanics
```

## 🚀 Getting Started

### 1. Requirements
* Flutter SDK (`^3.12.2` or later)
* A Supabase Project with the schema in `supabase_schema.sql` applied.
* A valid Google Maps API Key.

### 2. Configuration
Create a `.env` file in the root directory:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
GOOGLE_WEB_CLIENT_ID=your-google-client-id
```

### 3. Installation
```bash
flutter pub get
flutter run
```

---
*Note: Real-time features require enabling Replication on the `bookings`, `offers`, `chat_messages`, and `booking_locations` tables within your Supabase dashboard.*
