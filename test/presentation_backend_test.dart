import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerx/engine/presentation_backend.dart';
import 'package:powerx/engine/pptx_importer.dart';

void main() {
  test('opens pptx without requiring the office engine', () async {
    final pptxFile = File('${Directory.systemTemp.path}/powerx_backend.pptx');
    await pptxFile.writeAsBytes(ZipEncoder().encode(_minimalPptx()));
    addTearDown(() {
      if (pptxFile.existsSync()) pptxFile.deleteSync();
    });

    final engine = _FakeOfficeEngine();
    final presentation = await HybridPresentationBackend(
      officeEngine: engine,
    ).open(pptxFile.path);

    expect(presentation.filePath, pptxFile.path);
    expect(presentation.slides, hasLength(1));
    expect(engine.ensureAvailableCalls, 0);
  });

  test('requires the office engine before opening legacy ppt', () async {
    final pptFile = File('${Directory.systemTemp.path}/powerx_backend.ppt');
    final convertedFile = File(
      '${Directory.systemTemp.path}/powerx_backend_converted.pptx',
    );
    await pptFile.writeAsBytes([
      0xD0,
      0xCF,
      0x11,
      0xE0,
      0xA1,
      0xB1,
      0x1A,
      0xE1,
    ]);
    await convertedFile.writeAsBytes(ZipEncoder().encode(_minimalPptx()));
    addTearDown(() {
      if (pptFile.existsSync()) pptFile.deleteSync();
      if (convertedFile.existsSync()) convertedFile.deleteSync();
    });

    final engine = _FakeOfficeEngine(
      legacyPptConverter: _FakeLegacyPptConverter(convertedFile.path),
    );
    final presentation = await HybridPresentationBackend(
      officeEngine: engine,
    ).open(pptFile.path);

    expect(presentation.filePath, pptFile.path);
    expect(presentation.slides, hasLength(1));
    expect(engine.ensureAvailableCalls, 1);
  });
}

Archive _minimalPptx() {
  return Archive()
    ..addFile(
      ArchiveFile.string('ppt/presentation.xml', '''
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:sldSz cx="9144000" cy="5143500"/>
  <p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst>
</p:presentation>
'''),
    )
    ..addFile(
      ArchiveFile.string('ppt/_rels/presentation.xml.rels', '''
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
</Relationships>
'''),
    )
    ..addFile(
      ArchiveFile.string('ppt/slides/slide1.xml', '''
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld><p:spTree/></p:cSld>
</p:sld>
'''),
    );
}

class _FakeOfficeEngine implements OfficeCompatibilityEngine {
  _FakeOfficeEngine({LegacyPptConverter? legacyPptConverter})
    : _legacyPptConverter = legacyPptConverter ?? _FakeLegacyPptConverter('');

  final LegacyPptConverter _legacyPptConverter;
  int ensureAvailableCalls = 0;

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<void> ensureAvailable() async {
    ensureAvailableCalls++;
  }

  @override
  Future<LegacyPptConversion> convertLegacyPpt(String pptPath) {
    return _legacyPptConverter.convert(pptPath);
  }
}

class _FakeLegacyPptConverter extends LegacyPptConverter {
  _FakeLegacyPptConverter(this.convertedPptxPath);

  final String convertedPptxPath;

  @override
  Future<LegacyPptConversion> convert(String pptPath) async {
    return LegacyPptConversion(convertedPptxPath);
  }
}
