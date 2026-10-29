# LeafNote — Flutter PDF reader prototype

Android/iOS Flutter starter. Local-only document storage; PDF import, library, page navigation, freehand annotation, undo, page position persistence, PDF export/share, and simple text-to-PDF creation.

## Run

1. Install Flutter SDK and Android Studio or Xcode.
2. In this directory run `flutter create . --platforms=android,ios` (on macOS for iOS).
3. Run `flutter pub get` and `flutter run`.
4. For an Android APK: `flutter build apk --release`.

## Important limitations

- This is a **prototype**, not a fully tested release. Flutter SDK is not installed in the authoring environment, so compilation/device tests have not been performed.
- Text-to-PDF bundles NanumGothic for Korean text support. Confirm bundled font license conditions before redistributing the app.
- PDF export rasterizes pages; selectable text and vector fidelity are lost. A production release should use native PDF annotations rather than flattening the document.
- Page aspect ratio follows the original PDF page. Zoom, search, highlights, bookmarks, EPUB import, OCR, accessibility and cloud sync are planned, not implemented.
- Ink strokes are saved in SharedPreferences; migrate to SQLite/Isar for production.
- A production build must include import/export error handling, file name collision handling, large-file memory controls, and tests.
