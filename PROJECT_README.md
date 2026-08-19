# Beauty Clinic iOS

A native iOS application for beauty clinic internal management built with SwiftUI and Supabase.

## Features

- **Multi-user Authentication** via phone number (SMS OTP)
- **Customer Management** - View/edit client profiles, medical history, preferences
- **Package Management** - Manage beauty services with training materials
- **Store Management** - Track branches, status, and locations
- **Transaction Records** - Log appointments and sales

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | SwiftUI + SwiftData (iOS 17+) |
| Backend | Supabase (PostgreSQL + Auth + Storage) |

## Getting Started

### Prerequisites

- Xcode 15+ with iOS 17+ SDK
- Supabase account ([supabase.com](https://supabase.com))

### Step 1: Create Supabase Project

1. Sign up at [Supabase](https://supabase.com)
2. Create a new project (free tier works for startup)
3. Wait for deployment (~5 minutes)

### Step 2: Initialize Database

In Supabase Dashboard → SQL Editor, run:

```sql
-- 1. Enable UUID extension
create extension if not exists "uuid-ossp";

-- 2. Create tables (see supabase/migrations/001_init_schema.sql)
-- Copy the entire schema from the file and paste here

-- 3. Set up Row Level Security
-- Copy RLS policies from supabase/migrations/001_init_schema.sql
```

### Step 3: Configure Auth

1. Go to Authentication → Providers
2. Enable Phone Provider
3. Add your SMS provider credentials (Twilio, Aliyun, etc.)

### Step 4: Xcode Setup

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/beauty-clinic-ios.git
cd beauty-clinic-ios

# Open in Xcode
open BeautyClinic.xcodeproj
```

In `App.swift`, update your Supabase credentials:

```swift
let client = SupabaseClient(
    url: "https://YOUR_PROJECT.supabase.co",
    apiKey: "YOUR_ANON_KEY"
)
```

Or use environment variables:

```bash
export SUPABASE_URL=https://YOUR_PROJECT.supabase.co
export SUPABASE_ANON_KEY=your-anon-key-here
```

## Project Structure

```
BeautyClinic/
├── App.swift                    # Main app entry point
├── Models/                      # Data models (SwiftData)
│   ├── User.swift
│   ├── Store.swift
│   ├── Customer.swift
│   ├── Package.swift
│   └── Transaction.swift
├── Views/                       # SwiftUI views
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── OTPVerificationView.swift
│   ├── HomeView.swift
│   ├── Customers/
│   │   ├── CustomerListView.swift
│   │   ├── CustomerDetailView.swift
│   │   └── CustomerEditView.swift
│   ├── Packages/
│   │   ├── PackageListView.swift
│   │   └── PackageEditView.swift
│   ├── Stores/
│   │   ├── StoreListView.swift
│   │   └── StoreEditView.swift
│   ├── Transactions/
│   │   ├── TransactionListView.swift
│   │   └── TransactionRecordView.swift
│   └── SettingsView.swift
├── Services/                    # Supabase integration
│   └── SupabaseClient.swift
└── Assets.xcassets              # App assets
```

## Database Schema

### Tables

| Table | Description |
|-------|-------------|
| `users` | Staff/user accounts with roles and store assignments |
| `stores` | Clinic branches and locations |
| `customers` | Client information for appointments/sales |
| `packages` | Beauty service packages with training materials |
| `transactions` | Appointment and sale records |

### Row Level Security

Staff can only access data from their assigned store:
- Admins see all stores' data
- Store managers see their store's data
- Staff members see only their assigned store

## Deployment

### TestFlight (Internal Testing)

1. In Xcode: Product → Archive
2. Open Organizer → Distribute App
3. Choose App Store Connect
4. Upload and share with testers

### App Store Submission

1. Update privacy policy URL in App Store Connect
2. Ensure all permissions are documented in Info.plist
3. Test on multiple device types
4. Submit for review

## License

MIT - See [LICENSE](../LICENSE) file.
