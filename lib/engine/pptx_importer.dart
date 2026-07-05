import 'dart:io';
import 'dart:ui';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:uuid/uuid.dart';
import '../models/presentation.dart';
import '../models/slide_master.dart';
import '../models/elements.dart';
import '../models/text_styles.dart';
import '../models/table.dart';
import '../models/chart.dart';
import '../models/animation.dart';
import '../models/theme.dart';
import 'openxml_utils.dart';

class LegacyPptConversion {
  const LegacyPptConversion(this.pptxPath, {this.cleanup});

  final String pptxPath;
  final Future<void> Function()? cleanup;

  Future<void> dispose() async {
    await cleanup?.call();
  }
}

class LegacyPptConverter {
  const LegacyPptConverter({this.executableCandidates});

  final List<String>? executableCandidates;

  List<String> executableCandidatesForPlatform() =>
      executableCandidates ?? _defaultExecutableCandidates();

  Future<LegacyPptConversion> convert(String pptPath) async {
    final outDir = await Directory.systemTemp.createTemp('powerx_ppt_');
    final candidates = executableCandidatesForPlatform();

    Object? lastError;
    for (final executable in candidates) {
      try {
        final result = await Process.run(executable, [
          '--headless',
          '--convert-to',
          'pptx',
          '--outdir',
          outDir.path,
          pptPath,
        ]);
        if (result.exitCode == 0) {
          final pptxPath = _convertedPathFor(outDir.path, pptPath);
          if (await File(pptxPath).exists()) {
            return LegacyPptConversion(
              pptxPath,
              cleanup: () async {
                if (await outDir.exists()) {
                  await outDir.delete(recursive: true);
                }
              },
            );
          }
          lastError = 'converted file was not created';
        } else {
          lastError = '${result.stderr}${result.stdout}';
        }
      } on ProcessException catch (e) {
        lastError = e;
      }
    }

    if (await outDir.exists()) {
      await outDir.delete(recursive: true);
    }
    throw Exception(
      'Legacy .ppt import requires LibreOffice or OpenOffice to be installed. '
      'Conversion failed: $lastError',
    );
  }

  List<String> _defaultExecutableCandidates() {
    if (Platform.isMacOS) {
      return const [
        '/Applications/LibreOffice.app/Contents/MacOS/soffice',
        '/Applications/OpenOffice.app/Contents/MacOS/soffice',
        'soffice',
        'libreoffice',
      ];
    }
    if (Platform.isWindows) {
      return const [
        r'C:\Program Files\LibreOffice\program\soffice.exe',
        r'C:\Program Files (x86)\LibreOffice\program\soffice.exe',
        'soffice.exe',
        'soffice',
      ];
    }
    return const ['libreoffice', 'soffice'];
  }

  String _convertedPathFor(String outDir, String pptPath) {
    final fileName = pptPath.split(Platform.pathSeparator).last;
    final dot = fileName.lastIndexOf('.');
    final stem = dot == -1 ? fileName : fileName.substring(0, dot);
    return '$outDir${Platform.pathSeparator}$stem.pptx';
  }
}

/// Imports `.pptx` files by resolving the PresentationML inheritance chain the
/// way PowerPoint does. Legacy binary `.ppt` files are converted to `.pptx`
/// first, then parsed through the same OOXML pipeline.
class PptxImporter {
  PptxImporter({LegacyPptConverter? legacyPptConverter})
    : _legacyPptConverter = legacyPptConverter ?? const LegacyPptConverter();

  final _uuid = const Uuid();
  final LegacyPptConverter _legacyPptConverter;

  late Archive _archive;
  late Map<String, Map<String, String>> _relsMap;
  late Map<String, String> _mediaFiles;
  final Map<String, _Master> _masters = {};
  final Map<String, _Layout> _layouts = {};

  static const _defaultScheme = ColorScheme.office();
  static const _defaultFonts = FontScheme();

  Future<Presentation> import(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    if (_isLegacyPpt(bytes)) {
      if (Platform.isAndroid) {
        throw Exception(
          'Office Compatibility Engine is required for legacy .ppt import on Android.',
        );
      }
      final conversion = await _legacyPptConverter.convert(filePath);
      try {
        return importConvertedLegacyPpt(
          conversion.pptxPath,
          displayFilePath: filePath,
        );
      } finally {
        await conversion.dispose();
      }
    }
    return _importPptxBytes(bytes, displayFilePath: filePath);
  }

  Future<Presentation> importConvertedLegacyPpt(
    String pptxPath, {
    required String displayFilePath,
  }) async {
    final convertedBytes = await File(pptxPath).readAsBytes();
    return _importPptxBytes(convertedBytes, displayFilePath: displayFilePath);
  }

  Future<Presentation> _importPptxBytes(
    List<int> bytes, {
    required String displayFilePath,
  }) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    _archive = archive;

    _relsMap = _buildRelsMap(archive);
    _mediaFiles = await _extractMediaFiles(archive);

    final presEntry = archive.findFile('ppt/presentation.xml');
    if (presEntry == null) throw Exception('Invalid PPTX: no presentation.xml');

    final presDoc = XmlDocument.parse(String.fromCharCodes(presEntry.content));
    final presRoot = presDoc.rootElement;

    final sldSz = OpenXmlUtils.findChild(presRoot, 'sldSz');
    final cx = OpenXmlUtils.attr(sldSz, 'cx');
    final cy = OpenXmlUtils.attr(sldSz, 'cy');
    final slideSize = Size(
      cx != null ? OpenXmlUtils.parseEmuD(cx) : 960,
      cy != null ? OpenXmlUtils.parseEmuD(cy) : 540,
    );

    // Masters first (each carries its theme), then layouts (which reference a
    // master), so slides can resolve the full chain.
    _parseMasters(archive);
    _parseLayouts(archive);

    final slideIdList = OpenXmlUtils.findChild(presRoot, 'sldIdLst');
    final slideIds = slideIdList != null
        ? OpenXmlUtils.findChildren(slideIdList, 'sldId')
        : <XmlElement>[];

    final slides = <Slide>[];
    for (var i = 0; i < slideIds.length; i++) {
      final relId = OpenXmlUtils.attr(slideIds[i], 'id', nsPrefix: 'r');
      if (relId == null) continue;
      final slidePath = _relsMap['ppt/_rels/presentation.xml.rels']?[relId];
      if (slidePath == null) continue;
      slides.add(await _parseSlide(archive, slidePath, i + 1));
    }

    final firstTheme = _masters.values.isNotEmpty
        ? PresentationTheme(
            colors: _masters.values.first.scheme,
            fonts: _masters.values.first.fonts,
          )
        : const PresentationTheme();

    return Presentation(
      id: _uuid.v4(),
      title: 'Imported Presentation',
      slides: slides.isEmpty ? [Slide(id: _uuid.v4(), slideNumber: 1)] : slides,
      theme: firstTheme,
      settings: PresentationSettings(slideSize: slideSize),
      filePath: displayFilePath,
    );
  }

  bool _isLegacyPpt(List<int> bytes) {
    const oleHeader = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];
    if (bytes.length < oleHeader.length) return false;
    for (var i = 0; i < oleHeader.length; i++) {
      if (bytes[i] != oleHeader[i]) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Masters / layouts / theme
  // ---------------------------------------------------------------------------

  void _parseMasters(Archive archive) {
    for (final file in archive.files) {
      if (!file.name.startsWith('ppt/slideMasters/slideMaster') ||
          !file.name.endsWith('.xml')) {
        continue;
      }
      final root = XmlDocument.parse(
        String.fromCharCodes(file.content),
      ).rootElement;
      final themePath = _findTarget(_relsPathForPart(file.name), '/theme/');
      final theme = themePath != null
          ? _parseThemeAt(archive, themePath)
          : const PresentationTheme();
      final scheme = theme.colors;
      final fonts = theme.fonts;

      final cSld = OpenXmlUtils.findChild(root, 'cSld');
      final spTree = OpenXmlUtils.findChild(cSld, 'spTree');
      final placeholders = <_Ph>[];
      final decorative = <XmlElement>[];
      _collectShapes(spTree, placeholders, decorative, scheme, fonts);

      final txStyles = OpenXmlUtils.findChild(root, 'txStyles');
      _masters[file.name] = _Master(
        path: file.name,
        scheme: scheme,
        fonts: fonts,
        bg: OpenXmlUtils.findChild(cSld, 'bg'),
        placeholders: placeholders,
        decorative: decorative,
        titleStyle: _parseListStyle(
          OpenXmlUtils.findChild(txStyles, 'titleStyle'),
          scheme,
          fonts,
        ),
        bodyStyle: _parseListStyle(
          OpenXmlUtils.findChild(txStyles, 'bodyStyle'),
          scheme,
          fonts,
        ),
        otherStyle: _parseListStyle(
          OpenXmlUtils.findChild(txStyles, 'otherStyle'),
          scheme,
          fonts,
        ),
      );
    }
  }

  void _parseLayouts(Archive archive) {
    for (final file in archive.files) {
      if (!file.name.startsWith('ppt/slideLayouts/slideLayout') ||
          !file.name.endsWith('.xml')) {
        continue;
      }
      final root = XmlDocument.parse(
        String.fromCharCodes(file.content),
      ).rootElement;
      final masterPath =
          _findTarget(_relsPathForPart(file.name), '/slideMasters/') ?? '';
      final master = _masters[masterPath];
      final scheme = master?.scheme ?? _defaultScheme;
      final fonts = master?.fonts ?? _defaultFonts;

      final cSld = OpenXmlUtils.findChild(root, 'cSld');
      final spTree = OpenXmlUtils.findChild(cSld, 'spTree');
      final placeholders = <_Ph>[];
      final decorative = <XmlElement>[];
      _collectShapes(spTree, placeholders, decorative, scheme, fonts);

      _layouts[file.name] = _Layout(
        path: file.name,
        masterPath: masterPath,
        bg: OpenXmlUtils.findChild(cSld, 'bg'),
        placeholders: placeholders,
        decorative: decorative,
      );
    }
  }

  /// Splits an spTree's top-level shapes into placeholders (which other parts
  /// inherit from) and decorative shapes (drawn behind slide content).
  void _collectShapes(
    XmlElement? spTree,
    List<_Ph> placeholders,
    List<XmlElement> decorative,
    ColorScheme scheme,
    FontScheme fonts,
  ) {
    if (spTree == null) return;
    for (final child in spTree.childElements) {
      if (child.name.local == 'sp') {
        final ph = _placeholderInfo(child, scheme, fonts);
        if (ph != null) {
          placeholders.add(ph);
        } else {
          decorative.add(child);
        }
      } else if (child.name.local == 'pic' ||
          child.name.local == 'grpSp' ||
          child.name.local == 'graphicFrame') {
        decorative.add(child);
      }
    }
  }

  _Ph? _placeholderInfo(XmlElement sp, ColorScheme scheme, FontScheme fonts) {
    final nvSpPr = OpenXmlUtils.findChild(sp, 'nvSpPr');
    final nvPr = OpenXmlUtils.findChild(nvSpPr, 'nvPr');
    final ph = OpenXmlUtils.findChild(nvPr, 'ph');
    if (ph == null) return null;
    final spPr = OpenXmlUtils.findChild(sp, 'spPr');
    final xfrm = _parseXfrm(OpenXmlUtils.findChild(spPr, 'xfrm'));
    final txBody = OpenXmlUtils.findChild(sp, 'txBody');
    return _Ph(
      type: OpenXmlUtils.attr(ph, 'type') ?? 'body',
      idx: OpenXmlUtils.attr(ph, 'idx') ?? '',
      off: xfrm.off,
      size: xfrm.ext,
      rot: xfrm.rot,
      lstStyle: _parseListStyle(
        OpenXmlUtils.findChild(txBody, 'lstStyle'),
        scheme,
        fonts,
      ),
    );
  }

  PresentationTheme _parseThemeAt(Archive archive, String themePath) {
    final entry = archive.findFile(themePath);
    if (entry == null) return const PresentationTheme();
    final root = XmlDocument.parse(
      String.fromCharCodes(entry.content),
    ).rootElement;
    final themeElements = OpenXmlUtils.findChild(root, 'themeElements');
    final clrScheme = OpenXmlUtils.findChild(themeElements, 'clrScheme');
    final fontScheme = OpenXmlUtils.findChild(themeElements, 'fontScheme');

    Color schemeColor(String name, Color fallback) {
      final el = OpenXmlUtils.findChild(clrScheme, name);
      return OpenXmlUtils.colorIn(el, scheme: _defaultScheme) ?? fallback;
    }

    final colors = ColorScheme(
      text1: schemeColor('dk1', const Color(0xFF000000)),
      background1: schemeColor('lt1', const Color(0xFFFFFFFF)),
      accent1: schemeColor('accent1', const Color(0xFF4472C4)),
      accent2: schemeColor('accent2', const Color(0xFFED7D31)),
      accent3: schemeColor('accent3', const Color(0xFFA5A5A5)),
      accent4: schemeColor('accent4', const Color(0xFFFFC000)),
      accent5: schemeColor('accent5', const Color(0xFF5B9BD5)),
      accent6: schemeColor('accent6', const Color(0xFF70AD47)),
      hyperlink: schemeColor('hlink', const Color(0xFF0563C1)),
      followedHyperlink: schemeColor('folHlink', const Color(0xFF954F72)),
    );

    String fontOf(String type, String fallback) {
      final latin = OpenXmlUtils.findChild(
        OpenXmlUtils.findChild(fontScheme, type),
        'latin',
      );
      return OpenXmlUtils.attr(latin, 'typeface') ?? fallback;
    }

    return PresentationTheme(
      colors: colors,
      fonts: FontScheme(
        majorFont: fontOf('majorFont', 'Calibri'),
        minorFont: fontOf('minorFont', 'Calibri'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Slide
  // ---------------------------------------------------------------------------

  Future<Slide> _parseSlide(
    Archive archive,
    String slidePath,
    int slideNumber,
  ) async {
    final entry = archive.findFile(slidePath);
    if (entry == null) return Slide(id: _uuid.v4(), slideNumber: slideNumber);

    final root = XmlDocument.parse(
      String.fromCharCodes(entry.content),
    ).rootElement;
    final cSld = OpenXmlUtils.findChild(root, 'cSld');
    final spTree = OpenXmlUtils.findChild(cSld, 'spTree');

    final layoutPath = _findTarget(
      _relsPathForPart(slidePath),
      '/slideLayouts/',
    );
    final layout = layoutPath != null ? _layouts[layoutPath] : null;
    final master = layout != null ? _masters[layout.masterPath] : null;
    final scheme = master?.scheme ?? _defaultScheme;
    final fonts = master?.fonts ?? _defaultFonts;

    final elements = <SlideElement>[];
    var zIndex = 0;

    // Decorative master/layout graphics render behind the slide's own content.
    final showMaster = OpenXmlUtils.attr(root, 'showMasterSp') != '0';
    if (showMaster && master != null) {
      for (final sp in master.decorative) {
        final el = _parseAny(sp, master.path, scheme, fonts);
        if (el != null) elements.add(el.copyWith(zIndex: zIndex++));
      }
    }
    if (layout != null) {
      for (final sp in layout.decorative) {
        final el = _parseAny(sp, layout.path, scheme, fonts);
        if (el != null) elements.add(el.copyWith(zIndex: zIndex++));
      }
    }

    if (spTree != null) {
      for (final child in spTree.childElements) {
        final el = _parseAny(
          child,
          slidePath,
          scheme,
          fonts,
          layout: layout,
          master: master,
        );
        if (el != null) elements.add(el.copyWith(zIndex: zIndex++));
      }
    }

    final bgFill =
        _backgroundFill(cSld, scheme) ??
        (layout != null ? _resolveBg(layout.bg, scheme) : null) ??
        (master != null ? _resolveBg(master.bg, scheme) : null);
    final bgColor = _backgroundColorFromFill(bgFill);

    final transitionEl = OpenXmlUtils.findChild(root, 'transition');
    SlideTransition? transition;
    if (transitionEl != null) {
      final dur = OpenXmlUtils.attr(transitionEl, 'dur');
      transition = SlideTransition(
        type: _parseTransitionType(_transitionChildName(transitionEl)),
        duration: dur != null
            ? Duration(milliseconds: int.tryParse(dur) ?? 2000)
            : const Duration(milliseconds: 2000),
      );
    }

    return Slide(
      id: _uuid.v4(),
      elements: elements,
      backgroundColorOverride: bgColor,
      backgroundFillOverride: bgFill,
      transition: transition ?? const SlideTransition(),
      slideNumber: slideNumber,
    );
  }

  BackgroundFill? _backgroundFill(XmlElement? cSld, ColorScheme scheme) {
    return _resolveBg(OpenXmlUtils.findChild(cSld, 'bg'), scheme);
  }

  Color? _backgroundColorFromFill(BackgroundFill? fill) {
    if (fill == null) return null;
    if (fill.solidColor != null) return fill.solidColor;
    final stops = fill.gradient?.stops;
    if (stops != null && stops.isNotEmpty) return stops.first.color;
    return null;
  }

  BackgroundFill? _resolveBg(XmlElement? bg, ColorScheme scheme) {
    if (bg == null) return null;
    final bgPr = OpenXmlUtils.findChild(bg, 'bgPr');
    final solid = OpenXmlUtils.findChild(bgPr, 'solidFill');
    if (solid != null) {
      final color = OpenXmlUtils.colorIn(solid, scheme: scheme);
      if (color != null) {
        return BackgroundFill(
          type: BackgroundFillType.solid,
          solidColor: color,
        );
      }
    }
    final gradient = _parseGradientFill(
      OpenXmlUtils.findChild(bgPr, 'gradFill'),
      scheme,
    );
    if (gradient != null) {
      return BackgroundFill(
        type: BackgroundFillType.gradient,
        gradient: gradient,
      );
    }
    // bgRef points into the theme's background fill styles; approximate with
    // its color child.
    final bgRef = OpenXmlUtils.findChild(bg, 'bgRef');
    if (bgRef != null) {
      final color = OpenXmlUtils.colorIn(bgRef, scheme: scheme);
      if (color != null) {
        return BackgroundFill(
          type: BackgroundFillType.solid,
          solidColor: color,
        );
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Shape dispatch
  // ---------------------------------------------------------------------------

  SlideElement? _parseAny(
    XmlElement el,
    String partPath,
    ColorScheme scheme,
    FontScheme fonts, {
    _Layout? layout,
    _Master? master,
  }) {
    switch (el.name.local) {
      case 'sp':
        return _parseShape(el, partPath, scheme, fonts, layout, master);
      case 'pic':
        return _parsePicture(el, partPath, scheme);
      case 'graphicFrame':
        return _parseGraphicFrame(el, partPath, scheme, fonts);
      case 'grpSp':
        return _parseGroup(el, partPath, scheme, fonts);
      default:
        return null;
    }
  }

  SlideElement? _parseShape(
    XmlElement sp,
    String partPath,
    ColorScheme scheme,
    FontScheme fonts,
    _Layout? layout,
    _Master? master,
  ) {
    final nvSpPr = OpenXmlUtils.findChild(sp, 'nvSpPr');
    final cNvPr = OpenXmlUtils.findChild(nvSpPr, 'cNvPr');
    final name = OpenXmlUtils.attr(cNvPr, 'name');
    final id = OpenXmlUtils.attr(cNvPr, 'id') ?? _uuid.v4();

    // Placeholder linkage to the layout/master.
    final ph = OpenXmlUtils.findChild(
      OpenXmlUtils.findChild(nvSpPr, 'nvPr'),
      'ph',
    );
    final phType = ph != null
        ? (OpenXmlUtils.attr(ph, 'type') ?? 'body')
        : null;
    final phIdx = ph != null ? (OpenXmlUtils.attr(ph, 'idx') ?? '') : '';

    final spPr = OpenXmlUtils.findChild(sp, 'spPr');
    final xfrm = _parseXfrm(OpenXmlUtils.findChild(spPr, 'xfrm'));

    // Geometry: slide value, else inherited from layout, else master.
    _Ph? layoutPh;
    _Ph? masterPh;
    if (phType != null) {
      layoutPh = layout != null
          ? _matchPh(layout.placeholders, phType, phIdx)
          : null;
      masterPh = master != null
          ? _matchPh(master.placeholders, phType, phIdx)
          : null;
    }

    final off = xfrm.off ?? layoutPh?.off ?? masterPh?.off ?? Offset.zero;
    final size =
        xfrm.ext ?? layoutPh?.size ?? masterPh?.size ?? const Size(100, 100);
    final rot = xfrm.rot;

    final fill = _resolveFill(sp, spPr, scheme);
    final stroke = _resolveStroke(spPr, scheme);
    final customGeometry = _parseCustomGeometry(
      OpenXmlUtils.findChild(spPr, 'custGeom'),
    );
    final shapeType = customGeometry != null
        ? ShapeType.custom
        : _shapeType(
            OpenXmlUtils.attr(OpenXmlUtils.findChild(spPr, 'prstGeom'), 'prst'),
          );

    final txBody = OpenXmlUtils.findChild(sp, 'txBody');
    if (txBody != null) {
      // Effective list style for inherited text sizing/coloring.
      final listStyle = _effectiveListStyle(
        phType,
        layoutPh,
        masterPh,
        master,
        scheme,
        fonts,
      );
      final paragraphs = _parseTextBody(txBody, listStyle, scheme, fonts);
      final hasText = paragraphs.any((p) => p.plainText.trim().isNotEmpty);
      // Skip empty inherited prompt placeholders so they don't render as boxes.
      if (!hasText && ph != null && _isEmptyTxBody(txBody)) return null;
      if (hasText) {
        return TextElement(
          id: id,
          name: name,
          position: off,
          size: size,
          rotation: rot,
          paragraphs: paragraphs,
          fillColor: fill,
          borderWidth: stroke?.width,
          borderColor: stroke?.color,
          zIndex: 0,
        );
      }
    }

    return ShapeElement(
      id: id,
      name: name,
      position: off,
      size: size,
      rotation: rot,
      fillColor: fill ?? const Color(0x00000000),
      gradientStart: _gradient(spPr, scheme)?.$1,
      gradientEnd: _gradient(spPr, scheme)?.$2,
      gradientType: _gradient(spPr, scheme) != null
          ? GradientType.linear
          : null,
      strokeColor: stroke?.color ?? const Color(0xFF000000),
      strokeWidth: stroke?.width ?? 0,
      shapeType: shapeType,
      customGeometry: customGeometry,
      flipHorizontal: xfrm.flipH,
      flipVertical: xfrm.flipV,
      zIndex: 0,
    );
  }

  bool _isEmptyTxBody(XmlElement txBody) {
    for (final p in OpenXmlUtils.findChildren(txBody, 'p')) {
      for (final r in OpenXmlUtils.findChildren(p, 'r')) {
        if ((OpenXmlUtils.findChild(r, 't')?.innerText ?? '').isNotEmpty) {
          return false;
        }
      }
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Fills / strokes
  // ---------------------------------------------------------------------------

  Color? _resolveFill(XmlElement sp, XmlElement? spPr, ColorScheme scheme) {
    if (spPr != null) {
      if (OpenXmlUtils.findChild(spPr, 'noFill') != null) {
        return const Color(0x00000000);
      }
      final solid = OpenXmlUtils.findChild(spPr, 'solidFill');
      if (solid != null) {
        final c = OpenXmlUtils.colorIn(solid, scheme: scheme);
        if (c != null) return c;
      }
    }
    // Themed shapes carry their fill in <p:style><a:fillRef>.
    final fillRef = OpenXmlUtils.findChild(
      OpenXmlUtils.findChild(sp, 'style'),
      'fillRef',
    );
    if (fillRef != null) return OpenXmlUtils.colorIn(fillRef, scheme: scheme);
    return null;
  }

  ({Color color, double width})? _resolveStroke(
    XmlElement? spPr,
    ColorScheme scheme,
  ) {
    final ln = OpenXmlUtils.findChild(spPr, 'ln');
    if (ln == null) return null;
    if (OpenXmlUtils.findChild(ln, 'noFill') != null) return null;
    final w = OpenXmlUtils.attr(ln, 'w');
    final width = w != null ? (int.tryParse(w) ?? 0) / 12700.0 : 1.0;
    final solid = OpenXmlUtils.findChild(ln, 'solidFill');
    final color = OpenXmlUtils.colorIn(solid, scheme: scheme);
    if (color == null && width == 0) return null;
    return (color: color ?? const Color(0xFF000000), width: width);
  }

  (Color, Color)? _gradient(XmlElement? spPr, ColorScheme scheme) {
    final gradient = _parseGradientFill(
      OpenXmlUtils.findChild(spPr, 'gradFill'),
      scheme,
    );
    if (gradient == null || gradient.stops.length < 2) return null;
    return (gradient.stops.first.color, gradient.stops.last.color);
  }

  GradientFill? _parseGradientFill(XmlElement? grad, ColorScheme scheme) {
    if (grad == null) return null;
    final gsLst = OpenXmlUtils.findChild(grad, 'gsLst');
    final stops =
        OpenXmlUtils.findChildren(gsLst, 'gs')
            .map((gs) {
              final color = OpenXmlUtils.colorIn(gs, scheme: scheme);
              if (color == null) return null;
              final position =
                  (int.tryParse(OpenXmlUtils.attr(gs, 'pos') ?? '') ?? 0) /
                  100000.0;
              return ColorStop(
                color: color,
                position: position.clamp(0.0, 1.0),
              );
            })
            .whereType<ColorStop>()
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position));

    if (stops.length < 2) return null;
    final lin = OpenXmlUtils.findChild(grad, 'lin');
    final angle =
        (int.tryParse(OpenXmlUtils.attr(lin, 'ang') ?? '0') ?? 0) / 60000.0;
    return GradientFill(stops: stops, angle: angle);
  }

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  /// Builds the effective per-level list style for a placeholder by layering
  /// master text styles (by category) under the master and layout placeholder
  /// list styles (highest priority).
  _ListStyle _effectiveListStyle(
    String? phType,
    _Ph? layoutPh,
    _Ph? masterPh,
    _Master? master,
    ColorScheme scheme,
    FontScheme fonts,
  ) {
    final layers = <_ListStyle>[];
    if (master != null && phType != null) {
      switch (_category(phType)) {
        case 'title':
          layers.add(master.titleStyle);
          break;
        case 'body':
          layers.add(master.bodyStyle);
          break;
        default:
          layers.add(master.otherStyle);
      }
    }
    if (masterPh != null) layers.add(masterPh.lstStyle);
    if (layoutPh != null) layers.add(layoutPh.lstStyle);
    return _mergeListStyles(layers);
  }

  List<RichParagraph> _parseTextBody(
    XmlElement txBody,
    _ListStyle listStyle,
    ColorScheme scheme,
    FontScheme fonts,
  ) {
    final paragraphs = <RichParagraph>[];
    for (final p in OpenXmlUtils.findChildren(txBody, 'p')) {
      final pPr = OpenXmlUtils.findChild(p, 'pPr');
      final level = int.tryParse(OpenXmlUtils.attr(pPr, 'lvl') ?? '0') ?? 0;
      final levelStyle = listStyle.at(level);

      var align = _align(OpenXmlUtils.attr(pPr, 'algn')) ?? levelStyle?.align;

      final runs = <TextRun>[];
      for (final node in p.childElements) {
        if (node.name.local == 'r' || node.name.local == 'fld') {
          final t = OpenXmlUtils.findChild(node, 't');
          final text = t?.innerText ?? '';
          if (text.isEmpty && node.name.local == 'r') continue;
          runs.add(
            _resolveRun(
              OpenXmlUtils.findChild(node, 'rPr'),
              levelStyle,
              scheme,
              fonts,
              text: text,
            ),
          );
        } else if (node.name.local == 'br') {
          runs.add(const TextRun(text: '\n'));
        }
      }
      if (runs.isEmpty) runs.add(const TextRun(text: ''));

      paragraphs.add(
        RichParagraph(
          runs: runs,
          style: ParagraphStyle(
            alignment: align ?? TextAlign.left,
            level: level,
            bulletType: _bulletType(pPr),
          ),
        ),
      );
    }
    return paragraphs.isEmpty ? [const RichParagraph()] : paragraphs;
  }

  TextRun _resolveRun(
    XmlElement? rPr,
    _LevelStyle? levelStyle,
    ColorScheme scheme,
    FontScheme fonts, {
    required String text,
  }) {
    var font = levelStyle?.font;
    var size = levelStyle?.size;
    var color = levelStyle?.color;
    var bold = levelStyle?.bold ?? false;
    var italic = levelStyle?.italic ?? false;
    var underline = false;
    var strike = false;

    if (rPr != null) {
      final sz = OpenXmlUtils.attr(rPr, 'sz');
      if (sz != null) size = (int.tryParse(sz) ?? 1800) / 100.0;
      final b = OpenXmlUtils.attr(rPr, 'b');
      if (b != null) bold = b == '1' || b == 'true';
      final i = OpenXmlUtils.attr(rPr, 'i');
      if (i != null) italic = i == '1' || i == 'true';
      final u = OpenXmlUtils.attr(rPr, 'u');
      if (u != null && u != 'none') underline = true;
      final s = OpenXmlUtils.attr(rPr, 'strike');
      if (s != null && s != 'noStrike') strike = true;
      final latin = OpenXmlUtils.findChild(rPr, 'latin');
      final typeface = OpenXmlUtils.attr(latin, 'typeface');
      if (typeface != null) font = typeface;
      final solid = OpenXmlUtils.findChild(rPr, 'solidFill');
      final c = OpenXmlUtils.colorIn(solid, scheme: scheme);
      if (c != null) color = c;
    }

    return TextRun(
      text: text,
      fontFamily: _resolveFont(font, fonts),
      fontSize: size ?? 18,
      color: color ?? scheme.text1,
      bold: bold,
      italic: italic,
      underline: underline,
      strikethrough: strike,
    );
  }

  String _resolveFont(String? typeface, FontScheme fonts) {
    if (typeface == null || typeface.isEmpty) return fonts.minorFont;
    if (typeface.startsWith('+mj')) return fonts.majorFont;
    if (typeface.startsWith('+mn')) return fonts.minorFont;
    return typeface;
  }

  _ListStyle _parseListStyle(
    XmlElement? lstStyle,
    ColorScheme scheme,
    FontScheme fonts,
  ) {
    final style = _ListStyle();
    if (lstStyle == null) return style;
    for (final child in lstStyle.childElements) {
      final m = RegExp(r'^lvl(\d)pPr$').firstMatch(child.name.local);
      if (m == null) continue;
      final level = (int.parse(m.group(1)!) - 1).clamp(0, 8);
      final defRPr = OpenXmlUtils.findChild(child, 'defRPr');
      final ls = _LevelStyle()
        ..align = _align(OpenXmlUtils.attr(child, 'algn'));
      if (defRPr != null) {
        final sz = OpenXmlUtils.attr(defRPr, 'sz');
        if (sz != null) ls.size = (int.tryParse(sz) ?? 1800) / 100.0;
        final b = OpenXmlUtils.attr(defRPr, 'b');
        if (b != null) ls.bold = b == '1' || b == 'true';
        final i = OpenXmlUtils.attr(defRPr, 'i');
        if (i != null) ls.italic = i == '1' || i == 'true';
        final latin = OpenXmlUtils.findChild(defRPr, 'latin');
        ls.font = OpenXmlUtils.attr(latin, 'typeface');
        final solid = OpenXmlUtils.findChild(defRPr, 'solidFill');
        ls.color = OpenXmlUtils.colorIn(solid, scheme: scheme);
      }
      style.levels[level] = ls;
    }
    return style;
  }

  _ListStyle _mergeListStyles(List<_ListStyle> lowToHigh) {
    final merged = _ListStyle();
    for (final layer in lowToHigh) {
      layer.levels.forEach((level, ls) {
        final target = merged.levels.putIfAbsent(level, () => _LevelStyle());
        if (ls.size != null) target.size = ls.size;
        if (ls.color != null) target.color = ls.color;
        if (ls.font != null) target.font = ls.font;
        if (ls.bold != null) target.bold = ls.bold;
        if (ls.italic != null) target.italic = ls.italic;
        if (ls.align != null) target.align = ls.align;
      });
    }
    return merged;
  }

  TextAlign? _align(String? algn) {
    switch (algn) {
      case 'ctr':
        return TextAlign.center;
      case 'r':
        return TextAlign.right;
      case 'just':
        return TextAlign.justify;
      case 'l':
        return TextAlign.left;
      default:
        return null;
    }
  }

  BulletType _bulletType(XmlElement? pPr) {
    if (pPr == null) return BulletType.none;
    if (OpenXmlUtils.findChild(pPr, 'buNone') != null) return BulletType.none;
    if (OpenXmlUtils.findChild(pPr, 'buAutoNum') != null) {
      return BulletType.number;
    }
    if (OpenXmlUtils.findChild(pPr, 'buChar') != null) return BulletType.bullet;
    return BulletType.none;
  }

  String _category(String phType) {
    switch (phType) {
      case 'title':
      case 'ctrTitle':
        return 'title';
      case 'body':
      case 'subTitle':
      case 'obj':
        return 'body';
      default:
        return 'other';
    }
  }

  /// Matches a slide placeholder to one in a layout/master. Index takes
  /// priority; otherwise type, treating title/ctrTitle as equivalent.
  _Ph? _matchPh(List<_Ph> phs, String type, String idx) {
    if (idx.isNotEmpty) {
      for (final p in phs) {
        if (p.idx == idx) return p;
      }
    }
    final cat = _category(type);
    for (final p in phs) {
      if (p.type == type) return p;
    }
    for (final p in phs) {
      if (_category(p.type) == cat) return p;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Pictures / groups / frames
  // ---------------------------------------------------------------------------

  SlideElement? _parsePicture(
    XmlElement pic,
    String partPath,
    ColorScheme scheme,
  ) {
    final cNvPr = OpenXmlUtils.findChild(
      OpenXmlUtils.findChild(pic, 'nvPicPr'),
      'cNvPr',
    );
    final id = OpenXmlUtils.attr(cNvPr, 'id') ?? _uuid.v4();
    final name = OpenXmlUtils.attr(cNvPr, 'name');

    final spPr = OpenXmlUtils.findChild(pic, 'spPr');
    final xfrm = _parseXfrm(OpenXmlUtils.findChild(spPr, 'xfrm'));

    final blip = OpenXmlUtils.findChild(
      OpenXmlUtils.findChild(pic, 'blipFill'),
      'blip',
    );
    final opacity = _pictureOpacity(blip);
    final embedId = OpenXmlUtils.attr(blip, 'embed', nsPrefix: 'r');
    String? imagePath;
    if (embedId != null) {
      final archivePath = _relsMap[_relsPathForPart(partPath)]?[embedId];
      if (archivePath != null) imagePath = _mediaFiles[archivePath];
    }

    return ImageElement(
      id: id,
      name: name,
      position: xfrm.off ?? Offset.zero,
      size: xfrm.ext ?? const Size(100, 100),
      rotation: xfrm.rot,
      imagePath: imagePath ?? '',
      opacity: opacity,
      zIndex: 0,
    );
  }

  double _pictureOpacity(XmlElement? blip) {
    if (blip == null) return 1.0;
    final values = <double>[];
    for (final child in blip.childElements) {
      switch (child.name.local) {
        case 'alphaModFix':
        case 'alphaMod':
          final amt = OpenXmlUtils.attr(child, 'amt');
          if (amt != null) {
            values.add(((int.tryParse(amt) ?? 100000) / 100000.0).clamp(0, 1));
          }
          break;
        case 'alpha':
          final val = OpenXmlUtils.attr(child, 'val');
          if (val != null) {
            values.add(((int.tryParse(val) ?? 100000) / 100000.0).clamp(0, 1));
          }
          break;
      }
    }
    if (values.isEmpty) return 1.0;
    return values.reduce((a, b) => a * b);
  }

  SlideElement? _parseGroup(
    XmlElement grpSp,
    String partPath,
    ColorScheme scheme,
    FontScheme fonts,
  ) {
    final grpSpPr = OpenXmlUtils.findChild(grpSp, 'grpSpPr');
    final xfrmEl = OpenXmlUtils.findChild(grpSpPr, 'xfrm');
    final xfrm = _parseXfrm(xfrmEl);
    final chOff = OpenXmlUtils.findChild(xfrmEl, 'chOff');
    final chExt = OpenXmlUtils.findChild(xfrmEl, 'chExt');

    final off = xfrm.off ?? Offset.zero;
    final ext = xfrm.ext ?? const Size(100, 100);
    final chOffX = OpenXmlUtils.parseEmuD(OpenXmlUtils.attr(chOff, 'x'));
    final chOffY = OpenXmlUtils.parseEmuD(OpenXmlUtils.attr(chOff, 'y'));
    final chCx = OpenXmlUtils.parseEmuD(OpenXmlUtils.attr(chExt, 'cx'));
    final chCy = OpenXmlUtils.parseEmuD(OpenXmlUtils.attr(chExt, 'cy'));
    final sx = chCx != 0 ? ext.width / chCx : 1.0;
    final sy = chCy != 0 ? ext.height / chCy : 1.0;

    final children = <SlideElement>[];
    for (final child in grpSp.childElements) {
      final el = _parseAny(child, partPath, scheme, fonts);
      if (el == null) continue;
      children.add(_transformChild(el, off, chOffX, chOffY, sx, sy));
    }
    if (children.isEmpty) return null;

    return GroupElement(
      id: _uuid.v4(),
      name: null,
      position: off,
      size: ext,
      children: children,
      zIndex: 0,
    );
  }

  /// Maps an element from a group's child coordinate space into absolute slide
  /// coordinates, recursing into nested groups.
  SlideElement _transformChild(
    SlideElement el,
    Offset off,
    double chOffX,
    double chOffY,
    double sx,
    double sy,
  ) {
    final newPos = Offset(
      off.dx + (el.position.dx - chOffX) * sx,
      off.dy + (el.position.dy - chOffY) * sy,
    );
    final newSize = Size(el.size.width * sx, el.size.height * sy);
    if (el is GroupElement) {
      final movedChildren = el.children
          .map((c) => _transformChild(c, off, chOffX, chOffY, sx, sy))
          .toList();
      return el.copyWith(
        position: newPos,
        size: newSize,
        children: movedChildren,
      );
    }
    return el.copyWith(position: newPos, size: newSize);
  }

  SlideElement? _parseGraphicFrame(
    XmlElement graphicFrame,
    String partPath,
    ColorScheme scheme,
    FontScheme fonts,
  ) {
    final xfrm = _parseXfrm(OpenXmlUtils.findChild(graphicFrame, 'xfrm'));
    final off = xfrm.off ?? Offset.zero;
    final size = xfrm.ext ?? const Size(100, 100);

    final graphicData = OpenXmlUtils.findChild(
      OpenXmlUtils.findChild(graphicFrame, 'graphic'),
      'graphicData',
    );
    if (graphicData == null) return null;
    final uri = OpenXmlUtils.attr(graphicData, 'uri');

    if (uri == 'http://schemas.openxmlformats.org/drawingml/2006/table') {
      final tbl = OpenXmlUtils.findChild(graphicData, 'tbl');
      if (tbl != null) return _parseTable(tbl, off, size, scheme, fonts);
    }
    if (uri == 'http://schemas.openxmlformats.org/drawingml/2006/chart') {
      final chartEl = OpenXmlUtils.findChild(graphicData, 'chart');
      final relId = OpenXmlUtils.attr(chartEl, 'id', nsPrefix: 'r');
      String? chartPath;
      if (relId != null) {
        chartPath = _relsMap[_relsPathForPart(partPath)]?[relId];
      }
      return _parseChart(chartPath, off, size, scheme);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Charts (ppt/charts/chartN.xml)
  // ---------------------------------------------------------------------------

  /// Reads an embedded DrawingML chart part into a [ChartElement]. The cached
  /// values (`<c:numCache>` / `<c:strCache>`) are what PowerPoint draws from
  /// without re-opening the workbook, so they're what we parse.
  ChartElement _parseChart(
    String? chartPath,
    Offset off,
    Size size,
    ColorScheme scheme,
  ) {
    ChartData data = const ChartData();
    var type = ChartType.column;
    String? title;
    var hasLegend = false;
    var legendPosition = LegendPosition.right;

    final entry = chartPath != null ? _archive.findFile(chartPath) : null;
    if (entry != null) {
      final root = XmlDocument.parse(
        String.fromCharCodes(entry.content),
      ).rootElement;
      final chart = OpenXmlUtils.findChild(root, 'chart');
      final plotArea = OpenXmlUtils.findChild(chart, 'plotArea');

      // The first recognised plot element decides the chart type.
      XmlElement? plot;
      for (final child in plotArea?.childElements ?? const <XmlElement>[]) {
        final mapped = _chartTypeFor(child.name.local, child);
        if (mapped != null) {
          type = mapped;
          plot = child;
          break;
        }
      }

      if (plot != null) {
        final accents = [
          scheme.accent1,
          scheme.accent2,
          scheme.accent3,
          scheme.accent4,
          scheme.accent5,
          scheme.accent6,
        ];
        final seriesEls = OpenXmlUtils.findChildren(plot, 'ser');
        final series = <ChartSeries>[];
        var categories = <String>[];
        for (var i = 0; i < seriesEls.length; i++) {
          final ser = seriesEls[i];
          if (categories.isEmpty) {
            categories = _readRefValues(OpenXmlUtils.findChild(ser, 'cat'));
          }
          series.add(
            ChartSeries(
              name: _seriesName(ser, i),
              values: _readRefValues(
                OpenXmlUtils.findChild(ser, 'val'),
              ).map((v) => double.tryParse(v) ?? 0).toList(),
              color: _seriesColor(ser, scheme) ?? accents[i % accents.length],
            ),
          );
        }
        data = ChartData(categories: categories, series: series);
      }

      title = _chartTitle(chart);
      final legend = OpenXmlUtils.findChild(chart, 'legend');
      if (legend != null) {
        hasLegend = true;
        legendPosition = _legendPosition(
          OpenXmlUtils.attr(OpenXmlUtils.findChild(legend, 'legendPos'), 'val'),
        );
      }
    }

    return ChartElement(
      id: _uuid.v4(),
      position: off,
      size: size,
      data: data,
      type: type,
      hasLegend: hasLegend,
      legendPosition: legendPosition,
      hasTitle: title != null && title.isNotEmpty,
      title: title,
      zIndex: 0,
    );
  }

  ChartType? _chartTypeFor(String local, XmlElement el) {
    switch (local) {
      case 'barChart':
      case 'bar3DChart':
        final dir = OpenXmlUtils.attr(
          OpenXmlUtils.findChild(el, 'barDir'),
          'val',
        );
        return dir == 'bar' ? ChartType.bar : ChartType.column;
      case 'lineChart':
      case 'line3DChart':
        return ChartType.line;
      case 'pieChart':
      case 'pie3DChart':
      case 'doughnutChart':
        return ChartType.pie;
      case 'areaChart':
      case 'area3DChart':
        return ChartType.area;
      case 'scatterChart':
        return ChartType.scatter;
      case 'radarChart':
        return ChartType.radar;
      default:
        return null;
    }
  }

  /// Collects the cached point values from a `<c:cat>` or `<c:val>` reference,
  /// ordered by their `idx`.
  List<String> _readRefValues(XmlElement? ref) {
    if (ref == null) return const [];
    XmlElement? cache;
    for (final child in ref.childElements) {
      if (child.name.local == 'numRef' || child.name.local == 'strRef') {
        cache =
            OpenXmlUtils.findChild(child, 'numCache') ??
            OpenXmlUtils.findChild(child, 'strCache');
        break;
      }
      if (child.name.local == 'numLit' || child.name.local == 'strLit') {
        cache = child;
        break;
      }
    }
    if (cache == null) return const [];
    final points = OpenXmlUtils.findChildren(cache, 'pt');
    final indexed = <int, String>{};
    for (final pt in points) {
      final idx = int.tryParse(OpenXmlUtils.attr(pt, 'idx') ?? '') ?? 0;
      indexed[idx] = OpenXmlUtils.findChild(pt, 'v')?.innerText ?? '';
    }
    final sortedKeys = indexed.keys.toList()..sort();
    return [for (final k in sortedKeys) indexed[k]!];
  }

  String _seriesName(XmlElement ser, int index) {
    final tx = OpenXmlUtils.findChild(ser, 'tx');
    final fromRef = _readRefValues(tx);
    if (fromRef.isNotEmpty) return fromRef.first;
    final v = OpenXmlUtils.findChild(tx, 'v');
    if (v != null && v.innerText.isNotEmpty) return v.innerText;
    return 'Series ${index + 1}';
  }

  Color? _seriesColor(XmlElement ser, ColorScheme scheme) {
    final spPr = OpenXmlUtils.findChild(ser, 'spPr');
    if (spPr == null) return null;
    final solid = OpenXmlUtils.findChild(spPr, 'solidFill');
    final fill = OpenXmlUtils.colorIn(solid, scheme: scheme);
    if (fill != null) return fill;
    final ln = OpenXmlUtils.findChild(spPr, 'ln');
    return OpenXmlUtils.colorIn(
      OpenXmlUtils.findChild(ln, 'solidFill'),
      scheme: scheme,
    );
  }

  String? _chartTitle(XmlElement? chart) {
    if (OpenXmlUtils.attr(
          OpenXmlUtils.findChild(chart, 'autoTitleDeleted'),
          'val',
        ) ==
        '1') {
      return null;
    }
    final title = OpenXmlUtils.findChild(chart, 'title');
    if (title == null) return null;
    // Title text lives in <c:tx><c:rich> as DrawingML <a:t> runs.
    final buffer = StringBuffer();
    for (final t in title.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 't',
    )) {
      buffer.write(t.innerText);
    }
    final text = buffer.toString().trim();
    if (text.isNotEmpty) return text;
    final fromRef = _readRefValues(OpenXmlUtils.findChild(title, 'tx'));
    return fromRef.isNotEmpty ? fromRef.first : null;
  }

  LegendPosition _legendPosition(String? val) {
    switch (val) {
      case 't':
        return LegendPosition.top;
      case 'b':
        return LegendPosition.bottom;
      case 'l':
        return LegendPosition.left;
      default:
        return LegendPosition.right;
    }
  }

  TableElement _parseTable(
    XmlElement tbl,
    Offset off,
    Size size,
    ColorScheme scheme,
    FontScheme fonts,
  ) {
    final rows = <TableRow>[];
    final columns = <TableColumn>[];
    final cells = <TableCell>[];

    final tblGrid = OpenXmlUtils.findChild(tbl, 'tblGrid');
    for (final gridCol in OpenXmlUtils.findChildren(tblGrid, 'gridCol')) {
      final w = OpenXmlUtils.attr(gridCol, 'w');
      columns.add(
        TableColumn(
          id: _uuid.v4(),
          width: w != null ? OpenXmlUtils.parseEmuD(w) : 100,
        ),
      );
    }

    for (final tr in OpenXmlUtils.findChildren(tbl, 'tr')) {
      final h = OpenXmlUtils.attr(tr, 'h');
      final rowId = _uuid.v4();
      rows.add(
        TableRow(id: rowId, height: h != null ? OpenXmlUtils.parseEmuD(h) : 30),
      );
      var colIdx = 0;
      for (final tc in OpenXmlUtils.findChildren(tr, 'tc')) {
        final tcPr = OpenXmlUtils.findChild(tc, 'tcPr');
        final txBody = OpenXmlUtils.findChild(tc, 'txBody');
        final paragraphs = txBody != null
            ? _parseTextBody(txBody, _ListStyle(), scheme, fonts)
            : <RichParagraph>[];
        final fillColor = OpenXmlUtils.colorIn(
          OpenXmlUtils.findChild(tcPr, 'solidFill'),
          scheme: scheme,
        );
        if (colIdx < columns.length) {
          cells.add(
            TableCell(
              id: _uuid.v4(),
              rowId: rowId,
              colId: columns[colIdx].id,
              colSpan:
                  int.tryParse(OpenXmlUtils.attr(tcPr, 'gridSpan') ?? '1') ?? 1,
              rowSpan:
                  int.tryParse(OpenXmlUtils.attr(tcPr, 'rowSpan') ?? '1') ?? 1,
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
      position: off,
      size: size,
      rows: rows,
      columns: columns,
      cells: cells,
      zIndex: 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Geometry / shape type / transitions
  // ---------------------------------------------------------------------------

  _Xfrm _parseXfrm(XmlElement? xfrm) {
    if (xfrm == null) return const _Xfrm();
    final off = OpenXmlUtils.findChild(xfrm, 'off');
    final ext = OpenXmlUtils.findChild(xfrm, 'ext');
    final rotAttr = OpenXmlUtils.attr(xfrm, 'rot');
    return _Xfrm(
      off: off != null
          ? Offset(
              OpenXmlUtils.parseEmuD(OpenXmlUtils.attr(off, 'x')),
              OpenXmlUtils.parseEmuD(OpenXmlUtils.attr(off, 'y')),
            )
          : null,
      ext: ext != null
          ? Size(
              OpenXmlUtils.parseEmuD(OpenXmlUtils.attr(ext, 'cx')),
              OpenXmlUtils.parseEmuD(OpenXmlUtils.attr(ext, 'cy')),
            )
          : null,
      rot: rotAttr != null ? (int.tryParse(rotAttr) ?? 0) / 60000.0 : 0.0,
      flipH: OpenXmlUtils.attr(xfrm, 'flipH') == '1',
      flipV: OpenXmlUtils.attr(xfrm, 'flipV') == '1',
    );
  }

  ShapeType _shapeType(String? prst) {
    switch (prst) {
      case 'ellipse':
        return ShapeType.circle;
      case 'roundRect':
        return ShapeType.roundedRectangle;
      case 'triangle':
        return ShapeType.triangle;
      case 'diamond':
        return ShapeType.diamond;
      case 'pentagon':
        return ShapeType.pentagon;
      case 'hexagon':
        return ShapeType.hexagon;
      case 'star5':
        return ShapeType.star;
      case 'donut':
        return ShapeType.donut;
      case 'rightArrow':
      case 'leftArrow':
      case 'arrow':
        return ShapeType.arrow;
      default:
        return ShapeType.rectangle;
    }
  }

  CustomGeometry? _parseCustomGeometry(XmlElement? custGeom) {
    final pathLst = OpenXmlUtils.findChild(custGeom, 'pathLst');
    if (pathLst == null) return null;

    final paths = <CustomGeometryPath>[];
    for (final pathEl in OpenXmlUtils.findChildren(pathLst, 'path')) {
      final w = double.tryParse(OpenXmlUtils.attr(pathEl, 'w') ?? '') ?? 0;
      final h = double.tryParse(OpenXmlUtils.attr(pathEl, 'h') ?? '') ?? 0;
      final commands = <CustomPathCommand>[];

      for (final commandEl in pathEl.childElements) {
        switch (commandEl.name.local) {
          case 'moveTo':
            final point = _parsePathPoint(
              OpenXmlUtils.findChild(commandEl, 'pt'),
            );
            if (point != null) {
              commands.add(
                CustomPathCommand(
                  type: CustomPathCommandType.moveTo,
                  point: point,
                ),
              );
            }
            break;
          case 'lnTo':
            final point = _parsePathPoint(
              OpenXmlUtils.findChild(commandEl, 'pt'),
            );
            if (point != null) {
              commands.add(
                CustomPathCommand(
                  type: CustomPathCommandType.lineTo,
                  point: point,
                ),
              );
            }
            break;
          case 'cubicBezTo':
            final points = OpenXmlUtils.findChildren(
              commandEl,
              'pt',
            ).map(_parsePathPoint).whereType<Offset>().toList();
            if (points.length == 3) {
              commands.add(
                CustomPathCommand(
                  type: CustomPathCommandType.cubicTo,
                  control1: points[0],
                  control2: points[1],
                  point: points[2],
                ),
              );
            }
            break;
          case 'close':
            commands.add(
              const CustomPathCommand(type: CustomPathCommandType.close),
            );
            break;
        }
      }

      if (w > 0 && h > 0 && commands.isNotEmpty) {
        paths.add(CustomGeometryPath(size: Size(w, h), commands: commands));
      }
    }

    if (paths.isEmpty) return null;
    return CustomGeometry(paths: paths);
  }

  Offset? _parsePathPoint(XmlElement? pt) {
    if (pt == null) return null;
    final x = double.tryParse(OpenXmlUtils.attr(pt, 'x') ?? '');
    final y = double.tryParse(OpenXmlUtils.attr(pt, 'y') ?? '');
    if (x == null || y == null) return null;
    return Offset(x, y);
  }

  String? _transitionChildName(XmlElement transition) {
    for (final child in transition.childElements) {
      return child.name.local;
    }
    return OpenXmlUtils.attr(transition, 'type');
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

  // ---------------------------------------------------------------------------
  // Package plumbing (relationships + media)
  // ---------------------------------------------------------------------------

  Map<String, Map<String, String>> _buildRelsMap(Archive archive) {
    final map = <String, Map<String, String>>{};
    for (final file in archive.files) {
      if (!file.name.endsWith('.rels')) continue;
      final doc = XmlDocument.parse(String.fromCharCodes(file.content));
      final rels = <String, String>{};
      for (final rel in doc.rootElement.childElements) {
        if (rel.name.local != 'Relationship') continue;
        final id = OpenXmlUtils.attr(rel, 'Id');
        final target = OpenXmlUtils.attr(rel, 'Target');
        if (id != null && target != null) {
          rels[id] = _resolveRelationshipTarget(file.name, target);
        }
      }
      map[file.name] = rels;
    }
    return map;
  }

  String? _findTarget(String relsPath, String dirNeedle) {
    final m = _relsMap[relsPath];
    if (m == null) return null;
    for (final target in m.values) {
      if (target.contains(dirNeedle)) return target;
    }
    return null;
  }

  Future<Map<String, String>> _extractMediaFiles(Archive archive) async {
    final mediaEntries = archive.files.where(
      (file) => file.name.startsWith('ppt/media/') && !file.isDirectory,
    );
    if (mediaEntries.isEmpty) return const {};
    final outputDir = await Directory.systemTemp.createTemp(
      'powerx_pptx_media_',
    );
    final mediaFiles = <String, String>{};
    for (final entry in mediaEntries) {
      final fileName = entry.name.split('/').last;
      final outputFile = File('${outputDir.path}/$fileName');
      await outputFile.writeAsBytes(List<int>.from(entry.content));
      mediaFiles[entry.name] = outputFile.path;
    }
    return mediaFiles;
  }

  String _resolveRelationshipTarget(String relsPath, String target) {
    if (target.startsWith('http://') || target.startsWith('https://')) {
      return target;
    }
    final normalizedTarget = target.replaceAll('\\', '/');
    if (normalizedTarget.startsWith('/')) {
      return _normalizePath(normalizedTarget.substring(1));
    }
    final sourcePath = _sourcePathForRels(relsPath);
    final sourceDir = sourcePath.contains('/')
        ? sourcePath.substring(0, sourcePath.lastIndexOf('/'))
        : '';
    return _normalizePath(
      sourceDir.isEmpty ? normalizedTarget : '$sourceDir/$normalizedTarget',
    );
  }

  String _sourcePathForRels(String relsPath) {
    final normalized = relsPath.replaceAll('\\', '/');
    const relsMarker = '/_rels/';
    final markerIndex = normalized.lastIndexOf(relsMarker);
    if (markerIndex == -1 || !normalized.endsWith('.rels')) {
      return normalized;
    }
    final dir = normalized.substring(0, markerIndex);
    final fileName = normalized.substring(markerIndex + relsMarker.length);
    return '$dir/${fileName.substring(0, fileName.length - 5)}';
  }

  String _relsPathForPart(String partPath) {
    final normalized = partPath.replaceAll('\\', '/');
    final slashIndex = normalized.lastIndexOf('/');
    final dir = slashIndex == -1 ? '' : normalized.substring(0, slashIndex);
    final fileName = slashIndex == -1
        ? normalized
        : normalized.substring(slashIndex + 1);
    return dir.isEmpty ? '_rels/$fileName.rels' : '$dir/_rels/$fileName.rels';
  }

  String _normalizePath(String path) {
    final parts = <String>[];
    for (final part in path.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else {
        parts.add(part);
      }
    }
    return parts.join('/');
  }
}

// =============================================================================
// Internal resolved structures
// =============================================================================

class _Xfrm {
  final Offset? off;
  final Size? ext;
  final double rot;
  final bool flipH;
  final bool flipV;
  const _Xfrm({
    this.off,
    this.ext,
    this.rot = 0.0,
    this.flipH = false,
    this.flipV = false,
  });
}

class _LevelStyle {
  double? size;
  Color? color;
  String? font;
  bool? bold;
  bool? italic;
  TextAlign? align;
}

class _ListStyle {
  final Map<int, _LevelStyle> levels = {};
  _LevelStyle? at(int level) => levels[level] ?? levels[0];
}

class _Ph {
  final String type;
  final String idx;
  final Offset? off;
  final Size? size;
  final double rot;
  final _ListStyle lstStyle;
  _Ph({
    required this.type,
    required this.idx,
    required this.off,
    required this.size,
    required this.rot,
    required this.lstStyle,
  });
}

class _Master {
  final String path;
  final ColorScheme scheme;
  final FontScheme fonts;
  final XmlElement? bg;
  final List<_Ph> placeholders;
  final List<XmlElement> decorative;
  final _ListStyle titleStyle;
  final _ListStyle bodyStyle;
  final _ListStyle otherStyle;
  _Master({
    required this.path,
    required this.scheme,
    required this.fonts,
    required this.bg,
    required this.placeholders,
    required this.decorative,
    required this.titleStyle,
    required this.bodyStyle,
    required this.otherStyle,
  });
}

class _Layout {
  final String path;
  final String masterPath;
  final XmlElement? bg;
  final List<_Ph> placeholders;
  final List<XmlElement> decorative;
  _Layout({
    required this.path,
    required this.masterPath,
    required this.bg,
    required this.placeholders,
    required this.decorative,
  });
}
