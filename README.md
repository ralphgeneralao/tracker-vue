# Habit Tracker

A Vue habit tracker with Supabase profiles and Google sign-in. Without
Supabase configuration, the app shows the public landing page and Google
sign-in remains unavailable. The personal dashboard is shown only to signed-in
users.

## Supabase and Google setup

1. In the Supabase SQL Editor, run (or re-run)
   [`supabase/schema.sql`](./supabase/schema.sql). It creates the `habits` table,
   enables row level security so users can only read and change their own rows,
   and migrates existing habits from the `profiles.habits` JSON field without
   overwriting rows already in `habits`. After copying, the old JSON field is
   emptied so deleted habits cannot be restored from stale profile data.
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

Habits load from the signed-in user's rows in `public.habits`; the database is
the source of truth and Supabase row level security prevents access to another
user's habits. On first sign-in, an existing browser-local tracker is copied
into a new account when that account has no saved habits. A per-user local cache
is also kept for continuity.

## Development

```sh
npm install
npm run dev
```

Create a production build with `npm run build`.
