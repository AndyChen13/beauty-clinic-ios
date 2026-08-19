# Beauty Clinic iOS

Internal management app for beauty clinics.

## Setup Instructions

### 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Sign up and create a new project (free tier works)
3. Wait for project deployment (~5 minutes)

### 2. Initialize Database

1. In Supabase Dashboard, go to **SQL Editor**
2. Copy the contents of `supabase/migrations/001_init_schema.sql`
3. Paste and run the SQL

### 3. Configure Authentication

1. Go to **Authentication** → **Providers** in Dashboard
2. Enable **Phone Provider**
3. Add your SMS provider credentials (Twilio, Aliyun, etc.)
4. Optional: Add test phone numbers to **Users** list

### 4. Create Storage Buckets

Run this SQL in Supabase:

```sql
insert into storage.buckets (id, name, public) values 
('training-materials', 'training-materials', true),
('customer-images', 'customer-images', false);
```

Or create manually via Dashboard: **Storage** → **Create Bucket**

### 5. Configure Xcode Project

1. Clone/download this repository
2. Open `BeautyClinic.xcodeproj` in Xcode 15+
3. In `App.swift`, update:

```swift
let client = SupabaseClient(
    url: "https://YOUR_PROJECT.supabase.co",
    apiKey: "YOUR_ANON_KEY"
)
```

4. Enable capabilities:
   - **Signing & Capabilities** → Push Notifications
   - AddPrivacy - Phone Book Usage Description to Info.plist

### 6. Run

```bash
# In Terminal (from project directory)
xcodebuild -project BeautyClinic.xcodeproj \
    -scheme BeautyClinic \
    -sdk iphonesimulator \
    -configuration Debug
```

## Development

### Project Structure

```
BeautyClinic/
├── App.swift              # Main app entry point
├── Models/                # Data models (SwiftData)
│   ├── User.swift
│   ├── Store.swift
│   ├── Customer.swift
│   ├── Package.swift
│   └── Transaction.swift
├── Views/                 # SwiftUI views
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
│   └── Transactions/
│       ├── TransactionListView.swift
│       └── TransactionRecordView.swift
├── Services/              # Supabase integration
│   └── SupabaseClient.swift
└── Assets.xcassets        # App assets
```

## Testing

1. Use TestFlight for internal testing
2. Create test user accounts with known phone numbers
3. Verify RLS policies: staff should NOT see other stores' data

## Deployment

### Pre-Submission Checklist

- [ ] Update privacy policy URL in App Store Connect
- [ ] Test all CRUD operations end-to-end
- [ ] Verify app icon and launch screen
- [ ] Enable Push Notifications capability
- [ ] Add Privacy - Camera Usage Description to Info.plist (if photo capture enabled)

### Submit to App Store

1. In Xcode: **Product** → **Archive**
2. Open Organizer → **Distribute App**
3. Choose **App Store Connect**
4. Sign in with Apple Developer account
5. Follow upload wizard

## Troubleshooting

### "Auth session not found"

- Check Supabase API key is correct
- Verify phone number is in allowed list (if enabled)

### "Row level security policy violation"

- Verify RLS policies are applied
- Check `users` table has matching `store_id`

### Storage upload fails

- Ensure storage bucket exists: `training-materials`
- Check public/private bucket settings match your use case

## License

MIT - See LICENSE file.
