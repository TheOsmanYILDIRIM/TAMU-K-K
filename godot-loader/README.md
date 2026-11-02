# OSMAN Godot Loader (Android, first functional prototype)

One APK acts as a player for external **Godot 4.6 PCKs**. It is not the Godot editor and does not rebuild the game APK for content updates.

## Workflow

1. On the TAMU Godot branch, `godot --headless --path . --export-pack Android build/tamu-android-content.pck` produces a compiled PCK. The existing TAMU workflow now uploads the PCK next to its APK.
2. Install `OSMAN_Godot_Loader-debug.apk` once (the separate `Godot Loader Android` workflow).
3. From a file manager, tap a `.pck` file and choose **Open with → OSMAN Godot Loader** (or use **Share → OSMAN Godot Loader** where available). Android sends `ACTION_VIEW` / `ACTION_SEND`; the loader copies and validates the pack, then asks for explicit confirmation before running third-party game scripts. Some file managers may not expose the app for a PCK because they send an unsupported MIME type; in that case use the in-app picker.
4. Alternatively, in the loader, pick the downloaded `.pck` with Android's Storage Access Framework. It is copied to `filesDir/packs/<sha256>.pck`, fsynced and atomically published.
5. Tap **OYUNU AÇ**. The non-exported `GameActivity` starts a custom Godot 4.6 runtime using `--main-pack /data/user/0/.../files/packs/<sha256>.pck`.
6. Import a replacement PCK to update. No game APK rebuild is necessary.

## Engine constraint

**The stock Godot 4.6 Android export template is insufficient for external packs.** The workflow compiles `godotengine/godot` at tag `4.6-stable` for `arm64` with `disable_path_overrides=no`, packages the resulting `godot-lib.template_debug.aar`, and builds a minimal Java/Android host app. Do not substitute the stock AAR or remove this flag.

## Current limits / acceptance

- PCK only, max 2 GiB; no source ZIP import or in-app resource compilation. Use the Godot editor/CI for resource imports before export.
- Single active PCK. Previous packs and game saves are not deleted; distinct projects with identical Godot `config/name` may share a `user://` namespace. **Do not use this as a general untrusted-game sandbox.** Native code/GDExtensions and scripts in imported packs run with app privileges; use trusted content only.
- Android architecture ARM64 only; debug APK, no production signing. Device boot, orientation, save isolation, graphics, and FPS must be verified on a physical Android device. CI compile is not device proof.
- Android manifest declares `ACTION_VIEW` and `ACTION_SEND` for `application/octet-stream`, `application/x-godot-pck` and `application/x-pck`; a generic binary association can list Loader for other files, but known non-`.pck` names and invalid PCK headers are rejected. Incoming `content://`/local `file://` URIs are copied, never executed directly. A file-manager import asks the user before launching GDScript.
- Android SAF picker avoids storage-wide permissions; files are copied to private storage, not executed directly via `content://`.
- GitHub Actions job compiles Godot's C++ native engine, so it is resource-intensive. Check workflow results and artifact existence before calling the APK delivered.
- This is independent of TAMU's gameplay/save implementation. Does not alter `main`, LÖVE or existing user data.
