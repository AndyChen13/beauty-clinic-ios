# Beauty Clinic iOS - Internal Management System

A native iOS app for beauty clinic internal management, built with SwiftUI + Supabase.

## Features

- 📱 **Multi-user authentication** via phone number (SMS OTP)
- 👥 **Customer management** - view/edit client profiles
- 💼 **Package & Training Materials** - manage beauty services with documentation
- 🏢 **Store management** - track active/pending branches
- 📊 **Transaction records** - log appointments and sales
- 🔐 **Row-level security** - staff only see their assigned store data

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | SwiftUI + SwiftData (iOS 17+) |
| Backend | Supabase (PostgreSQL + Auth + Storage) |
| File Storage | Supabase Storage (images, PDFs) |

## Setup Guide

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign up
2. Create new project → choose free tier
3. Copy **Project URL** and **Anon Key**

### 2. Initialize Database

Run the SQL in `supabase/migrations/001_init_schema.sql` in Supabase SQL Editor.

### 3. Configure Auth

In Supabase Dashboard:
- Authentication → Providers → Enable **Phone Provider**
- Upload your Twilio/SMS provider credentials
- Add phone number to allowed list (test only)

### 4. Xcode Setup

```bash
cd ~/Desktop/beauty-clinic-ios
open BeautyClinic.xcodeproj
```

In Xcode:
1. Update `SupabaseClient(url: apiKey:)` with your project credentials in `App.swift`
2. Enable capabilities: Push Notifications, Keychain Sharing (for Auth)
3. Add Privacy - Phone Book Usage Description to Info.plist

### 5. Run

```bash
# In Terminal (from repo root)
xcodebuild -project BeautyClinic.xcodeproj -scheme BeautyClinic -sdk iphonesimulator
```

## Directory Structure

```
beauty-clinic-ios/
├── BeautyClinic/                # Xcode project files
│   ├── App.swift               # Main app entry point
│   ├── Models/                 # Data models
│   ├── Views/                  # SwiftUI views
│   ├── Services/               # Supabase client wrapper
│   └── Assets.xcassets         # Images, colors
├── supabase/
│   └── migrations/
│       └── 001_init_schema.sql # Database schema
└── docs/
    └── PRIVACY_POLICY.md       # Privacy policy template
```

## License

MIT - See [LICENSE](LICENSE) file.
