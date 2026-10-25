# Hear this post

Every flyer has a “Hear this post” button. It reads the headline, category,
description, price, neighborhood, and approximate distance when available.
Reading does not request GPS permission. When distance is unavailable, it
explains how to obtain it or says that the post has no location.

The shared audio player offers Pause, Resume and Stop. Starting another post
cancels the previous post; obsolete playback callbacks cannot stop new audio.
Playback stops when leaving the page and never starts automatically.

This uses the browser Web Speech API with the device's available voices and
the page/post language. No paid API or application server is used for speech;
the browser or operating system controls whether its selected voice uses a
network service. Unsupported browsers show a disabled “Read aloud unavailable”
button. Voice availability and pause/resume behavior vary by device.

Verified JavaScript syntax and mocked speech lifecycle checks: narrated fields,
distance text, pause/resume, stop, completion, stale callback isolation, errors,
missing coordinates, and unsupported browser. Real-device audio testing remains
necessary after publication. Confirm the hosting deployment after publishing main.
