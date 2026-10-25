# Profile images

Profile → Profile images accepts JPEG, PNG, and WebP, at most 5 MB each.
Accounts have five reusable free slots. A one-time $5 pass enables up to ten
total slots for 30 days. There is no subscription or automatic renewal.
Slots 6–10 stop appearing publicly at expiry; owners can remove them or renew.
The first available slot is used for each upload. The first active image is
shown in the account header; active profile images appear with the author's flyers.

## Backend

`image-schema.sql` is applied to Supabase `nwwkiljmxbtzoxafsesq`.
`pp-images.ts` and `pp-image-billing.ts` are deployed as `pp-images` and
`pp-image-billing`. Both verify user JWTs themselves, so gateway JWT checking
is disabled. The billing webhook retrieves each event by ID directly from
Stripe and uses only that authenticated API response, never submitted fields.

Storage is private and has no browser write policies. Uploads are authenticated,
checked for image file signatures and size, and reserved atomically under an
account lock. Clients cannot write image metadata or payment entitlements.
Public gallery URLs expire after at most 60 seconds, capped at pass expiry for
paid slots. Pending uploads count toward quota and can be removed by their owner.

## Payment activation — currently blocked

The shared project's existing `STRIPE_SECRET_KEY` belongs to another Stripe
account. It must not collect Polepost payments. Stripe connector writes also
returned repeated authentication requests; no payment link or webhook was created.

To activate the existing Checkout integration:

1. Set the Edge Function secret `PP_STRIPE_SECRET_KEY` to a restricted key for
   Polepost.org account `acct_1U4QffPG4Dmc1DVK`, with read access to the account,
   events, PaymentIntents and charges, and read/write Checkout Sessions access.
   Keep other apps' `STRIPE_SECRET_KEY` unchanged.
2. Register `https://nwwkiljmxbtzoxafsesq.supabase.co/functions/v1/pp-image-billing?webhook=1`
   in that account for `checkout.session.completed`,
   `checkout.session.async_payment_succeeded`, `charge.refunded`, and
   `charge.dispute.created`. Use API version `2026-08-26.dahlia`.
3. Verify Checkout and webhook fulfillment in an isolated Stripe sandbox, then
   set `PP_IMAGE_PAYMENTS_ENABLED=true` for the live integration.

Until activation, the upgrade button displays “payment setup pending” and
checkout fails closed. A success URL never grants paid slots. Server-side
fulfillment checks the registered session owner, plan purpose, USD 500 cents,
paid status, mode, live mode, and absence of full refunds/disputes. Fulfillment
is idempotent; separate purchases extend the current non-revoked entitlement.

## Verification performed

Live database transaction, rolled back: first five reservations succeed; sixth
free image rejected; paid pass duration is exactly 30 days; duplicate session
fulfillment grants only once; slots 6–10 succeed while paid; eleventh is rejected;
expiry prevents new paid-slot reservations. JavaScript syntax passed. A mocked
browser smoke test was prepared but could not run because Chromium is not installed.
A real signed-in upload and payment
purchase still need end-to-end testing; no customer was charged during setup.
