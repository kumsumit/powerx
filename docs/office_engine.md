# Office Compatibility Engine

PowerX has two document paths:

1. Lightweight `.pptx`
   - Uses the Dart PPTX importer/exporter.
   - Available without downloading the Office Compatibility Engine.
   - Intended for fast, simple editing when the user does not need full fidelity.

2. Complete Office support
   - Required for legacy `.ppt`.
   - Required for full-fidelity `.pptx` editing.
   - Backed by a local Office engine such as LibreOfficeKit or Collabora core.
   - The engine may be installed on demand, but executable native code should be
     delivered through an app-store-supported mechanism such as Play Feature
     Delivery for Play Store builds.

Product rule:

- `.pptx` can open without the engine if the user accepts simplified support.
- `.ppt` must not open through a simplified parser; it requires the engine.
- Once the engine is installed, reading, editing, saving, and exporting should
  stay local and work offline.

The Flutter UI talks to `PresentationBackend`, not directly to a parser. This
keeps the UI independent from whether a document is handled by the lightweight
Dart implementation or by the complete local Office engine.

Android implementation:

- `AndroidOnDemandOfficeEngine` talks to the `powerx/office_engine` platform
  channel.
- The example Android app registers an on-demand `:office_engine` dynamic
  feature module.
- `MainActivity` handles `isInstalled`, `ensureInstalled`, and
  `convertLegacyPptToPptx`.
- `OfficeEngineBridge` in `:office_engine` is the native integration point for
  LibreOfficeKit/Collabora core. The bridge is compiled and delivered on demand;
  the actual native binaries still need to be added there.

Build/package workflow:

```sh
tool/office_engine/fetch_collabora_source.sh
tool/office_engine/build_collabora_android.sh
tool/office_engine/package_collabora_android.sh
```

The native Android engine build must run on Linux with Android SDK/NDK
installed. On macOS, use a Linux VM, CI runner, or containerized Linux builder.

Useful environment variables:

- `COLLABORA_SOURCE_DIR`: source checkout location
- `COLLABORA_BRANCH`: default `distro/collabora/co-25.04`
- `COLLABORA_ANDROID_ABI`: default `arm64-v8a`
- `COLLABORA_LO_BUILDDIR`: separate LibreOffice/Collabora core build directory
  for branches that do not contain an `engine/` subdirectory
- `COLLABORA_ANDROID_AAR`: prebuilt Collabora Android library AAR to package

The package step copies the built AAR to:

```text
example/android/office_engine/libs/collabora-office-engine.aar
```

The dynamic feature module consumes `*.aar` files from that `libs/` directory.
