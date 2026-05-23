import 'dart:ui';
import 'package:xml/xml.dart';

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
        if (nsUri == null ||
            attr.name.namespaceUri == null ||
            attr.name.namespaceUri == nsUri) {
          return attr.value;
        }
      }
    }
    return null;
  }

  static Color? parseColor(XmlElement? colorElement) {
    if (colorElement == null) return null;

    final srgb = attr(colorElement, 'val');
    if (srgb != null && srgb.length == 6) {
      return Color(int.parse('FF\$srgb', radix: 16));
    }

    final schemeClr = findChild(colorElement, 'schemeClr');
    if (schemeClr != null) {
      final scheme = attr(schemeClr, 'val');
      const schemeMap = {
        'tx1': 0xFF000000,
        'bg1': 0xFFFFFFFF,
        'accent1': 0xFF4472C4,
        'accent2': 0xFFED7D31,
        'accent3': 0xFFA5A5A5,
        'accent4': 0xFFFFC000,
        'accent5': 0xFF5B9BD5,
        'accent6': 0xFF70AD47,
      };
      if (schemeMap.containsKey(scheme)) {
        return Color(schemeMap[scheme]!);
      }
    }

    return null;
  }

  static int parseEmu(String? value) {
    if (value == null) return 0;
    return (int.parse(value) / 914400 * 96).round();
  }

  static int parsePt(String? value) {
    if (value == null) return 0;
    return (int.parse(value) / 100).round();
  }

  static String colorToHex(Color color) {
    return color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
  }
}
