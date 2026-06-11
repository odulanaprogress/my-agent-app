# TODO_ROUTING - App not booting to homepage

## Symptoms
- Flutter app doesn’t navigate to Dashboard/Home after startup.

## Observed from flutter run (Chrome)
- Web boot fails while trying to fetch Google fonts / CanvasKit module.

## Current hypothesis
- In this environment, Chrome can’t fetch external resources (fonts.gstatic.com, www.gstatic.com/flutter-canvaskit/.../canvaskit.js).
- This fails during Flutter Web bootstrap, so app never reaches router navigation.

## Fix to apply
- Remove dependency on external web fonts (google_fonts) or inline fonts locally.
- Avoid CanvasKit/ensure we don’t rely on dynamic import from www.gstatic.com.
  - Prefer HTML renderer / disable CanvasKit if possible (flutter run --web-renderer html).

## Verify
- Run `flutter run -d chrome --web-renderer html`
- Confirm navigation to `/dashboard` or at least `/auth`/`/login`.

