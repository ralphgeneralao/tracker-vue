# Debt Tracker

A Vue debt tracker with Supabase profiles and Google sign-in. The public
landing page is available to everyone; the personal dashboard and debt records
are available only after signing in.

## Supabase and Google setup

1. In the Supabase SQL Editor, run (or re-run)
   [`supabase/schema.sql`](./supabase/schema.sql). It creates the
   `public.debts` table and row-level security policies so each signed-in user
   can only read and change their own debt records. The script also retains the
   earlier profile and habits schema for existing data; old habits are not
   converted into debt records.
2. In Google Cloud Console, create an OAuth client ID for a web application.
   In Supabase **Authentication → Providers → Google**, enable Google and enter
   the client ID and client secret. Add the exact callback URL shown by Supabase
   to the Google OAuth client's **Authorized redirect URIs**. Add your app
   origin (for local development, `http://localhost:5173`) to **Authorized
   JavaScript origins**.
3. In Supabase **Authentication → URL Configuration**, set the site URL to your
   app URL and add the local development URL (`http://localhost:5173`) and any
   deployed app URLs to the allowed redirect URLs.
4. Copy `.env.example` to `.env` and set `VITE_SUPABASE_URL` and
   `VITE_SUPABASE_PUBLISHABLE_KEY` from the Supabase project's API settings.
   The app also accepts the legacy `VITE_SUPABASE_ANON_KEY` variable. Use the
   public anon/publishable key only; never put the service-role key in a
   frontend environment variable.
5. Restart the Vite development server, then choose **Continue with Google**.

Each debt record stores the debtor's name, amount owed, and expected payment
date. Amounts are displayed without a currency symbol; use the same currency
for every record so the outstanding total is meaningful. Existing habit data
is retained in the legacy database tables but is not displayed or migrated
into debts.

## Development

```sh
npm install
npm run dev
```

Create a production build with `npm run build`.
