# Onestop · Snake Alert (demo)

A standalone demo of the **Snake Alert** add-on for IIT Guwahati's Onestop app: report snake sightings on a campus map, see nearby reports, and let the hostel authority mark areas safe.

- **Open it in your browser:** https://kaveiduo.github.io/snake-watch/
- **Android app (APK):** https://github.com/KaveiDuo/snake-watch/releases/latest/download/SnakeAlert.apk

This is a design demo built from the Figma prototype. It uses example data only: reports stay on your own device and reset when the app restarts, and there is no real sign-in.

**Snake scanner:** it identifies photos with Google Gemini's free tier (`gemini-3.8-flash`, falling back to 3.6 Flash and 3.5 Flash-Lite), using a key added at build time. Anyone can use their own Gemini or Anthropic key instead in **Profile → Snake scanner key**. Results are a guide, not a diagnosis.

## Build

```bash
flutter pub get
flutter build apk --release
./build_web.sh
```

`build_web.sh` builds the web version without an offline service worker, so phones always load the latest version, and replaces Flutter's worker with one that removes old caches. Both build scripts read the scanner's free Gemini key from `scanner_key.txt`, which is not committed. Without that file, the scanner shows demo matches.

On the original Windows PC use `build_apk.ps1`, which works around a Java temp-folder issue.

Snake photos: Wikimedia Commons. Map © OpenStreetMap contributors.

- Profile photos (student, Housekeeping, Security guard): Unsplash (Unsplash License): https://unsplash.com/photos/XrF99ON2upU, https://unsplash.com/photos/C7m7RSFONYc, https://unsplash.com/photos/o73QvWNLags
