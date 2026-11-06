# WhatsApp Sent Gallery

A Flutter Android app that displays images inside the folders selected by the user through Android Storage Access Framework (SAF).

## Features
- Separate folder access for WhatsApp and WhatsApp Business.
- User selects each `Sent` folder once using Android's system folder picker.
- Persistent read permission across app restarts.
- Grid gallery, full-screen image viewer and pinch zoom.
- Refresh to rescan selected folders.
- No broad storage permission and no upload/network feature.

## Folder setup
Select each folder separately:

- WhatsApp: `Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/Sent`
- WhatsApp Business: `Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Images/Sent`

Android's folder picker may initially open elsewhere. Navigate through `Internal storage` / `Android` / `media`. On some Android builds, access to parts of `Android/data` is restricted, but these WhatsApp media folders are normally under `Android/media`.

If the app reports no images, confirm that you selected the actual `Sent` folder, not its parent `WhatsApp Images` folder. You can select a different folder again at any time.

## Build locally
Install Flutter and Android SDK, then run:

```bash
flutter pub get
flutter analyze
flutter build apk --release
```

APK output:
`build/app/outputs/flutter-apk/app-release.apk`

## Build with GitHub Actions
1. Create a GitHub repository.
2. Upload/push the contents of this project to the repository's root.
3. Push to `main` or `master`, or open **Actions → Build Android APK → Run workflow**.
4. Open the completed workflow run.
5. Download the artifact named `whatsapp-sent-gallery-release`.
6. Extract the ZIP to get `app-release.apk`.

## Notes
- The app reads image files only; it does not modify or delete them.
- The folder permission is stored locally by Android.
- If WhatsApp is reinstalled, media is moved, or Android revokes the folder permission, select the folder again.
- The current version recursively scans image files under the selected folder. For best results, select the exact `Sent` directory.
