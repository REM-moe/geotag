# Geotag 2.0 — Revamp Plan

Branch: `revamp/astryx`. Visual reference: [`docs/ui-mock.html`](ui-mock.html) (open in a browser — it is the source of truth for layout, spacing and behaviour).

## Design rules (Astryx-style)
- Tokens only: `lib/theme/tokens.dart` (`Space`, `Radii`, `TextSize`, `Motion`, `context.geo.*` colours). No hard-coded colours/paddings in widgets.
- Neutral greys; colour only for actions and status (accent / positive / warning / negative).
- 1px hairline borders, **no drop shadows** on app surfaces.
- Figtree for UI, JetBrains Mono (`monoStyle()`) for coordinates/altitude/time.
- Capture tab is always-dark camera chrome; other tabs follow system light/dark.
- Out of scope now: cloud backup, proximity reminders ("remind me when nearby").

## Architecture
- `lib/main.dart` opens `CaptureRepository` → `GeotagApp` → `AppShell` (no permission wall).
- `lib/shell/` — `AppShell` (5 tabs, refreshes permissions on resume, listens to GPS service), `TabCubit`.
- `lib/data/` — `Capture` model + `CaptureRepository` (local JSON index + media in app documents; `allocate()`, `add()`, `updateNote()`, `delete()`, `changes` stream, `items`).
- `lib/cubits/permission_cubit.dart` — just-in-time `ensureCamera/ensureMicrophone/ensureLocation`, `PermStatus.{notAsked,denied,blocked,granted}`, `locationServiceEnabled`, `preciseLocation`, `openSettings()`, `openLocationSettings()`. `blocked` ⇒ button opens Settings.

## Ownership (two agents work in parallel — do not edit the other's files)
| Area | Owner | Files |
|---|---|---|
| Capture, permissions UX, stamps, native config | **Agent A (Camera)** | `lib/screens/camera_screen.dart`, `lib/screens/camera/**`, `lib/cubits/camera_cubit.dart`, `lib/cubits/location_overlay_cubit.dart`, `lib/cubits/template_cubit.dart`, `lib/templates/**`, `lib/widgets/**`, `lib/services/**`, `android/**`, `ios/**`, delete `permission_screen.dart` + `template_picker_screen.dart` |
| Library, Map, Notes, Detail, Settings | **Agent B (Library)** | `lib/screens/library/**`, `lib/screens/map/**`, `lib/screens/notes/**`, `lib/screens/detail/**`, `lib/screens/settings/**`, `lib/ui/**` (shared Astryx primitives) |
| Shared contracts | Coordinator | `lib/theme/**`, `lib/data/**`, `lib/shell/**`, `lib/cubits/permission_cubit.dart`, `lib/app.dart`, `lib/main.dart`, `pubspec.yaml` |

Need a contract change or a new package? Ask the coordinator.
