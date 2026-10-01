# REHAB-X AI

Move Better. Recover Smarter.

REHAB-X AI is a local-first Flutter application for sports rehabilitation movement analysis. It uses on-device Google ML Kit pose detection when camera access and native platform support are available. It does not diagnose injuries or medically clear athletes.

## Current implementation

- Dark REHAB-X AI dashboard with Home, Analyze, Recovery, Progress, and Profile navigation.
- Exercise catalog, real camera preview/frame streaming, and honest camera/pose-model error states.
- Google ML Kit pose detection provider with CameraImage conversion, confidence filtering, landmark mapping, frame throttling, and real skeleton overlay.
- Pose, session, athlete profile, and movement metric domain contracts.
- Landmark-based joint-angle and movement range calculations with insufficient-data protection.
- Local athlete profile persistence through `shared_preferences`.
- Gemini-backed conversational AI Coach when configured, with an explicit local movement-coach fallback.
- Optional FastAPI backend boundary in `backend/`.
- Focused widget, geometry, pose-quality, analyzer, session-controller, and repository tests.

## Run

```text
flutter pub get
flutter run
flutter analyze
flutter test
```

## Gemini AI Coach setup

The AI Coach uses the FastAPI backend so the Gemini key never ships in the Flutter app. Rotate any key shared in chat, then set the replacement only in the backend process:

```powershell
$env:GEMINI_API_KEY = '<set-your-key-locally>'
$env:GEMINI_MODEL = 'gemini-2.5-flash'
uvicorn app.main:app --app-dir backend --reload --port 8000
```

If Python is unavailable, use the Dart backend already included in the project:

```powershell
$env:GEMINI_API_KEY = '<set-your-key-locally>'
$env:GEMINI_MODEL = 'gemini-2.5-flash'
dart run backend/dart_server.dart
```

Start Flutter with the backend URL:

```text
flutter run -d chrome --web-hostname localhost --web-port 7357 --dart-define=REHAB_X_API_URL=http://127.0.0.1:8000
```

For an Android emulator, use the emulator's host-machine alias:

```text
flutter run -d android --dart-define=REHAB_X_API_URL=http://10.0.2.2:8000
```

For a physical Android device, replace the URL with the development computer's reachable LAN
address and allow that connection in its firewall.

When Gemini is connected, Mitra can answer general questions conversationally and uses up to the
12 most recent chat turns plus relevant profile/session context. If the backend is unavailable,
the app labels its more limited local movement-coach responses. AI answers can be wrong; verify
clinical decisions with a qualified healthcare professional.

## Google sign-in setup

Google sign-in requires OAuth credentials; it cannot work with only the Flutter package.

For Android, register the application package `com.example.flutter_application_1` with the Android OAuth client and its build-key SHA-1. No server client ID is configured or required by this app:

```text
flutter run -d android
```

For Chrome, authorize `http://localhost` and the Flutter web port in the web OAuth client, then launch with the configured client ID:

```text
flutter run -d chrome --web-hostname localhost --web-port 7357 --dart-define=GOOGLE_WEB_CLIENT_ID=115998672735-atm3kcee7lunc590joq156osrgo3gp39.apps.googleusercontent.com
```

The web sign-in control is the Google Identity Services button required by `google_sign_in` 7.x. The same web client ID is also the safe built-in default for local web development; the dart-define can override it. User cancellation returns to the login screen without an error message.

## Integration boundaries

`MlKitPoseDetectionService` is the production provider. It accepts real `CameraImage` frames, runs the on-device ML Kit base pose model, maps landmarks into the app's domain model, rejects low-confidence points, and never fabricates landmarks. `UnavailablePoseDetectionService` remains available for tests and unsupported environments.

Real analysis currently supports the configured squat, lunge, single-leg balance, and shoulder-flexion analyzer paths. Runtime camera/model failures remain visible as unavailable, low-confidence, or insufficient-visibility states.

Android release builds successfully with the current Flutter/AGP toolchain. iOS source integration is present, but device validation requires an Apple/iOS build environment.

The AI backend is optional and calls Gemini only when `GEMINI_API_KEY` is configured. It does not store chat history or include provider secrets in the Flutter app; credentials must remain server-side and be supplied through environment configuration.
