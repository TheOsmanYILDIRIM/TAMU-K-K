# 🕹️ OSMAN Godot Loader

**Play Godot games on Android without opening the editor or rebuilding an APK for every game update.**

OSMAN Godot Loader is a reusable Android game launcher, similar in spirit to a LÖVE loader. Install the Loader APK **once**, then import an exported **Godot 4.6 `.pck`** game pack and launch it directly. The player and the game content are distributed separately.

**Status:** Working prototype / **Android debug APK**, not a Google Play release. [GitHub Actions has successfully built the Loader with Android file-manager integration](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41416339859). Individual phone models, third-party game packs, and per-game save isolation are not certified by that CI result.

## Table of contents

- [Quick start](#quick-start)
- [Download and install](#download-and-install)
- [Open a PCK from Android](#open-a-pck-from-android)
- [Export your own Godot game](#export-your-own-godot-game)
- [Compatibility and limitations](#compatibility-and-limitations)
- [Troubleshooting](#troubleshooting)
- [How it works](#how-it-works)
- [Build the Loader from source](#build-the-loader-from-source)
- [Privacy, security and saves](#privacy-security-and-saves)
- [Contributing and licensing](#contributing-and-licensing)

## Quick start

1. Visit the [Godot Loader Android workflow](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/workflows/godot-loader-android.yml), open a successful run, and download its **OSMAN-Godot-Loader-Android** artifact.
2. **Unzip** that artifact and install **OSMAN_Godot_Loader-debug.apk** on an **ARM64 Android 7.0+** phone.
3. Download or export a **Godot 4.6 `.pck`** game file (not an APK, ZIP, or raw project folder).
4. Tap the PCK in your Android file manager → **Open with → OSMAN Godot Loader**. Alternatively open Loader → **PCK İÇERİ AKTAR**.
5. The app copies the game to private storage. Confirm a file-manager launch and tap **OYUNU AÇ** to play.

### Türkçe hızlı başlangıç

1. [Başarılı Loader Actions çalışmasından](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/workflows/godot-loader-android.yml) **OSMAN-Godot-Loader-Android** artefaktını indir. ZIP'i açıp **OSMAN_Godot_Loader-debug.apk** dosyasını telefona kur (Android 7+, ARM64).
2. Godot 4.6'dan dışa aktarılmış **.pck** oyun paketini indir. GitHub Actions artefaktı ZIP olarak iniyorsa içinden PCK'yi çıkar.
3. Dosya yöneticisinden **Birlikte aç → OSMAN Godot Loader** seçeneğini kullan. Görünmüyorsa uygulamada **PCK İÇERİ AKTAR** düğmesine bas.
4. Güvendiğin bir paket için çalıştırma onayı ver ve **OYUNU AÇ** ile başlat. Editör açılmaz.

## Download and install

- Open the [Loader's workflow runs](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/workflows/godot-loader-android.yml).
- Choose a **completed/success** run on the `experiment/godot4-android-apk-20261031` branch. Under **Artifacts**, download **OSMAN-Godot-Loader-Android**. Artifacts are ZIP files, may expire, and GitHub may require sign-in.
- Unzip it; install the included **OSMAN_Godot_Loader-debug.apk**. Android might ask for permission to install applications from the selected browser/file manager.
- Launch OSMAN Godot Loader. It does not ship with TAMU or any other game embedded.

**Reference:** [Successful Loader run #41416339859](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/runs/41416339859) includes file-manager VIEW/SEND support. Prefer a newer successful run if available.

**Do not confuse the downloads:** the **Loader APK** is from [Godot Loader Android](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/workflows/godot-loader-android.yml), while the **TAMU game PCK** is generated separately by [Godot PCK and native visual checks](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/workflows/godot4-android-baseline.yml). An Actions artifact ZIP is not itself a game pack.

## Open a PCK from Android

### Method A — file manager

1. Tap a file ending in `.pck`.
2. Select **Open with / Birlikte aç → OSMAN Godot Loader**. Some file managers offer **Share / Paylaş → OSMAN Godot Loader** instead.
3. Let the app copy the selected PCK. When opened from a file manager, it offers **OYUNU AÇ** (launch) or **SADECE İÇERİ AKTAR** (import only).
4. Select launch only for games you trust.

**Why the app may not appear:** File managers use different MIME types for PCK files. The Loader supports Android `ACTION_VIEW` and `ACTION_SEND` for `application/octet-stream`, `application/x-pck`, and `application/x-godot-pck`, but some providers don't send a matching type. Because `application/octet-stream` is generic, the app may also appear for unrelated binary files; it rejects known non-PCK names and invalid headers.

### Method B — Loader's file picker

1. Open **OSMAN Godot Loader**.
2. Tap **PCK İÇERİ AKTAR** and select the `.pck` through Android's system file picker.
3. When import finishes, tap **OYUNU AÇ**.

The picker uses Android's Storage Access Framework (SAF). The Loader does **not** need the broad **All files access** permission.

### Update a game

Export a **new, complete** PCK and import it again. The last successfully selected pack becomes the one launched by **OYUNU AÇ**, without reinstalling the Loader APK. Existing PCKs are retained, not automatically overwritten or removed. There is currently no multiple-game library, update checker, built-in cleanup tool, or rollback screen.

## Export your own Godot game

Use the **Godot 4.6 editor** and make sure your project has a working `project.godot` and **main scene**. Install matching export templates and configure an export preset; the example below uses a preset named `Android`.

**Graphical editor:** **Project → Export → select Android preset → Export PCK/ZIP**, then save the output with a `.pck` extension.

**Command line** (from a computer or CI runner with the Godot editor and matching export templates):

```bash
godot --headless --path /path/to/my-game --import --quit
godot --headless --path /path/to/my-game --export-pack "Android" /path/to/output/MyGame.pck
```

The preset name must match your `export_presets.cfg`. An export pack contains game resources **but no Android runtime**. Select `.pck`, not a ZIP-formatted pack. Export a **complete** main pack; patch-only packs, encrypted packs, or project-specific native extensions are not generally supported by this Loader.

**Critical export checklist:** Confirm that the pack contains the game's **startup scene, referenced scripts (`.gd`/`.gdc`), shader resources, imported textures/audio, scenes, and other runtime dependencies**. If you configured *export selected resources*, the export may silently omit scripts or shaders needed at startup. A syntactically valid PCK can still display a blank/gray screen when those files are missing.

For a working example, see the existing [TAMU PCK export workflow](../.github/workflows/godot4-android-baseline.yml). Godot documentation: [Exporting projects](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html) and [Exporting packs](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_pcks.html).

## Compatibility and limitations

| Capability | Current status |
| --- | --- |
| Run exported game without Godot editor UI | Yes; custom external PCK runtime |
| Install Loader once, replace game content | Yes; import another complete PCK |
| Open via Android file manager or share menu | Supported when MIME association matches |
| Internal Android file picker | Yes |
| Raw `project.godot` folder or source ZIP | **Not supported** |
| ZIP game pack | **Not supported**; use `.pck` |
| Engine version | **Godot 4.6** targeted; other versions unverified |
| Android version / CPU | **Android 7.0+ (API 24), ARM64 (`arm64-v8a`)** |
| Maximum imported PCK | **2 GiB** |
| Multiple game library | Not yet; **one selected pack** |
| Game update downloads | Manual import; no built-in network downloader |
| Android package | Debug APK artifact; no signed production/store release |
| Godot C# / platform-specific native extensions | Not generally verified |
| Independent save directory per imported game | **Not guaranteed** |
| Real-device and performance certification | No broad device/FPS certification from CI |

**This tool is a game runner, not an editor, APK builder, resource compiler, or secure app sandbox.**

## Troubleshooting

| Symptom | Action |
| --- | --- |
| **Open with** doesn't offer Loader | Try **Share**, then use **PCK İÇERİ AKTAR** as a guaranteed in-app alternative when SAF can read the file. |
| “Invalid PCK” / import rejected | Unzip GitHub's downloaded artifact **first**. Confirm the file is actually Godot-exported `.pck`, not a renamed ZIP or APK. |
| APK installation fails | Check Android 7.0+, ARM64 support, free space and installation-source permissions. |
| Gray or empty screen | Re-export with the **main scene, scripts, shaders and all dependencies**. Check Godot 4.6 renderer settings and import failures. |
| Desktop game works, Android does not | Examine Android graphics compatibility, resource path casing, imported assets, native libraries and engine version. |
| Import worked, play fails | Try a known-good Godot 4.6 pack, then inspect **Godot** and **AndroidRuntime** logs. |
| Wrong save or progress | Another game might share the same Godot `config/name` / `user://` namespace. Back up saves before switching unrelated games. |
| App storage grows | Old packs are kept. **Do not clear app storage** unless you've independently backed up game data. |

To capture a diagnostic log from a computer with Android Debug Bridge:

```bash
adb logcat -d > godot-loader-logcat.txt
```

Reproduce the problem first, then inspect for `Godot`, `AndroidRuntime`, missing resources, and shader errors. **Remove personal/device information before posting logs publicly.**

## How it works

```text
Godot 4.6 project + export preset
        │ editor / GitHub Actions: export-pack
        ▼
      MyGame.pck
        │ Android file manager (Open with / Share)
        │ or in-app SAF picker
        ▼
      MainActivity
        │ stream to private storage, check GDPC header/size
        │ SHA-256 filename + fsync + atomic rename
        ▼
      filesDir/packs/<sha256>.pck
        │ selected pack (user initiates launch)
        ▼
      GameActivity (not exported to other apps)
        │ --main-pack <absolute path>
        ▼
      Custom Godot 4.6 ARM64 runtime → game main scene
```

**Engine detail:** Standard Godot Android export templates do not enable this external-main-pack use case by default. CI builds a custom Godot 4.6 Android native library with **`disable_path_overrides=no`**, then packages it into the Loader. Do not replace that library with an ordinary stock AAR and expect external PCK loading to work.

| Source | Role |
| --- | --- |
| [MainActivity.java](android/app/src/main/java/com/osman/godotloader/MainActivity.java) | Launch screen, Android VIEW/SEND intents, import and consent |
| [PackStore.java](android/app/src/main/java/com/osman/godotloader/PackStore.java) | PCK size/header checks, private copy, SHA-derived filename |
| [GameActivity.java](android/app/src/main/java/com/osman/godotloader/GameActivity.java) | Non-exported game activity; injects `--main-pack` |
| [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) | Activity exposure, MIME intent filters, permissions |
| [PackStoreTest.java](android/app/src/test/java/com/osman/godotloader/PackStoreTest.java) | Filename/header regression tests |
| [Android build workflow](../.github/workflows/godot-loader-android.yml) | Custom native engine, Gradle, unit tests, manifest checks, artifact |

## Build the Loader from source

**Recommended path:** run the existing [Godot Loader Android GitHub Actions workflow](https://github.com/TheOsmanYILDIRIM/TAMU-K-K/actions/workflows/godot-loader-android.yml). Its build definition is the authoritative, repeatable starting point for contributors.

The workflow:

1. Checks out this repository and upstream **`godotengine/godot` at `4.6-stable`**.
2. Installs the Godot native build prerequisites, Android SDK/NDK, JDK 17 and SCons.
3. Builds the Godot ARM64 debug native library with **`platform=android target=template_debug arch=arm64 optimize=speed disable_path_overrides=no`**.
4. Builds **`godot-lib.template_debug.aar`** and copies it to `godot-loader/android/app/libs/`.
5. Builds `app-debug.apk` using the upstream Godot Gradle wrapper, runs `:app:testDebugUnitTest`, checks native `libgodot_android.so`, APK archive integrity, and manifest VIEW/SEND filters.
6. Publishes **OSMAN_Godot_Loader-debug.apk** as an Actions artifact if all steps succeed.

Local builds need a matching toolchain: **JDK 17, Android SDK 35, NDK 28.1.13356709, SCons, upstream Godot 4.6 source and Gradle**. The Loader's Gradle project expects a prebuilt custom AAR. Just opening `android/` without supplying it is not a complete build setup. Consult the workflow for commands; no local build claim is made here.

**Validation levels:** JVM tests and APK checks are CI evidence, **not** proof that a specific handset successfully opens a particular PCK. Report device model, Android version, Godot pack version and logs when testing on real devices.

## Privacy, security and saves

- **Only run games from publishers you trust.** A Godot PCK can include executable scripts and potentially native extensions. The Loader is not a sandbox or malware scanner.
- `GDPC` header checking and a SHA-256-derived storage filename detect obvious file mismatch and select a private path, but **do not authenticate the publisher** or guarantee the full pack is trustworthy.
- Imported `content://` or local `file://` streams are copied to an app-private `filesDir/packs/` path. The Loader does not execute directly from the file manager's URI, request broad storage permissions, or automatically launch a pack selected through its own picker.
- The file-manager route asks for confirmation before running imported code. The app currently retains old packs and uses one active selection.
- **Save data:** Two unrelated games using the same Godot `config/name` may share a `user://` save path. No guaranteed separate save profiles or safe migration feature exists. Never clear Loader app data without backups.
- The Android manifest declares the **INTERNET** permission, but the Loader UI does not implement a remote game catalog, auto-updater, or telemetry service. Each imported game may have its own network behavior.

## Contributing and licensing

Contributions and bug reports are welcome via the [repository](https://github.com/TheOsmanYILDIRIM/TAMU-K-K). Include the affected pack/engine versions, precise reproduction steps, device model, screenshots/logs when relevant, and the GitHub Actions run or commit. Keep changes scoped to `godot-loader/` and the existing Loader workflow where possible; do not alter the TAMU game or users' saved data as part of an unrelated Loader fix.

The underlying [Godot Engine uses the MIT License](https://github.com/godotengine/godot/blob/4.6-stable/LICENSE.txt). **That does not automatically license this repository's Loader code or game assets.** There is currently no separate repository/Loader `LICENSE` file; obtain maintainer permission before redistributing, relicensing or reusing this project's code/content. Do not bundle third-party artwork or other assets without checking their licenses.

---

**TAMU is the first example game, not a runtime dependency.**
