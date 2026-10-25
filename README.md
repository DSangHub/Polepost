# Polepost.org

Local flyers and community profiles. Static single-file site: serve `index.html` over HTTPS; no build step is required.

## Features

- Supabase magic-link accounts and editable profiles.
- Profile images: five reusable free slots; a one-time $5 pass enables up to ten total slots for 30 days. **Paid upgrades remain disabled pending Stripe configuration.** See [IMAGE_UPLOADS.md](IMAGE_UPLOADS.md).
- GPS-tagged posts and click-to-view approximate straight-line distance. See [GEOLOCATION.md](GEOLOCATION.md).
- Hear each post using browser text-to-speech, with pause, resume, and stop. See [READ_ALOUD.md](READ_ALOUD.md).
- Forum profiles and signed-in community feedback for Music Groups, Bands, Local Businesses, and Religious Organizations. See [FORUM.md](FORUM.md).

## Backend

Supabase project `nwwkiljmxbtzoxafsesq`. Original `schema.sql` describes the profile/flyer baseline. Image, geolocation, and Forum SQL additions in this repository have already been applied to that project; do not reapply them blindly. Edge Function sources live in `supabase/functions/` and the deployed functions authenticate user JWTs themselves.

The browser contains only a public Supabase publishable key. Database ownership policies and private image storage enforce access. Never place secret keys in frontend code.

## Verification

JavaScript syntax, speech lifecycle mocks, distance calculation tests, image allowance and expiry transaction tests, and Forum RLS tests passed. Forum access checks are reproducible with rollback-only `forum-rls-test.sql`. Real-device audio/GPS, signed-in upload UI, deployment, and paid Checkout end-to-end validation remain pending. `vercel.json` retains the existing static hosting settings.
