# PowerX

PowerX is a reusable Flutter library for embedding a PowerPoint-style
presentation editor in another Flutter app.

## Usage

Add PowerX as a dependency:

```yaml
dependencies:
  powerx:
    path: ../powerx
```

Embed the editor:

```dart
import 'package:flutter/material.dart';
import 'package:powerx/powerx.dart';

void main() {
  runApp(const MaterialApp(home: PowerXEditor()));
}
```

If you want to control the editor state yourself, pass an `EditorCubit`:

```dart
final editorCubit = EditorCubit();

PowerXEditor(editorCubit: editorCubit);
```

## Example

Run the bundled example app:

```sh
cd example
flutter pub get
flutter run
```
