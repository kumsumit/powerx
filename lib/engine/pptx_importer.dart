import 'dart:io';
import 'dart:ui';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:uuid/uuid.dart';
import '../models/presentation.dart';
import '../models/elements.dart';
import '../models/text_styles.dart';
import '../models/slide_master.dart';
import '../models/table.dart';
import '../models/chart.dart';
import '../models/animation.dart';
import '../models/theme.dart';
import 'openxml_utils.dart';

class PptxImporter {
  final _uuid = const Uuid();

  Future<Presentation> import(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Build relationship map
    final relsMap = _buildRelsMap(archive);

    // Parse presentation.xml
    final presEntry = archive.findFile('ppt/presentation.xml');
    if (presEntry == null) throw Exception('Invalid PPTX: no presentation.xml');

    final presDoc = XmlDocument.parse(String.fromCharCodes(presEntry.content));
    final presRoot = presDoc.rootElement;

    // Parse slide size
    final sldSz = OpenXmlUtils.findChild(presRoot, 'sldSz');
    final cx = OpenXmlUtils.attr(sldSz, 'cx');
    final cy = OpenXmlUtils.attr(sldSz, 'cy');
    final slideSize = Size(
      cx != null ? OpenXmlUtils.parseEmu(cx).toDouble() : 960,
      cy != null ? OpenXmlUtils.parseEmu(cy).toDouble() : 540,
    );

    // Parse slide list
    final slideIdList = OpenXmlUtils.findChild(presRoot, 'sldIdLst');
    final slideIds = slideIdList != null
        ? OpenXmlUtils.findChildren(slideIdList, 'sldId')
        : <XmlElement>[];

    // Parse themes
    final themes = _parseThemes(archive);

    // Parse masters
    final masters = _parseMasters(archive, relsMap, themes);

    // Parse layouts
    final layouts = _parseLayouts(archive, relsMap);

    // Parse slides
    final slides = <Slide>[];
    for (var i = 0; i < slideIds.length; i++) {
      final sldId = slideIds[i];
      final relId = OpenXmlUtils.attr(sldId, 'id', nsPrefix: 'r');
      if (relId == null) continue;

      final slidePath = relsMap['ppt/_rels/presentation.xml.rels']?[relId];
      if (slidePath == null) continue;

      final slide = await _parseSlide(archive, slidePath, relsMap, i + 1);
      slides.add(slide);
    }

    return Presentation(
      id: _uuid.v4(),
      title: 'Imported Presentation',
      slides: slides,
      masters: masters,
      layouts: layouts,
      theme: themes.isNotEmpty ? themes.first : const PresentationTheme(),
      settings: PresentationSettings(slideSize: slideSize),
      filePath: filePath,
    );
  }

  Map<String, Map<String, String>> _buildRelsMap(Archive archive) {
    final map = <String, Map<String, String>>{};
    for (final file in archive.files) {
      if (file.name.endsWith('.rels')) {
        final doc = XmlDocument.parse(String.fromCharCodes(file.content));
        final rels = <String, String>{};
        for (final rel in doc.rootElement.childElements) {
          if (rel.name.local == 'Relationship') {
            final id = OpenXmlUtils.attr(rel, 'Id');
            final target = OpenXmlUtils.attr(rel, 'Target');
            if (id != null && target != null) {
              rels[id] = target;
            }
          }
        }
        map[file.name] = rels;
      }
    }
    return map;
  }

  List<PresentationTheme> _parseThemes(Archive archive) {
    final themes = <PresentationTheme>[];
    for (final file in archive.files) {
      if (file.name.startsWith('ppt/theme/theme') &&
          file.name.endsWith('.xml')) {
        final doc = XmlDocument.parse(String.fromCharCodes(file.content));
        final themeRoot = doc.rootElement;

        final clrScheme = OpenXmlUtils.findChild(themeRoot, 'clrScheme');
        final fontScheme = OpenXmlUtils.findChild(themeRoot, 'fontScheme');

        Color? parseSchemeClr(String name) {
          final el = OpenXmlUtils.findChild(clrScheme, name);
          return OpenXmlUtils.parseColor(
            OpenXmlUtils.findChild(el, 'srgbClr') ??
                OpenXmlUtils.findChild(el, 'sysClr'),
          );
        }

        final colors = ColorScheme(
          text1: parseSchemeClr('dk1') ?? const Color(0xFF000000),
          background1: parseSchemeClr('lt1') ?? const Color(0xFFFFFFFF),
          accent1: parseSchemeClr('accent1') ?? const Color(0xFF4472C4),
          accent2: parseSchemeClr('accent2') ?? const Color(0xFFED7D31),
          accent3: parseSchemeClr('accent3') ?? const Color(0xFFA5A5A5),
          accent4: parseSchemeClr('accent4') ?? const Color(0xFFFFC000),
          accent5: parseSchemeClr('accent5') ?? const Color(0xFF5B9BD5),
          accent6: parseSchemeClr('accent6') ?? const Color(0xFF70AD47),
          hyperlink: parseSchemeClr('hlink') ?? const Color(0xFF0563C1),
          followedHyperlink:
              parseSchemeClr('folHlink') ?? const Color(0xFF954F72),
        );

        String? getFont(String type) {
          final el = OpenXmlUtils.findChild(fontScheme, type);
          final latin = OpenXmlUtils.findChild(el, 'latin');
          return OpenXmlUtils.attr(latin, 'typeface');
        }

        final fonts = FontScheme(
          majorFont: getFont('majorFont') ?? 'Calibri',
          minorFont: getFont('minorFont') ?? 'Calibri',
        );

        themes.add(
          PresentationTheme(
            name: OpenXmlUtils.attr(clrScheme, 'name') ?? 'Office',
            colors: colors,
            fonts: fonts,
          ),
        );
      }
    }
    return themes;
  }

  List<SlideMaster> _parseMasters(
    Archive archive,
    Map<String, Map<String, String>> relsMap,
    List<PresentationTheme> themes,
  ) {
    final masters = <SlideMaster>[];
    // Master parsing stub - full implementation would parse slideMaster1.xml etc.
    return masters;
  }

  List<SlideLayout> _parseLayouts(
    Archive archive,
    Map<String, Map<String, String>> relsMap,
  ) {
    final layouts = <SlideLayout>[];
    // Layout parsing stub
    return layouts;
  }

  Future<Slide> _parseSlide(
    Archive archive,
    String slidePath,
    Map<String, Map<String, String>> relsMap,
    int slideNumber,
  ) async {
    final entry = archive.findFile(slidePath);
    if (entry == null) return Slide(id: _uuid.v4(), slideNumber: slideNumber);

    final doc = XmlDocument.parse(String.fromCharCodes(entry.content));
    final sldRoot = doc.rootElement;
    final cSld = OpenXmlUtils.findChild(sldRoot, 'cSld');
    if (cSld == null) return Slide(id: _uuid.v4(), slideNumber: slideNumber);

    final spTree = OpenXmlUtils.findChild(cSld, 'spTree');
    if (spTree == null) return Slide(id: _uuid.v4(), slideNumber: slideNumber);

    final elements = <SlideElement>[];
    int zIndex = 0;

    for (final child in spTree.childElements) {
      SlideElement? el;
      switch (child.name.local) {
        case 'sp':
          el = _parseShape(child);
          break;
        case 'pic':
          el = _parsePicture(child, archive, slidePath, relsMap);
          break;
        case 'graphicFrame':
          el = _parseGraphicFrame(child, archive, slidePath, relsMap);
          break;
      }
      if (el != null) {
        elements.add(el.copyWith(zIndex: zIndex++));
      }
    }

    // Parse background
    Color? bgColor;
    final bg = OpenXmlUtils.findChild(cSld, 'bg');
    if (bg != null) {
      final solidFill = OpenXmlUtils.findChild(bg, 'solidFill');
      if (solidFill != null) {
        bgColor = OpenXmlUtils.parseColor(
          OpenXmlUtils.findChild(solidFill, 'srgbClr') ??
              OpenXmlUtils.findChild(solidFill, 'schemeClr'),
        );
      }
    }

    // Parse transition
    final transition = OpenXmlUtils.findChild(sldRoot, 'transition');
    SlideTransition? slideTransition;
    if (transition != null) {
      final type = OpenXmlUtils.attr(transition, 'type');
      final dur = OpenXmlUtils.attr(transition, 'dur');
      slideTransition = SlideTransition(
        type: _parseTransitionType(type),
        duration: dur != null
            ? Duration(milliseconds: int.parse(dur))
            : const Duration(milliseconds: 2000),
      );
    }

    return Slide(
      id: _uuid.v4(),
      elements: elements,
      backgroundColorOverride: bgColor,
      transition: slideTransition ?? const SlideTransition(),
      slideNumber: slideNumber,
    );
  }

  SlideElement? _parseShape(XmlElement sp) {
    final nvSpPr = OpenXmlUtils.findChild(sp, 'nvSpPr');
    final cNvPr = nvSpPr != null
        ? OpenXmlUtils.findChild(nvSpPr, 'cNvPr')
        : null;
    final name = cNvPr != null ? OpenXmlUtils.attr(cNvPr, 'name') : null;
    final id = OpenXmlUtils.attr(cNvPr, 'id') ?? _uuid.v4();

    final spPr = OpenXmlUtils.findChild(sp, 'spPr');
    if (spPr == null) return null;

    final xfrm = OpenXmlUtils.findChild(spPr, 'xfrm');
    final off = xfrm != null ? OpenXmlUtils.findChild(xfrm, 'off') : null;
    final ext = xfrm != null ? OpenXmlUtils.findChild(xfrm, 'ext') : null;

    final x = off != null
        ? OpenXmlUtils.parseEmu(OpenXmlUtils.attr(off, 'x')).toDouble()
        : 0.0;
    final y = off != null
        ? OpenXmlUtils.parseEmu(OpenXmlUtils.attr(off, 'y')).toDouble()
        : 0.0;
    final cx = ext != null
        ? OpenXmlUtils.parseEmu(OpenXmlUtils.attr(ext, 'cx')).toDouble()
        : 100.0;
    final cy = ext != null
        ? OpenXmlUtils.parseEmu(OpenXmlUtils.attr(ext, 'cy')).toDouble()
        : 100.0;

    // Parse fill
    final solidFill = OpenXmlUtils.findChild(spPr, 'solidFill');
    final fillColor =
        OpenXmlUtils.parseColor(
          OpenXmlUtils.findChild(solidFill, 'srgbClr') ??
              OpenXmlUtils.findChild(solidFill, 'schemeClr'),
        ) ??
        const Color(0xFF4472C4);

    // Parse line
    final ln = OpenXmlUtils.findChild(spPr, 'ln');
    Color? strokeColor;
    double strokeWidth = 0;
    if (ln != null) {
      final w = OpenXmlUtils.attr(ln, 'w');
      if (w != null) strokeWidth = int.parse(w) / 12700; // EMU to pt approx
      final lnSolidFill = OpenXmlUtils.findChild(ln, 'solidFill');
      strokeColor = OpenXmlUtils.parseColor(
        OpenXmlUtils.findChild(lnSolidFill, 'srgbClr') ??
            OpenXmlUtils.findChild(lnSolidFill, 'schemeClr'),
      );
    }

    // Parse geometry
    final prstGeom = OpenXmlUtils.findChild(spPr, 'prstGeom');
    final prst = prstGeom != null ? OpenXmlUtils.attr(prstGeom, 'prst') : null;
    ShapeType shapeType = ShapeType.rectangle;
    if (prst == 'ellipse')
      shapeType = ShapeType.circle;
    else if (prst == 'roundRect')
      shapeType = ShapeType.roundedRectangle;
    else if (prst == 'triangle')
      shapeType = ShapeType.triangle;
    else if (prst == 'diamond')
      shapeType = ShapeType.diamond;
    else if (prst == 'pentagon')
      shapeType = ShapeType.pentagon;
    else if (prst == 'hexagon')
      shapeType = ShapeType.hexagon;
    else if (prst == 'star5')
      shapeType = ShapeType.star;
    else if (prst == 'arrow')
      shapeType = ShapeType.arrow;

    // Parse text
    final txBody = OpenXmlUtils.findChild(sp, 'txBody');
    if (txBody != null) {
      final paragraphs = _parseTextBody(txBody);
      return TextElement(
        id: id,
        name: name,
        position: Offset(x, y),
        size: Size(cx, cy),
        paragraphs: paragraphs,
        fillColor: fillColor,
        borderWidth: strokeWidth > 0 ? strokeWidth : null,
        borderColor: strokeColor,
        zIndex: 0,
      );
    }

    return ShapeElement(
      id: id,
      name: name,
      position: Offset(x, y),
      size: Size(cx, cy),
      fillColor: fillColor,
      strokeColor: strokeColor ?? const Color(0xFF000000),
      strokeWidth: strokeWidth,
      shapeType: shapeType,
      zIndex: 0,
    );
  }

  List<RichParagraph> _parseTextBody(XmlElement txBody) {
    final paragraphs = <RichParagraph>[];
    final pElements = OpenXmlUtils.findChildren(txBody, 'p');

    for (final p in pElements) {
      final runs = <TextRun>[];
      final pPr = OpenXmlUtils.findChild(p, 'pPr');

      // Parse paragraph style
      TextAlign align = TextAlign.left;
      if (pPr != null) {
        final algn = OpenXmlUtils.attr(pPr, 'algn');
        if (algn == 'ctr')
          align = TextAlign.center;
        else if (algn == 'r')
          align = TextAlign.right;
        else if (algn == 'just')
          align = TextAlign.justify;
      }

      // Parse runs
      for (final r in OpenXmlUtils.findChildren(p, 'r')) {
        final t = OpenXmlUtils.findChild(r, 't');
        final text = t?.innerText ?? '';

        final rPr = OpenXmlUtils.findChild(r, 'rPr');
        String font = 'Calibri';
        double fontSize = 18;
        Color color = const Color(0xFF000000);
        bool bold = false;
        bool italic = false;
        bool underline = false;
        bool strikethrough = false;

        if (rPr != null) {
          final sz = OpenXmlUtils.attr(rPr, 'sz');
          if (sz != null) fontSize = int.parse(sz) / 100;

          final b = OpenXmlUtils.attr(rPr, 'b');
          if (b != null) bold = int.parse(b) > 0;

          final i = OpenXmlUtils.attr(rPr, 'i');
          if (i != null) italic = int.parse(i) > 0;

          final u = OpenXmlUtils.attr(rPr, 'u');
          if (u != null && u != 'none') underline = true;

          final strike = OpenXmlUtils.attr(rPr, 'strike');
          if (strike != null && strike != 'noStrike') strikethrough = true;

          final latin = OpenXmlUtils.findChild(rPr, 'latin');
          if (latin != null) {
            final typeface = OpenXmlUtils.attr(latin, 'typeface');
            if (typeface != null && !typeface.startsWith('+')) font = typeface;
          }

          final solidFill = OpenXmlUtils.findChild(rPr, 'solidFill');
          final parsedColor = OpenXmlUtils.parseColor(
            OpenXmlUtils.findChild(solidFill, 'srgbClr') ??
                OpenXmlUtils.findChild(solidFill, 'schemeClr'),
          );
          if (parsedColor != null) color = parsedColor;
        }

        runs.add(
          TextRun(
            text: text,
            fontFamily: font,
            fontSize: fontSize,
            color: color,
            bold: bold,
            italic: italic,
            underline: underline,
            strikethrough: strikethrough,
          ),
        );
      }

      // Handle endParaRPr for empty paragraphs
      if (runs.isEmpty) {
        runs.add(const TextRun(text: ''));
      }

      paragraphs.add(
        RichParagraph(
          runs: runs,
          style: ParagraphStyle(alignment: align),
        ),
      );
    }

    return paragraphs.isEmpty ? [const RichParagraph()] : paragraphs;
  }

  SlideElement? _parsePicture(
    XmlElement pic,
    Archive archive,
    String slidePath,
    Map<String, Map<String, String>> relsMap,
  ) {
    final nvPicPr = OpenXmlUtils.findChild(pic, 'nvPicPr');
    final cNvPr = nvPicPr != null
        ? OpenXmlUtils.findChild(nvPicPr, 'cNvPr')
        : null;
    final id = OpenXmlUtils.attr(cNvPr, 'id') ?? _uuid.v4();
    final name = cNvPr != null ? OpenXmlUtils.attr(cNvPr, 'name') : null;

    final spPr = OpenXmlUtils.findChild(pic, 'spPr');
    if (spPr == null) return null;

    final xfrm = OpenXmlUtils.findChild(spPr, 'xfrm');
    final off = xfrm != null ? OpenXmlUtils.findChild(xfrm, 'off') : null;
    final ext = xfrm != null ? OpenXmlUtils.findChild(xfrm, 'ext') : null;

    final x = off != null
        ? OpenXmlUtils.parseEmu(OpenXmlUtils.attr(off, 'x')).toDouble()
        : 0.0;
    final y = off != null
        ? OpenXmlUtils.parseEmu(OpenXmlUtils.attr(off, 'y')).toDouble()
        : 0.0;
    final cx = ext != null
        ? OpenXmlUtils.parseEmu(OpenXmlUtils.attr(ext, 'cx')).toDouble()
        : 100.0;
    final cy = ext != null
        ? OpenXmlUtils.parseEmu(OpenXmlUtils.attr(ext, 'cy')).toDouble()
        : 100.0;

    final blipFill = OpenXmlUtils.findChild(pic, 'blipFill');
    final blip = blipFill != null
        ? OpenXmlUtils.findChild(blipFill, 'blip')
        : null;
    final embedId = blip != null
        ? OpenXmlUtils.attr(blip, 'embed', nsPrefix: 'r')
        : null;

    String? imagePath;
    if (embedId != null) {
      final slideRelsPath = slidePath.replaceAll('.xml', '.xml.rels');
      final slideRelsPath2 = 'ppt/' + slideRelsPath.split('/').last;
      final target =
          relsMap[slideRelsPath2]?[embedId] ??
          relsMap['ppt/slides/_rels/${slidePath.split('/').last}.rels']?[embedId];
      if (target != null) {
        imagePath = 'ppt/media/' + target.split('/').last;
      }
    }

    return ImageElement(
      id: id,
      name: name,
      position: Offset(x, y),
      size: Size(cx, cy),
      imagePath: imagePath ?? '',
      zIndex: 0,
    );
  }

  SlideElement? _parseGraphicFrame(
    XmlElement graphicFrame,
    Archive archive,
    String slidePath,
    Map<String, Map<String, String>> relsMap,
  ) {
    final spPr = OpenXmlUtils.findChild(graphicFrame, 'spPr');
    final xfrm = spPr != null ? OpenXmlUtils.findChild(spPr, 'xfrm') : null;
    final off = xfrm != null ? OpenXmlUtils.findChild(xfrm, 'off') : null;
    final ext = xfrm != null ? OpenXmlUtils.findChild(xfrm, 'ext') : null;

    final x = off != null
        ? OpenXmlUtils.parseEmu(OpenXmlUtils.attr(off, 'x')).toDouble()
        : 0.0;
    final y = off != null
        ? OpenXmlUtils.parseEmu(OpenXmlUtils.attr(off, 'y')).toDouble()
        : 0.0;
    final cx = ext != null
        ? OpenXmlUtils.parseEmu(OpenXmlUtils.attr(ext, 'cx')).toDouble()
        : 100.0;
    final cy = ext != null
        ? OpenXmlUtils.parseEmu(OpenXmlUtils.attr(ext, 'cy')).toDouble()
        : 100.0;

    final graphic = OpenXmlUtils.findChild(graphicFrame, 'graphic');
    final graphicData = graphic != null
        ? OpenXmlUtils.findChild(graphic, 'graphicData')
        : null;
    if (graphicData == null) return null;

    final uri = OpenXmlUtils.attr(graphicData, 'uri');

    // Table
    if (uri == 'http://schemas.openxmlformats.org/drawingml/2006/table') {
      final tbl = OpenXmlUtils.findChild(graphicData, 'tbl');
      if (tbl != null) {
        return _parseTable(tbl, x, y, cx, cy);
      }
    }

    // Chart
    if (uri == 'http://schemas.openxmlformats.org/drawingml/2006/chart') {
      final chart = OpenXmlUtils.findChild(graphicData, 'chart');
      if (chart != null) {
        return ChartElement(
          id: _uuid.v4(),
          position: Offset(x, y),
          size: Size(cx, cy),
          data: const ChartData(),
          zIndex: 0,
        );
      }
    }

    return null;
  }

  TableElement _parseTable(
    XmlElement tbl,
    double x,
    double y,
    double cx,
    double cy,
  ) {
    final rows = <TableRow>[];
    final columns = <TableColumn>[];
    final cells = <TableCell>[];

    // Parse grid columns
    final tblGrid = OpenXmlUtils.findChild(tbl, 'tblGrid');
    if (tblGrid != null) {
      for (final gridCol in OpenXmlUtils.findChildren(tblGrid, 'gridCol')) {
        final w = OpenXmlUtils.attr(gridCol, 'w');
        columns.add(
          TableColumn(
            id: _uuid.v4(),
            width: w != null ? OpenXmlUtils.parseEmu(w).toDouble() : 100,
          ),
        );
      }
    }

    // Parse rows
    for (final tr in OpenXmlUtils.findChildren(tbl, 'tr')) {
      final h = OpenXmlUtils.attr(tr, 'h');
      final rowId = _uuid.v4();
      rows.add(
        TableRow(
          id: rowId,
          height: h != null ? OpenXmlUtils.parseEmu(h).toDouble() : 30,
        ),
      );

      int colIdx = 0;
      for (final tc in OpenXmlUtils.findChildren(tr, 'tc')) {
        final tcPr = OpenXmlUtils.findChild(tc, 'tcPr');
        final gridSpan = tcPr != null
            ? OpenXmlUtils.attr(tcPr, 'gridSpan')
            : null;
        final rowSpan = tcPr != null
            ? OpenXmlUtils.attr(tcPr, 'rowSpan')
            : null;

        final txBody = OpenXmlUtils.findChild(tc, 'txBody');
        final paragraphs = txBody != null
            ? _parseTextBody(txBody)
            : <RichParagraph>[];

        Color? fillColor;
        if (tcPr != null) {
          final solidFill = OpenXmlUtils.findChild(tcPr, 'solidFill');
          fillColor = OpenXmlUtils.parseColor(
            OpenXmlUtils.findChild(solidFill, 'srgbClr') ??
                OpenXmlUtils.findChild(solidFill, 'schemeClr'),
          );
        }

        if (colIdx < columns.length) {
          cells.add(
            TableCell(
              id: _uuid.v4(),
              rowId: rowId,
              colId: columns[colIdx].id,
              colSpan: gridSpan != null ? int.parse(gridSpan) : 1,
              rowSpan: rowSpan != null ? int.parse(rowSpan) : 1,
              paragraphs: paragraphs,
              fillColor: fillColor,
            ),
          );
        }
        colIdx++;
      }
    }

    return TableElement(
      id: _uuid.v4(),
      position: Offset(x, y),
      size: Size(cx, cy),
      rows: rows,
      columns: columns,
      cells: cells,
      zIndex: 0,
    );
  }

  TransitionType _parseTransitionType(String? type) {
    switch (type) {
      case 'fade':
        return TransitionType.fade;
      case 'push':
        return TransitionType.push;
      case 'wipe':
        return TransitionType.wipe;
      case 'split':
        return TransitionType.split;
      case 'reveal':
        return TransitionType.reveal;
      case 'random':
        return TransitionType.randomBars;
      case 'cover':
        return TransitionType.cover;
      case 'uncover':
        return TransitionType.uncover;
      case 'clock':
        return TransitionType.clock;
      case 'cube':
        return TransitionType.cube;
      case 'flip':
        return TransitionType.flip;
      case 'ripple':
        return TransitionType.ripple;
      default:
        return TransitionType.none;
    }
  }
}
