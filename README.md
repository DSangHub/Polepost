# polepost.org

Everything that was stapled to the pole — local gigs, instruments, eateries, handymen, and services, sorted by how far you'd have to walk.

Flyers on poles are unreadable at 35 mph. This puts them all in one place, filtered by your default location.

## What's here

Single-file static site. `index.html` contains all markup, styles, and script — no build step, no dependencies beyond a Google Fonts link.

## Features

- **Default location** — set by preset neighborhood or free text, plus a travel radius (1 / 3 / 6 miles or anywhere). Persists between visits.
- **Categories** — gigs, musical instruments, local eateries, handymen, local services. Category color is carried by the tape strip on each card.
- **Sort** by closest or newest. Distances recalculate from the saved location.
- **Tear-off tabs** — every flyer has a real fringe. Tearing a tab saves the number to "Your tabs" and leaves a gap on the card.
- **Post a flyer** — no account required.

## Local development

Open `index.html` in a browser, or:

```bash
python3 -m http.server 8000
```

## Deploy

Static. Any host works. On Vercel it needs no configuration — `vercel.json` just sets caching headers.

## Data note

Flyers still live in `localStorage`, so a post is visible only to the browser that wrote it. The `flyers` table in `schema.sql` is the next step for shared posting.

Listings are seeded demo content and distances are computed on a flat coordinate plane, not real geocoding. Swapping in a real backend means replacing the `SEED` array and the `coordsFor` / `milesTo` functions.
