import 'dart:io';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerx/engine/pptx_importer.dart';
import 'package:powerx/models/elements.dart';

void main() {
  test('imports slides through relative presentation relationships', () async {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string('ppt/presentation.xml', '''
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:sldSz cx="9144000" cy="5143500"/>
  <p:sldIdLst>
    <p:sldId id="256" r:id="rId1"/>
  </p:sldIdLst>
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
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr/>
      <p:grpSpPr/>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="2" name="Title"/></p:nvSpPr>
        <p:spPr>
          <a:xfrm>
            <a:off x="914400" y="914400"/>
            <a:ext cx="1828800" cy="914400"/>
          </a:xfrm>
          <a:prstGeom prst="rect"/>
        </p:spPr>
        <p:txBody>
          <a:bodyPr/>
          <a:p><a:r><a:t>Hello</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
      <p:pic>
        <p:nvPicPr><p:cNvPr id="3" name="Picture 1"/></p:nvPicPr>
        <p:blipFill><a:blip r:embed="rId2"/></p:blipFill>
        <p:spPr>
          <a:xfrm>
            <a:off x="0" y="0"/>
            <a:ext cx="914400" cy="914400"/>
          </a:xfrm>
        </p:spPr>
      </p:pic>
    </p:spTree>
  </p:cSld>
  <p:transition dur="123"/>
</p:sld>
'''),
      )
      ..addFile(
        ArchiveFile.string('ppt/slides/_rels/slide1.xml.rels', '''
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image1.png"/>
</Relationships>
'''),
      )
      ..addFile(ArchiveFile('ppt/media/image1.png', 4, [1, 2, 3, 4]));

    final file = File('${Directory.systemTemp.path}/powerx_import_test.pptx');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });

    final presentation = await PptxImporter().import(file.path);

    expect(presentation.slides, hasLength(1));
    expect(presentation.activeSlide.transition.duration.inMilliseconds, 123);
    final image = presentation.activeSlide.elements
        .whereType<ImageElement>()
        .single;
    expect(image.imagePath, isNot('ppt/media/image1.png'));
    expect(File(image.imagePath).existsSync(), isTrue);
  });

  test(
    'resolves the slide -> layout -> master -> theme inheritance chain',
    () async {
      final archive = Archive()
        ..addFile(
          ArchiveFile.string('ppt/presentation.xml', '''
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:sldSz cx="9144000" cy="6858000"/>
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
        // Theme: accent1 is pure red, fonts are distinctive.
        ..addFile(
          ArchiveFile.string('ppt/theme/theme1.xml', '''
<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <a:themeElements>
    <a:clrScheme name="Custom">
      <a:dk1><a:srgbClr val="111111"/></a:dk1>
      <a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>
      <a:accent1><a:srgbClr val="FF0000"/></a:accent1>
      <a:accent2><a:srgbClr val="00FF00"/></a:accent2>
      <a:accent3><a:srgbClr val="0000FF"/></a:accent3>
      <a:accent4><a:srgbClr val="FFFF00"/></a:accent4>
      <a:accent5><a:srgbClr val="00FFFF"/></a:accent5>
      <a:accent6><a:srgbClr val="FF00FF"/></a:accent6>
      <a:hlink><a:srgbClr val="0000EE"/></a:hlink>
      <a:folHlink><a:srgbClr val="551A8B"/></a:folHlink>
    </a:clrScheme>
    <a:fontScheme name="Custom">
      <a:majorFont><a:latin typeface="Major Font"/></a:majorFont>
      <a:minorFont><a:latin typeface="Minor Font"/></a:minorFont>
    </a:fontScheme>
  </a:themeElements>
</a:theme>
'''),
        )
        // Master: title style is 44pt + major font; references the theme.
        ..addFile(
          ArchiveFile.string('ppt/slideMasters/slideMaster1.xml', '''
<p:sldMaster xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <p:cSld><p:spTree/></p:cSld>
  <p:txStyles>
    <p:titleStyle>
      <a:lvl1pPr algn="ctr"><a:defRPr sz="4400" b="1"><a:latin typeface="+mj-lt"/></a:defRPr></a:lvl1pPr>
    </p:titleStyle>
    <p:bodyStyle>
      <a:lvl1pPr><a:defRPr sz="2800"/></a:lvl1pPr>
    </p:bodyStyle>
    <p:otherStyle/>
  </p:txStyles>
</p:sldMaster>
'''),
        )
        ..addFile(
          ArchiveFile.string(
            'ppt/slideMasters/_rels/slideMaster1.xml.rels',
            '''
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rIdT" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
</Relationships>
''',
          ),
        )
        // Layout: the title placeholder's geometry lives here, not on the slide.
        ..addFile(
          ArchiveFile.string('ppt/slideLayouts/slideLayout1.xml', '''
<p:sldLayout xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <p:cSld><p:spTree>
    <p:sp>
      <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr/><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
      <p:spPr><a:xfrm><a:off x="914400" y="457200"/><a:ext cx="7315200" cy="1143000"/></a:xfrm></p:spPr>
    </p:sp>
  </p:spTree></p:cSld>
</p:sldLayout>
'''),
        )
        ..addFile(
          ArchiveFile.string(
            'ppt/slideLayouts/_rels/slideLayout1.xml.rels',
            '''
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rIdM" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideMasters/slideMaster1.xml"/>
</Relationships>
''',
          ),
        )
        // Slide: title has NO xfrm (inherits layout), a shape filled with
        // schemeClr accent1, and a 1:1 group wrapping a child shape.
        ..addFile(
          ArchiveFile.string('ppt/slides/slide1.xml', '''
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <p:cSld><p:spTree>
    <p:sp>
      <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr/><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
      <p:spPr/>
      <p:txBody><a:bodyPr/><a:p><a:r><a:t>Inherited Title</a:t></a:r></a:p></p:txBody>
    </p:sp>
    <p:sp>
      <p:nvSpPr><p:cNvPr id="3" name="Accent"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
      <p:spPr>
        <a:xfrm><a:off x="0" y="0"/><a:ext cx="914400" cy="914400"/></a:xfrm>
        <a:prstGeom prst="rect"/>
        <a:solidFill><a:schemeClr val="accent1"/></a:solidFill>
      </p:spPr>
    </p:sp>
    <p:grpSp>
      <p:grpSpPr><a:xfrm>
        <a:off x="1828800" y="1828800"/><a:ext cx="914400" cy="914400"/>
        <a:chOff x="0" y="0"/><a:chExt cx="914400" cy="914400"/>
      </a:xfrm></p:grpSpPr>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="4" name="Child"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="457200" cy="457200"/></a:xfrm><a:prstGeom prst="ellipse"/></p:spPr>
      </p:sp>
    </p:grpSp>
  </p:spTree></p:cSld>
</p:sld>
'''),
        )
        ..addFile(
          ArchiveFile.string('ppt/slides/_rels/slide1.xml.rels', '''
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rIdL" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
</Relationships>
'''),
        );

      final file = File(
        '${Directory.systemTemp.path}/powerx_inherit_test.pptx',
      );
      await file.writeAsBytes(ZipEncoder().encode(archive));
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });

      final pres = await PptxImporter().import(file.path);
      final elements = pres.activeSlide.elements;

      // Theme parsed onto the presentation.
      expect(pres.theme.colors.accent1, const Color(0xFFFF0000));
      expect(pres.theme.fonts.majorFont, 'Major Font');

      // Title inherited geometry from the layout (914400 EMU -> 96 px @96dpi).
      final title = elements.whereType<TextElement>().single;
      expect(title.position.dx, closeTo(96, 0.01));
      expect(title.position.dy, closeTo(48, 0.01));
      expect(title.size.width, closeTo(768, 0.01));

      // Title run inherited size (44pt) + major font from the master txStyles.
      final run = title.paragraphs.first.runs.first;
      expect(run.text, 'Inherited Title');
      expect(run.fontSize, 44);
      expect(run.bold, isTrue);
      expect(run.fontFamily, 'Major Font');

      // schemeClr accent1 resolved through the theme, not a hardcoded default.
      final accent = elements.whereType<ShapeElement>().firstWhere(
        (s) => s.name == 'Accent',
      );
      expect(accent.fillColor, const Color(0xFFFF0000));

      // Group parsed with its child mapped into absolute slide coordinates.
      final group = elements.whereType<GroupElement>().single;
      expect(group.children, hasLength(1));
      expect(group.children.first.size.width, closeTo(48, 0.01));
    },
  );

  test('returns a blank slide when a deck has no slide ids', () async {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string('ppt/presentation.xml', '''
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldSz cx="9144000" cy="5143500"/>
</p:presentation>
'''),
      );

    final file = File(
      '${Directory.systemTemp.path}/powerx_empty_import_test.pptx',
    );
    await file.writeAsBytes(ZipEncoder().encode(archive));
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });

    final presentation = await PptxImporter().import(file.path);

    expect(presentation.slides, hasLength(1));
    expect(presentation.activeSlide.elements, isEmpty);
  });
}
