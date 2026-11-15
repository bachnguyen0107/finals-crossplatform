# finals
DEPLOYMENT (WEB & SUPABASE KEEP-ALIVE)
======================================

Live Web URL: https://final-2e9fd.web.app

1. Local Environment Setup:
   Create a `.env` file in the project root directory (never committed to Git):
   SUPABASE_URL=https://nxiajtfwoizbpqsljpwu.supabase.co
   SUPABASE_ANON_KEY=<publishable_key_from_supabase_dashboard>

2. Run Locally on Web:
   flutter run -d chrome --dart-define-from-file=.env

3. Build and Deploy to Firebase Hosting:
   npm install -g firebase-tools
   firebase login
   flutter build web --release --dart-define-from-file=.env
   firebase deploy --only hosting

4. Supabase Keep-Alive Workflow:
   Free Supabase projects pause after 7 days of inactivity.
   The workflow in `.github/workflows/keep-alive.yml` runs every 3 days (and via manual dispatch) to send a lightweight GET request to:
   SUPABASE_URL/rest/v1/labels?select=id&limit=1
   Required GitHub Repository Secrets (Settings > Secrets and variables > Actions):
   - SUPABASE_URL
   - SUPABASE_ANON_KEY
