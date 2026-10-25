# Click a post to see distance

Click a post's headline or non-interactive card area. If the post has GPS
coordinates, the browser requests location permission and displays approximate
straight-line distance in miles. Links, image links and tear-off tabs retain
their existing actions. A retry button handles denied permission and timeouts.

The location menu also has “Use my current location” for nearby sorting and
radius filtering. Unknown post locations are shown last when sorting nearby
and remain visible when filtering; the board labels this explicitly.

Authors tag new posts using “Tag this post with my location” while at the
business or advertised location. Coordinates are rounded to three decimals
(roughly 100 metres). The public post stores those coordinates and estimated
accuracy. A viewer's GPS coordinates stay only in JavaScript memory for the
session and are never saved or sent to the backend.

Existing posts and seeded examples have no real coordinates and display
“Location not added.” Neighborhood labels alone no longer generate invented
distances. This change does not geocode addresses or calculate driving routes.

`geolocation-schema.sql` has been applied to `nwwkiljmxbtzoxafsesq`. Existing
author ownership policies and row-level security remain enabled.

Verification: JavaScript syntax passed; distance checks covered identical
locations, equatorial one-degree distance, null and invalid coordinates,
missing locations, and denied browser permission. Live database inspection
confirmed the new columns, coordinate constraint, and enabled RLS. Real-device
GPS behavior still requires testing after publishing.

The revised `index.html` includes the profile image interface as well as
geolocation. Confirm the hosting deployment after publishing main.
