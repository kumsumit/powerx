import 'dart:ui';
import 'package:xml/xml.dart';
import '../models/theme.dart';

/// Low-level helpers for reading the OOXML (DrawingML / PresentationML) parts of
/// a `.pptx`. The color resolution here mirrors how PowerPoint itself resolves a
/// `<a:solidFill>` etc.: a base color (srgb/scheme/sys/preset) followed by a
/// chain of modifiers (lumMod, lumOff, shade, tint, satMod, alpha).
class OpenXmlUtils {
  static String ns(String prefix) {
    const namespaces = {
      'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
      'r':
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
      'p': 'http://schemas.openxmlformats.org/presentationml/2006/main',
      'c': 'http://schemas.openxmlformats.org/drawingml/2006/chart',
      'm': 'http://schemas.openxmlformats.org/officeDocument/2006/math',
      'wp':
          'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing',
    };
    return namespaces[prefix] ?? '';
  }

  static XmlElement? findChild(
    XmlElement? parent,
    String name, {
    String? nsPrefix,
  }) {
    if (parent == null) return null;
    final nsUri = nsPrefix != null ? ns(nsPrefix) : null;
    for (final child in parent.childElements) {
      if (child.name.local == name) {
        if (nsUri == null || child.name.namespaceUri == nsUri) {
          return child;
        }
      }
    }
    return null;
  }

  static List<XmlElement> findChildren(
    XmlElement? parent,
    String name, {
    String? nsPrefix,
  }) {
    if (parent == null) return const [];
    final nsUri = nsPrefix != null ? ns(nsPrefix) : null;
    return parent.childElements.where((c) {
      return c.name.local == name &&
          (nsUri == null || c.name.namespaceUri == nsUri);
    }).toList();
  }

  static String? attr(XmlElement? element, String name, {String? nsPrefix}) {
    if (element == null) return null;
    final nsUri = nsPrefix != null ? ns(nsPrefix) : null;
    for (final attr in element.attributes) {
      if (attr.name.local == name) {
        if (nsUri == null || attr.name.namespaceUri == nsUri) {
          return attr.value;
        }
      }
    }
    return null;
  }

  /// The DrawingML color-choice element tags, in the order they may appear.
  static const _colorChoiceTags = {
    'scrgbClr',
    'srgbClr',
    'hslClr',
    'sysClr',
    'schemeClr',
    'prstClr',
  };

  /// Returns the first color-choice child of [parent] (e.g. the `<a:srgbClr>`
  /// inside a `<a:solidFill>`), or null if there is none.
  static XmlElement? colorChild(XmlElement? parent) {
    if (parent == null) return null;
    for (final child in parent.childElements) {
      if (_colorChoiceTags.contains(child.name.local)) return child;
    }
    return null;
  }

  /// Resolves the color held directly in [parent] (a fill, line, etc.) against
  /// the supplied theme [scheme]. [phClr] is the substitution value for
  /// `<a:schemeClr val="phClr"/>` used inside style-matrix references.
  static Color? colorIn(
    XmlElement? parent, {
    required ColorScheme scheme,
    Color? phClr,
  }) {
    return resolveColor(colorChild(parent), scheme: scheme, phClr: phClr);
  }

  /// Resolves a single DrawingML color-choice element ([el] is `<a:srgbClr>`,
  /// `<a:schemeClr>`, `<a:sysClr>`, …) including its modifier children.
  static Color? resolveColor(
    XmlElement? el, {
    required ColorScheme scheme,
    Color? phClr,
  }) {
    if (el == null) return null;

    Color? base;
    switch (el.name.local) {
      case 'srgbClr':
        base = _hex(attr(el, 'val'));
        break;
      case 'scrgbClr':
        base = Color.fromARGB(
          255,
          (_pct(attr(el, 'r')) * 255).round(),
          (_pct(attr(el, 'g')) * 255).round(),
          (_pct(attr(el, 'b')) * 255).round(),
        );
        break;
      case 'sysClr':
        base = _hex(attr(el, 'lastClr')) ?? _sysColor(attr(el, 'val'));
        break;
      case 'prstClr':
        base = _presetColor(attr(el, 'val'));
        break;
      case 'hslClr':
        final h = (int.tryParse(attr(el, 'hue') ?? '0') ?? 0) / 60000.0;
        final s = _pct(attr(el, 'sat'));
        final l = _pct(attr(el, 'lum'));
        base = _hslToColor(h, s, l, 1);
        break;
      case 'schemeClr':
        base = _schemeColor(attr(el, 'val'), scheme, phClr);
        break;
    }
    if (base == null) return null;
    return _applyModifiers(base, el, scheme);
  }

  static Color _applyModifiers(Color base, XmlElement el, ColorScheme scheme) {
    double? alpha;
    double? lumMod;
    double? lumOff;
    double? satMod;
    double? shade;
    double? tint;

    for (final mod in el.childElements) {
      final v = _pct(attr(mod, 'val'));
      switch (mod.name.local) {
        case 'alpha':
          alpha = v;
          break;
        case 'lumMod':
          lumMod = v;
          break;
        case 'lumOff':
          lumOff = v;
          break;
        case 'satMod':
          satMod = v;
          break;
        case 'shade':
          shade = v;
          break;
        case 'tint':
          tint = v;
          break;
      }
    }

    var color = base;

    // Saturation / luminance modifiers operate in HSL space.
    if (lumMod != null || lumOff != null || satMod != null) {
      final hsl = _colorToHsl(color);
      var h = hsl[0];
      var s = hsl[1];
      var l = hsl[2];
      if (satMod != null) s = (s * satMod).clamp(0.0, 1.0);
      if (lumMod != null) l = l * lumMod;
      if (lumOff != null) l = l + lumOff;
      l = l.clamp(0.0, 1.0);
      color = _hslToColor(h, s, l, color.a);
    }

    // shade darkens toward black, tint lightens toward white (RGB space).
    if (shade != null) {
      color = Color.fromARGB(
        (color.a * 255).round(),
        (color.r * 255 * shade).round(),
        (color.g * 255 * shade).round(),
        (color.b * 255 * shade).round(),
      );
    }
    if (tint != null) {
      double mix(double c) => c * 255 * tint! + 255 * (1 - tint);
      color = Color.fromARGB(
        (color.a * 255).round(),
        mix(color.r).round(),
        mix(color.g).round(),
        mix(color.b).round(),
      );
    }
    if (alpha != null) {
      color = color.withValues(alpha: alpha);
    }
    return color;
  }

  static Color? _schemeColor(String? name, ColorScheme scheme, Color? phClr) {
    switch (name) {
      case 'tx1':
      case 'dk1':
        return scheme.text1;
      case 'bg1':
      case 'lt1':
        return scheme.background1;
      // The model has no dk2/lt2 slot; approximate with the primary pair.
      case 'tx2':
      case 'dk2':
        return scheme.text1;
      case 'bg2':
      case 'lt2':
        return scheme.background1;
      case 'accent1':
        return scheme.accent1;
      case 'accent2':
        return scheme.accent2;
      case 'accent3':
        return scheme.accent3;
      case 'accent4':
        return scheme.accent4;
      case 'accent5':
        return scheme.accent5;
      case 'accent6':
        return scheme.accent6;
      case 'hlink':
        return scheme.hyperlink;
      case 'folHlink':
        return scheme.followedHyperlink;
      case 'phClr':
        return phClr;
      default:
        return null;
    }
  }

  static Color? _hex(String? v) {
    if (v == null) return null;
    final h = v.replaceAll('#', '').trim();
    if (h.length != 6) return null;
    final value = int.tryParse(h, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }

  /// Modifier/percentage values are stored in thousandths of a percent.
  static double _pct(String? v) {
    if (v == null) return 1.0;
    final n = int.tryParse(v);
    if (n == null) return 1.0;
    return n / 100000.0;
  }

  static Color? _sysColor(String? name) {
    switch (name) {
      case 'window':
        return const Color(0xFFFFFFFF);
      case 'windowText':
        return const Color(0xFF000000);
      default:
        return null;
    }
  }

  static Color? _presetColor(String? name) {
    const presets = {
      'black': 0xFF000000,
      'white': 0xFFFFFFFF,
      'red': 0xFFFF0000,
      'green': 0xFF008000,
      'blue': 0xFF0000FF,
      'yellow': 0xFFFFFF00,
      'cyan': 0xFF00FFFF,
      'magenta': 0xFFFF00FF,
      'gray': 0xFF808080,
      'grey': 0xFF808080,
      'darkGray': 0xFFA9A9A9,
      'lightGray': 0xFFD3D3D3,
      'orange': 0xFFFFA500,
      'purple': 0xFF800080,
    };
    final v = presets[name];
    return v == null ? null : Color(v);
  }

  static List<double> _colorToHsl(Color c) {
    final r = c.r;
    final g = c.g;
    final b = c.b;
    final maxV = [r, g, b].reduce((a, b) => a > b ? a : b);
    final minV = [r, g, b].reduce((a, b) => a < b ? a : b);
    final l = (maxV + minV) / 2;
    double h = 0;
    double s = 0;
    final d = maxV - minV;
    if (d != 0) {
      s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV);
      if (maxV == r) {
        h = ((g - b) / d + (g < b ? 6 : 0));
      } else if (maxV == g) {
        h = (b - r) / d + 2;
      } else {
        h = (r - g) / d + 4;
      }
      h /= 6;
    }
    return [h * 360, s, l];
  }

  static Color _hslToColor(double hDeg, double s, double l, double alpha) {
    final h = (hDeg % 360) / 360.0;
    double hue2rgb(double p, double q, double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }

    double r, g, b;
    if (s == 0) {
      r = g = b = l;
    } else {
      final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      final p = 2 * l - q;
      r = hue2rgb(p, q, h + 1 / 3);
      g = hue2rgb(p, q, h);
      b = hue2rgb(p, q, h - 1 / 3);
    }
    return Color.fromARGB(
      (alpha * 255).round(),
      (r * 255).round().clamp(0, 255),
      (g * 255).round().clamp(0, 255),
      (b * 255).round().clamp(0, 255),
    );
  }

  /// English Metric Units -> logical pixels (96 DPI). 914400 EMU = 1 inch.
  static int parseEmu(String? value) {
    return parseEmuD(value).round();
  }

  static double parseEmuD(String? value) {
    if (value == null) return 0;
    final n = int.tryParse(value);
    if (n == null) return 0;
    return n / 914400 * 96;
  }

  static int parsePt(String? value) {
    if (value == null) return 0;
    return (int.parse(value) / 100).round();
  }

  static String colorToHex(Color color) {
    return color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
  }
}
