# LabSlot – Campus Computer Laboratory & PC Station Booking System

**LabSlot** replaces blind campus lab walk-ins and paper clipboard logbooks with a real-time, cloud-synced laboratory room and PC station reservation platform built with **Flutter**, **Riverpod**, and **Supabase**.

---

## Core Modules & System Capabilities (3 RBAC Actors)

### 1. Student Module (`student`)
- **Live Room & Visual PC Station Seat Map:** View real-time room badges (`Open Lab`, `Class in Session`, `Closed`) and interactive color-coded PC station grids (`Available`, `Occupied/Reserved`, `Defective/Maintenance`).
- **Coursework & Hardware Spec Filter:** Filter stations by installed tools (`Flutter / Android Studio`, `VS Code`, `AutoCAD`, `Cisco Packet Tracer`, `Premiere Pro / Blender`) and hardware specs before booking.
- **Time-Slot Reservation & QR Booking Pass:** Reserve a 1-to-2-hour slot with a unique QR token (`LS-XXXX-XXXX`) and live **10-minute grace period countdown** that automatically releases unclaimed "ghost" bookings.
- **One-Tap Defective PC Reporting:** Flag broken mice, keyboards, network drops, or missing IDEs to immediately quarantine the station from future reservations.
- **Direct In-App Help Desk Chat:** Message the lab custodian directly from an active PC station without leaving your seat.

### 2. Laboratory Custodian Module (`custodian`)
- **Fast Counter Check-In & Physical ID Vault Escrow:** Verify student QR tokens in one tap, record physical school ID escrow tray/bin locations (e.g., `Bin A-12`), and lock the station as `Occupied`.
- **One-Tap Check-Out & ID Return Verification:** Confirm physical ID return before releasing the station back to `Available` on the live campus map.
- **Room Status Override:** Toggle laboratory rooms between `Open Lab`, `Class in Session`, and `Closed` (automatically canceling pending walk-in reservations when a make-up class starts).
- **Maintenance Queue & Last-User Accountability Trace:** Inspect quarantined PCs, trace the exact last student who checked into that station (`Student Name`, `ID Number`, `Check-In/Out Timestamps`), and restore repaired stations.
- **Custodian Help Desk Inbox:** Respond to live student session messages and mark inquiries resolved.

### 3. System Administrator Module (`admin`)
- **Lab Room & PC Inventory Management:** Create and configure laboratory rooms, PC hardware specs, and installed software tags.
- **User Role & Fair-Use Strike Management:** Assign RBAC roles (`student`, `custodian`, `admin`) and review or reset student **3-Strike No-Show Restrictions** with mandatory audit logging.
- **Accreditation & Utilization Reports (CHED / PACUCOA):** Generate visual utilization analytics by room and academic department (`BSIT`, `BSCS`, `BSCpE`, `BMMA`) and export printable **PDF** and **CSV** reports.

---

## Tech Stack & Architecture

- **Frontend:** Flutter (Android, iOS, Web, Windows Desktop)
- **State Management:** `flutter_riverpod`
- **Backend & Database:** Supabase (PostgreSQL, Auth, Realtime WebSockets, Row-Level Security)
- **Reporting & QR:** `qr_flutter`, `fl_chart`, `pdf`, `printing`, `csv`

```text
lib/
├── core/
│   ├── config/supabase_config.dart       # Supabase initialization & env config
│   ├── models/labslot_models.dart        # Domain models & enums
│   ├── providers/labslot_controller.dart # System use-case state & RBAC controller
│   ├── theme/app_theme.dart              # Dark status-driven UI theme
│   └── widgets/labslot_shell.dart        # Multi-role navigation shell & actor switcher
├── features/
│   ├── auth/presentation/                # Login & quick RBAC actor switcher
│   ├── student/presentation/             # Live grid, QR pass, defect report, help chat
│   ├── custodian/presentation/           # ID escrow desk, room override, maintenance trace
│   └── admin/presentation/               # Lab/PC inventory, strike management, PDF/CSV reports
└── main.dart
```

---

## Getting Started

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run Immediately (Interactive Realtime Store Mode)
You can run and test all 13 system use cases across all 3 actors right away without external configuration:
```bash
flutter run -d chrome
# or on Windows desktop / Android emulator:
flutter run -d windows
```

### 3. Connect to Live Supabase Project (Optional Production Mode)
1. Create a free project at [supabase.com](https://supabase.com).
2. Open the **SQL Editor** in your Supabase Dashboard:
   - Run [`supabase/schema.sql`](supabase/schema.sql) to create all 7 tables, RBAC Row-Level Security (RLS) policies, and the `release_expired_ghost_slots()` PostgreSQL RPC function.
   - Run [`supabase/seed.sql`](supabase/seed.sql) to populate `ComLab 1`–`ComLab 4` and PC stations.
3. Enable **Realtime** replication for `lab_rooms`, `pc_stations`, `bookings`, `maintenance_tickets`, and `chat_messages`.
4. Launch Flutter with your Supabase URL and Anon Key:
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

---

## Running Tests
```bash
flutter analyze
flutter test
```
