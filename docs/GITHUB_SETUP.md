# Beauty Clinic iOS - GitHub Repository

## Setup Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/beauty-clinic-ios.git
   cd beauty-clinic-ios
   ```

2. **Create Supabase Project**
   - Go to [supabase.com](https://supabase.com)
   - Create new project (free tier sufficient for startup)
   - Wait ~5 minutes for deployment

3. **Initialize Database**
   - In Supabase Dashboard, go to SQL Editor
   - Copy `supabase/migrations/001_init_schema.sql`
   - Paste and run in SQL Editor
   - Run the RLS policies SQL (same file)

4. **Configure Auth**
   - Go to Authentication → Providers
   - Enable Phone Provider
   - Add your SMS provider credentials

5. **Configure Xcode**
   ```bash
   # Update project with your Supabase credentials:
   # In App.swift, replace:
   url: "https://YOUR_PROJECT.supabase.co"
   apiKey: "YOUR_ANON_KEY"
   
   # Or use environment variables (recommended for production)
   ```

6. **Run in Xcode**
   ```bash
   open BeautyClinic.xcodeproj
   # Then press Cmd+R to run
   ```

## Required Environment Variables

Before building, set these in your terminal or Xcode scheme:

```bash
export SUPABASE_URL=https://YOUR_PROJECT.supabase.co
export SUPABASE_ANON_KEY=your-anon-key-here
```

## Testing

Use TestFlight for internal testing:
1. Archive app in Xcode (Product → Archive)
2. Distribute via TestFlight
3. Share with team members for testing

## License

MIT - See LICENSE file.