# REHAB-X AI

Move Better. Recover Smarter.

REHAB-X AI is a local-first Flutter application for sports rehabilitation movement analysis. It uses on-device Google ML Kit pose detection when camera access and native platform support are available. It does not diagnose injuries or medically clear athletes.

## Current implementation

- Dark REHAB-X AI dashboard with Home, Analyze, Recovery, Progress, and Profile navigation.
- Exercise catalog, real camera preview/frame streaming, and honest camera/pose-model error states.
- Google ML Kit pose detection on Android/iOS and MediaPipe Pose Landmarker in Chrome, with confidence filtering, landmark mapping, and real skeleton overlay.
- Pose, session, athlete profile, and movement metric domain contracts.
- Landmark-based joint-angle and movement range calculations with insufficient-data protection.
- Local athlete profile persistence through `shared_preferences`.
- No account or OAuth sign-in is required; profile and movement history remain on this device.
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

The coach supports natural, multi-turn conversation and can use the athlete's recorded sessions when relevant. The bundled backend currently calls **Gemini**, not an OpenAI GPT model. An OpenAI/ChatGPT subscription is not an API key, and setting `OPENAI_API_KEY` alone will not work with this backend.

Create a Gemini API key, then set it only in the backend process; never put it in Flutter code, `--dart-define`, or a committed file:

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

Keep the backend running in that terminal, then start Flutter in a second terminal with the backend URL:

```powershell
flutter run -d chrome --web-hostname localhost --web-port 7357 --dart-define=REHAB_X_API_URL=http://127.0.0.1:8000
```

The coach connection banner reports backend status and offers a retry action. Without a valid backend key, replies come from the limited local movement coach.

To use an actual OpenAI GPT model instead, the backend must be changed to call OpenAI's API (including mapping conversation history and parsing its response). The current backend does not implement OpenAI yet; changing only an environment variable is insufficient. Keep any OpenAI API key server-side.

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

## Integration boundaries

`PoseDetectionServiceImpl` is selected by platform: Android/iOS use Google ML Kit with real camera frames, while Chrome uses MediaPipe Pose Landmarker on the browser camera video. The browser downloads the model/runtime from Google's model storage and jsDelivr; camera frames are processed in the browser and are not uploaded by this integration. Web-camera access requires localhost or HTTPS and user permission. Browser and mobile results are 2D pose estimates, not calibrated physical distances or medical measurements. `UnavailablePoseDetectionService` remains available for tests and unsupported environments.

Real analysis currently supports the configured squat, lunge, single-leg balance, and shoulder-flexion analyzer paths. Runtime camera/model failures remain visible as unavailable, low-confidence, or insufficient-visibility states.

The recorded-video screen currently has no real video decoder/pose pipeline. Its debug preview uses generated frames, is explicitly marked as a simulation, and is never saved or included in Recovery, Progress, reports, or coaching context. Use live camera analysis for verified history.

Android release builds successfully with the current Flutter/AGP toolchain. iOS source integration is present, but device validation requires an Apple/iOS build environment.

The AI backend is optional and calls Gemini only when `GEMINI_API_KEY` is configured. It does not store chat history or include provider secrets in the Flutter app; credentials must remain server-side and be supplied through environment configuration.
