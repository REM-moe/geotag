# Geotag

> A privacy-respecting, ad-free GPS camera for iOS and Android. Captures photos and videos with a live location overlay — address, coordinates, altitude, compass heading, magnetic field, and time — burned directly into the file.

Built in Flutter with Material 3, dynamic color, and a Cubit state architecture. No backend, no analytics, no third-party tracking. Tiles come from free public sources, fonts cache locally after first launch.

---

## Features

- **Live geotag overlay** rendered over the viewfinder and burned into every shot
- **5 watermark templates** — Classic, DateTime, Reporting, Navigational (compass + altitude + magnetic field), Minimal
- **Real satellite tiles** (Esri World Imagery, free, no API key)
- **Reverse geocoding** via the OS — works offline once cached, never hits a paid endpoint
- **Lens-aware zoom presets** — taps map to physical ultra-wide / wide / telephoto lenses where they exist, or digital zoom otherwise
- **Pinch-to-zoom** and **tap-to-focus** with animated focus ring
- **Self-timer** — 3s / 5s / 10s / 20s with full-screen countdown
- **Flash auto / on / off**, front + back lens flip, video mode with elapsed-time pill
- **Front camera mirror fix** — text in selfies reads correctly, not reversed
- **Video watermark burn-in** via on-device FFmpeg (libx264, audio copy)
- **Portrait + landscape** layouts with safe-area handling for Dynamic Island and home indicator
- **Material 3 dynamic color** on Android 12+, fallback Poppins theme via `google_fonts`
- **Battery-aware** — GPS / compass / magnetometer pause when the app is backgrounded
- **Saved to your Photos** automatically (album: `Geotag`)

## Architecture

```
lib/
├── main.dart                       # entrypoint, orientation prefs
├── app.dart                        # MaterialApp + theme + BlocProviders
├── cubits/
│   ├── permission_cubit.dart       # Camera / Location / Mic permissions
│   ├── camera_cubit.dart           # Camera controller, zoom, lenses, timer
│   ├── location_overlay_cubit.dart # GPS + compass + magnetometer + geocoding
│   └── template_cubit.dart         # Selected template, persisted via shared_preferences
├── screens/
│   ├── permission_screen.dart      # Pre-permission UI + status rows
│   ├── camera_screen.dart          # Viewfinder + controls (portrait & landscape)
│   └── template_picker_screen.dart # Full-screen template picker w/ previews
├── widgets/
│   ├── geotag_overlay.dart         # Dispatches to selected template, adds brand chip
│   ├── map_thumbnail.dart          # Stateful flutter_map with MapController
│   ├── shutter_button.dart         # Animated photo↔video shutter
│   ├── zoom_selector.dart          # 0.5×/1×/2×/5× preset row
│   └── mode_carousel.dart          # PHOTO / VIDEO mode toggle
├── templates/
│   └── templates.dart              # All 5 template layouts + compass painter
└── services/
    ├── watermark_service.dart      # RepaintBoundary → PNG bytes
    ├── photo_stamper.dart          # image package composite + front-cam mirror
    └── video_stamper.dart          # ffmpeg_kit overlay + hflip
```

State management is a small set of independent Cubits hoisted above `MaterialApp` so pushed routes (the template picker, future settings) can reach them.

## Tech stack

| Concern | Package |
|--|--|
| State management | `flutter_bloc` + `equatable` |
| Camera | `camera` |
| Location | `geolocator` + `geocoding` |
| Compass / Mag | `flutter_compass` + `sensors_plus` |
| Permissions | `permission_handler` |
| Map tiles | `flutter_map` (Esri World Imagery, no API key) |
| Image editing | `image` |
| Video editing | `ffmpeg_kit_flutter_new` |
| Save to gallery | `gal` |
| Theming | `dynamic_color` + `google_fonts` (Poppins) |
| Persistence | `shared_preferences` |

## Setup

Requirements: Flutter 3.32+ (stable), Xcode 16+ for iOS, Android Studio with SDK 34+.

```bash
git clone <your-fork>
cd geotag
flutter pub get
cd ios && pod install && cd ..
```

### iOS — required entries

`ios/Runner/Info.plist` already includes:

- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSLocationWhenInUseUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`

Deployment target is **iOS 14** (required by `ffmpeg_kit_flutter_new`). `ios/Podfile` adds the `permission_handler` preprocessor macros:

```ruby
config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
  '$(inherited)',
  'PERMISSION_CAMERA=1',
  'PERMISSION_MICROPHONE=1',
  'PERMISSION_LOCATION_WHENINUSE=1',
  'PERMISSION_PHOTOS=1',
]
```

### Android — required entries

`android/app/src/main/AndroidManifest.xml` declares:

- `CAMERA`, `RECORD_AUDIO`
- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
- `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`
- `INTERNET` (map tiles)

## Run

```bash
# Debug
flutter run

# Specific device
flutter devices
flutter run -d <device-id>

# Release on a physical iPhone
flutter run -d <udid> --release
```

The iOS Simulator and Android Emulator do **not** expose camera or GPS hardware. Real-device testing is required for the camera, GPS, compass, and magnetometer.

## Build for size

Both platforms benefit from obfuscation and split debug info:

```bash
flutter build ios --release \
  --obfuscate --split-debug-info=build/debug-info

flutter build apk --release \
  --obfuscate --split-debug-info=build/debug-info \
  --split-per-abi
```

The ffmpeg binary adds ~80 MB on iOS. If you don't need video watermarks you can drop `ffmpeg_kit_flutter_new` from `pubspec.yaml` and the relevant calls in `lib/services/video_stamper.dart` and `lib/screens/camera_screen.dart`.

## Privacy

Geotag never sends your location off-device.

- GPS, address resolution, and watermark rendering all happen on the device
- Map tiles are fetched from Esri's public CDN. No request includes any identifier
- Photos and videos are saved to your local Photos library and never uploaded

## License

Geotag is licensed under the **GNU General Public License v3.0** (GPL-3.0).

This is a strong copyleft license. If you distribute a modified version, you must release your changes under the same license and provide the corresponding source code.

The full license text is in [`LICENSE`](LICENSE). A short summary:

> Geotag is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
>
> This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

## Acknowledgements

- Esri's World Imagery tile server for free satellite imagery
- The Flutter team for `flutter_map`, `camera`, and the broader plugin ecosystem
- ffmpeg + the community fork `ffmpeg_kit_flutter_new` for on-device video processing
