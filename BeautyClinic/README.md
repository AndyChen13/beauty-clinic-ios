# beauty-clinic-ios - Project Files

This directory contains the Xcode project structure for the Beauty Clinic iOS app.

## File Structure

```
BeautyClinic/
├── App.swift                    # Main app entry point
├── Info.plist                   # App configuration
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
│   ├── Common/
│   │   ├── SearchBar.swift
│   │   └── AvatarView.swift
│   ├── HomeView.swift
│   ├── MainTabView.swift
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
│   ├── SupabaseClient.swift
│   └── SupabaseClient+Auth.swift
└── Assets.xcassets              # App assets (images, colors)
```

## Getting Started

1. Open `BeautyClinic.xcodeproj` in Xcode 15+
2. Update `App.swift` with your Supabase credentials
3. Run the app on simulator or device

## Configuration

In `App.swift`, replace these values:

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