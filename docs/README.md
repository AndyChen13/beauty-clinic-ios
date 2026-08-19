# beauty-clinic-ios - GitHub Repository

## Quick Start

### 1. Create Supabase Project
- Go to [supabase.com](https://supabase.com)
- Sign up and create new project (free tier OK)

### 2. Initialize Database
In Supabase Dashboard → SQL Editor, paste contents of `supabase/migrations/001_init_schema.sql`

### 3. Configure Xcode
```bash
cd ~/Desktop/beauty-clinic-ios
open BeautyClinic.xcodeproj
```

Update credentials in `App.swift`:
```swift
let client = SupabaseClient(
    url: "https://YOUR_PROJECT.supabase.co",
    apiKey: "YOUR_ANON_KEY"
)
```

### 4. Run
```bash
xcodebuild -project BeautyClinic.xcodeproj \
    -scheme BeautyClinic \
    -sdk iphonesimulator
```

## Documentation

- `docs/SETUP.md` - Detailed setup guide
- `docs/GITHUB_SETUP.md` - GitHub-specific instructions
- `PROJECT_README.md` - Architecture overview

## License

MIT - See LICENSE file.