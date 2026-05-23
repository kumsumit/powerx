import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../models/presentation.dart';
import '../models/elements.dart';
import '../models/text_styles.dart';
import '../models/table.dart';
import '../models/chart.dart';
import '../models/animation.dart';
import '../models/theme.dart';
import 'openxml_utils.dart';

class PptxExporter {
  Future<void> export(Presentation presentation, String outputPath) async {
    final archive = Archive();

    // Add [Content_Types].xml
    _addTextFile(archive, '[Content_Types].xml', _buildContentTypes());

    // Add .rels
    _addTextFile(archive, '_rels/.rels', _buildRels());

    // Add presentation.xml
    _addTextFile(
      archive,
      'ppt/presentation.xml',
      _buildPresentation(presentation),
    );

    // Add presentation.xml.rels
    _addTextFile(
      archive,
      'ppt/_rels/presentation.xml.rels',
      _buildPresentationRels(presentation),
    );

    // Add slides
    for (int i = 0; i < presentation.slides.length; i++) {
      final slide = presentation.slides[i];
      _addTextFile(archive, 'ppt/slides/slide${i + 1}.xml', _buildSlide(slide));
      _addTextFile(
        archive,
        'ppt/slides/_rels/slide${i + 1}.xml.rels',
        _buildSlideRels(i + 1),
      );
    }

    // Add theme
    _addTextFile(
      archive,
      'ppt/theme/theme1.xml',
      _buildTheme(presentation.theme),
    );

    // Write output
    final encoder = ZipEncoder();
    final output = encoder.encode(archive);
    await File(outputPath).writeAsBytes(output);
  }

  void _addTextFile(Archive archive, String path, String content) {
    final bytes = Uint8List.fromList(content.codeUnits);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  String _buildContentTypes() {
    final builder = XmlBuilder();
    builder.processing(
      'xml',
      'version="1.0" encoding="UTF-8" standalone="yes"',
    );
    builder.element(
      'Types',
      nest: () {
        builder.attribute(
          'xmlns',
          'http://schemas.openxmlformats.org/package/2006/content-types',
        );
        builder.element(
          'Default',
          attributes: {
            'Extension': 'rels',
            'ContentType':
                'application/vnd.openxmlformats-package.relationships+xml',
          },
        );
        builder.element(
          'Default',
          attributes: {'Extension': 'xml', 'ContentType': 'application/xml'},
        );
        builder.element(
          'Override',
          attributes: {
            'PartName': '/ppt/presentation.xml',
            'ContentType':
                'application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml',
          },
        );
        builder.element(
          'Override',
          attributes: {
            'PartName': '/ppt/theme/theme1.xml',
            'ContentType':
                'application/vnd.openxmlformats-officedocument.theme+xml',
          },
        );
        for (int i = 1; i <= 20; i++) {
          builder.element(
            'Override',
            attributes: {
              'PartName': '/ppt/slides/slide$i.xml',
              'ContentType':
                  'application/vnd.openxmlformats-officedocument.presentationml.slide+xml',
            },
          );
        }
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }

  String _buildRels() {
    final builder = XmlBuilder();
    builder.processing(
      'xml',
      'version="1.0" encoding="UTF-8" standalone="yes"',
    );
    builder.element(
      'Relationships',
      nest: () {
        builder.attribute(
          'xmlns',
          'http://schemas.openxmlformats.org/package/2006/relationships',
        );
        builder.element(
          'Relationship',
          attributes: {
            'Id': 'rId1',
            'Type':
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument',
            'Target': 'ppt/presentation.xml',
          },
        );
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }

  String _buildPresentation(Presentation pres) {
    final builder = XmlBuilder();
    builder.processing(
      'xml',
      'version="1.0" encoding="UTF-8" standalone="yes"',
    );
    builder.element(
      'p:presentation',
      nest: () {
        builder.namespace(
          'http://schemas.openxmlformats.org/presentationml/2006/main',
          'p',
        );
        builder.namespace(
          'http://schemas.openxmlformats.org/drawingml/2006/main',
          'a',
        );
        builder.namespace(
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
          'r',
        );

        builder.element(
          'p:sldSz',
          attributes: {
            'cx': (pres.settings.slideSize.width * 914400 / 96)
                .round()
                .toString(),
            'cy': (pres.settings.slideSize.height * 914400 / 96)
                .round()
                .toString(),
            'type': 'screen4x3',
          },
        );
        builder.element(
          'p:notesSz',
          attributes: {'cx': '6858000', 'cy': '9144000'},
        );

        builder.element(
          'p:sldIdLst',
          nest: () {
            for (int i = 0; i < pres.slides.length; i++) {
              builder.element(
                'p:sldId',
                attributes: {'id': (256 + i).toString(), 'r:id': 'rId${i + 1}'},
              );
            }
          },
        );
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }

  String _buildPresentationRels(Presentation pres) {
    final builder = XmlBuilder();
    builder.processing(
      'xml',
      'version="1.0" encoding="UTF-8" standalone="yes"',
    );
    builder.element(
      'Relationships',
      nest: () {
        builder.attribute(
          'xmlns',
          'http://schemas.openxmlformats.org/package/2006/relationships',
        );
        for (int i = 0; i < pres.slides.length; i++) {
          builder.element(
            'Relationship',
            attributes: {
              'Id': 'rId${i + 1}',
              'Type':
                  'http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide',
              'Target': 'slides/slide${i + 1}.xml',
            },
          );
        }
        builder.element(
          'Relationship',
          attributes: {
            'Id': 'rIdTheme',
            'Type':
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme',
            'Target': 'theme/theme1.xml',
          },
        );
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }

  String _buildSlideRels(int slideNum) {
    final builder = XmlBuilder();
    builder.processing(
      'xml',
      'version="1.0" encoding="UTF-8" standalone="yes"',
    );
    builder.element(
      'Relationships',
      nest: () {
        builder.attribute(
          'xmlns',
          'http://schemas.openxmlformats.org/package/2006/relationships',
        );
        builder.element(
          'Relationship',
          attributes: {
            'Id': 'rId1',
            'Type':
                'http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout',
            'Target': '../slideLayouts/slideLayout1.xml',
          },
        );
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }

  String _buildSlide(Slide slide) {
    final builder = XmlBuilder();
    builder.processing(
      'xml',
      'version="1.0" encoding="UTF-8" standalone="yes"',
    );
    builder.element(
      'p:sld',
      nest: () {
        builder.namespace(
          'http://schemas.openxmlformats.org/presentationml/2006/main',
          'p',
        );
        builder.namespace(
          'http://schemas.openxmlformats.org/drawingml/2006/main',
          'a',
        );
        builder.namespace(
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
          'r',
        );

        builder.element(
          'p:cSld',
          nest: () {
            // Background
            if (slide.backgroundColorOverride != null) {
              builder.element(
                'p:bg',
                nest: () {
                  builder.element(
                    'p:bgPr',
                    nest: () {
                      builder.element(
                        'a:solidFill',
                        nest: () {
                          builder.element(
                            'a:srgbClr',
                            attributes: {
                              'val': OpenXmlUtils.colorToHex(
                                slide.backgroundColorOverride!,
                              ),
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            }

            builder.element(
              'p:spTree',
              nest: () {
                builder.element(
                  'p:nvGrpSpPr',
                  nest: () {
                    builder.element(
                      'p:cNvPr',
                      attributes: {'id': '1', 'name': ''},
                    );
                    builder.element('p:cNvGrpSpPr');
                    builder.element('p:nvPr');
                  },
                );
                builder.element(
                  'p:grpSpPr',
                  nest: () {
                    builder.element(
                      'a:xfrm',
                      nest: () {
                        builder.element(
                          'a:off',
                          attributes: {'x': '0', 'y': '0'},
                        );
                        builder.element(
                          'a:ext',
                          attributes: {'cx': '0', 'cy': '0'},
                        );
                        builder.element(
                          'a:chOff',
                          attributes: {'x': '0', 'y': '0'},
                        );
                        builder.element(
                          'a:chExt',
                          attributes: {'cx': '0', 'cy': '0'},
                        );
                      },
                    );
                  },
                );

                for (final element in slide.elements) {
                  _writeElement(builder, element);
                }
              },
            );
          },
        );

        // Transition
        if (slide.transition.type != TransitionType.none) {
          builder.element(
            'p:transition',
            attributes: {
              'dur': slide.transition.duration.inMilliseconds.toString(),
            },
          );
        }
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }

  void _writeElement(XmlBuilder builder, SlideElement element) {
    if (element is TextElement) {
      _writeTextElement(builder, element);
    } else if (element is ShapeElement) {
      _writeShapeElement(builder, element);
    } else if (element is ImageElement) {
      _writeImageElement(builder, element);
    } else if (element is TableElement) {
      _writeTableElement(builder, element);
    } else if (element is ChartElement) {
      _writeChartElement(builder, element);
    }
  }

  void _writeTextElement(XmlBuilder builder, TextElement element) {
    builder.element(
      'p:sp',
      nest: () {
        builder.element(
          'p:nvSpPr',
          nest: () {
            builder.element(
              'p:cNvPr',
              attributes: {'id': element.id, 'name': element.name ?? 'TextBox'},
            );
            builder.element(
              'p:cNvSpPr',
              nest: () {
                builder.element('a:spLocks', attributes: {'noGrp': '1'});
              },
            );
            builder.element('p:nvPr');
          },
        );

        builder.element(
          'p:spPr',
          nest: () {
            _writeTransform(builder, element);
            _writeFill(builder, element.fillColor);
            if (element.borderWidth != null && element.borderWidth! > 0) {
              _writeLine(builder, element.borderColor, element.borderWidth);
            }
          },
        );

        builder.element(
          'p:txBody',
          nest: () {
            builder.element(
              'a:bodyPr',
              attributes: {
                'wrap': element.wrapText ? 'square' : 'none',
                'lIns': '91440',
                'tIns': '45720',
                'rIns': '91440',
                'bIns': '45720',
              },
            );
            builder.element('a:lstStyle');
            for (final para in element.paragraphs) {
              _writeParagraph(builder, para);
            }
          },
        );
      },
    );
  }

  void _writeShapeElement(XmlBuilder builder, ShapeElement element) {
    builder.element(
      'p:sp',
      nest: () {
        builder.element(
          'p:nvSpPr',
          nest: () {
            builder.element(
              'p:cNvPr',
              attributes: {'id': element.id, 'name': element.name ?? 'Shape'},
            );
            builder.element('p:cNvSpPr');
            builder.element('p:nvPr');
          },
        );

        builder.element(
          'p:spPr',
          nest: () {
            _writeTransform(builder, element);
            _writeFill(builder, element.fillColor);
            if (element.strokeWidth > 0) {
              _writeLine(builder, element.strokeColor, element.strokeWidth);
            }

            String prstName;
            switch (element.shapeType) {
              case ShapeType.circle:
                prstName = 'ellipse';
                break;
              case ShapeType.roundedRectangle:
                prstName = 'roundRect';
                break;
              case ShapeType.triangle:
                prstName = 'triangle';
                break;
              case ShapeType.diamond:
                prstName = 'diamond';
                break;
              case ShapeType.pentagon:
                prstName = 'pentagon';
                break;
              case ShapeType.hexagon:
                prstName = 'hexagon';
                break;
              case ShapeType.star:
                prstName = 'star5';
                break;
              case ShapeType.arrow:
                prstName = 'arrow';
                break;
              default:
                prstName = 'rect';
            }

            builder.element(
              'a:prstGeom',
              attributes: {'prst': prstName},
              nest: () {
                builder.element('a:avLst');
              },
            );
          },
        );
      },
    );
  }

  void _writeImageElement(XmlBuilder builder, ImageElement element) {
    builder.element(
      'p:pic',
      nest: () {
        builder.element(
          'p:nvPicPr',
          nest: () {
            builder.element(
              'p:cNvPr',
              attributes: {'id': element.id, 'name': element.name ?? 'Picture'},
            );
            builder.element(
              'p:cNvPicPr',
              nest: () {
                builder.element(
                  'a:picLocks',
                  attributes: {'noChangeAspect': '1'},
                );
              },
            );
            builder.element('p:nvPr');
          },
        );

        builder.element(
          'p:blipFill',
          nest: () {
            builder.element(
              'a:blip',
              attributes: {'r:embed': 'rIdImg${element.id}'},
            );
            builder.element(
              'a:stretch',
              nest: () {
                builder.element('a:fillRect');
              },
            );
          },
        );

        builder.element(
          'p:spPr',
          nest: () {
            _writeTransform(builder, element);
            builder.element(
              'a:prstGeom',
              attributes: {'prst': 'rect'},
              nest: () {
                builder.element('a:avLst');
              },
            );
          },
        );
      },
    );
  }

  void _writeTableElement(XmlBuilder builder, TableElement element) {
    builder.element(
      'p:graphicFrame',
      nest: () {
        builder.element(
          'p:nvGraphicFramePr',
          nest: () {
            builder.element(
              'p:cNvPr',
              attributes: {'id': element.id, 'name': 'Table'},
            );
            builder.element('p:cNvGraphicFramePr');
            builder.element('p:nvPr');
          },
        );

        builder.element(
          'p:xfrm',
          nest: () {
            builder.element(
              'a:off',
              attributes: {
                'x': _emu(element.position.dx),
                'y': _emu(element.position.dy),
              },
            );
            builder.element(
              'a:ext',
              attributes: {
                'cx': _emu(element.size.width),
                'cy': _emu(element.size.height),
              },
            );
          },
        );

        builder.element(
          'a:graphic',
          nest: () {
            builder.element(
              'a:graphicData',
              attributes: {
                'uri': 'http://schemas.openxmlformats.org/drawingml/2006/table',
              },
              nest: () {
                builder.element(
                  'a:tbl',
                  nest: () {
                    builder.element(
                      'a:tblPr',
                      attributes: {'bandRow': element.bandedRows ? '1' : '0'},
                    );
                    builder.element(
                      'a:tblGrid',
                      nest: () {
                        for (final col in element.columns) {
                          builder.element(
                            'a:gridCol',
                            attributes: {'w': _emu(col.width)},
                          );
                        }
                      },
                    );
                    for (final row in element.rows) {
                      builder.element(
                        'a:tr',
                        attributes: {'h': _emu(row.height)},
                        nest: () {
                          for (final cell in element.cells.where(
                            (c) => c.rowId == row.id,
                          )) {
                            builder.element(
                              'a:tc',
                              nest: () {
                                if (cell.colSpan > 1) {
                                  builder.element(
                                    'a:tcPr',
                                    attributes: {
                                      'gridSpan': cell.colSpan.toString(),
                                    },
                                  );
                                }
                                builder.element(
                                  'a:txBody',
                                  nest: () {
                                    builder.element('a:bodyPr');
                                    builder.element('a:lstStyle');
                                    for (final para in cell.paragraphs) {
                                      _writeParagraph(builder, para);
                                    }
                                  },
                                );
                              },
                            );
                          }
                        },
                      );
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _writeChartElement(XmlBuilder builder, ChartElement element) {
    builder.element(
      'p:graphicFrame',
      nest: () {
        builder.element(
          'p:nvGraphicFramePr',
          nest: () {
            builder.element(
              'p:cNvPr',
              attributes: {'id': element.id, 'name': 'Chart'},
            );
            builder.element('p:cNvGraphicFramePr');
            builder.element('p:nvPr');
          },
        );

        builder.element(
          'p:xfrm',
          nest: () {
            builder.element(
              'a:off',
              attributes: {
                'x': _emu(element.position.dx),
                'y': _emu(element.position.dy),
              },
            );
            builder.element(
              'a:ext',
              attributes: {
                'cx': _emu(element.size.width),
                'cy': _emu(element.size.height),
              },
            );
          },
        );

        builder.element(
          'a:graphic',
          nest: () {
            builder.element(
              'a:graphicData',
              attributes: {
                'uri': 'http://schemas.openxmlformats.org/drawingml/2006/chart',
              },
              nest: () {
                builder.element(
                  'c:chart',
                  attributes: {
                    'xmlns:c':
                        'http://schemas.openxmlformats.org/drawingml/2006/chart',
                    'r:id': 'rIdChart${element.id}',
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _writeTransform(XmlBuilder builder, SlideElement element) {
    builder.element(
      'a:xfrm',
      nest: () {
        builder.element(
          'a:off',
          attributes: {
            'x': _emu(element.position.dx),
            'y': _emu(element.position.dy),
          },
        );
        builder.element(
          'a:ext',
          attributes: {
            'cx': _emu(element.size.width),
            'cy': _emu(element.size.height),
          },
        );
      },
    );
  }

  void _writeFill(XmlBuilder builder, Color? color) {
    if (color == null) {
      builder.element('a:noFill');
      return;
    }
    builder.element(
      'a:solidFill',
      nest: () {
        builder.element(
          'a:srgbClr',
          attributes: {'val': OpenXmlUtils.colorToHex(color)},
        );
      },
    );
  }

  void _writeLine(XmlBuilder builder, Color? color, double? width) {
    builder.element(
      'a:ln',
      attributes: {
        'w': width != null ? (width * 12700).round().toString() : '12700',
      },
      nest: () {
        if (color != null) {
          builder.element(
            'a:solidFill',
            nest: () {
              builder.element(
                'a:srgbClr',
                attributes: {'val': OpenXmlUtils.colorToHex(color)},
              );
            },
          );
        }
      },
    );
  }

  void _writeParagraph(XmlBuilder builder, RichParagraph para) {
    builder.element(
      'a:p',
      nest: () {
        if (para.style.alignment != TextAlign.left) {
          String algn;
          switch (para.style.alignment) {
            case TextAlign.center:
              algn = 'ctr';
              break;
            case TextAlign.right:
              algn = 'r';
              break;
            case TextAlign.justify:
              algn = 'just';
              break;
            default:
              algn = 'l';
          }
          builder.element('a:pPr', attributes: {'algn': algn});
        }

        for (final run in para.runs) {
          builder.element(
            'a:r',
            nest: () {
              builder.element(
                'a:rPr',
                attributes: {
                  'sz': (run.fontSize * 100).round().toString(),
                  'b': run.bold ? '1' : '0',
                  'i': run.italic ? '1' : '0',
                  'u': run.underline ? 'sng' : 'none',
                  'strike': run.strikethrough ? 'sngStrike' : 'noStrike',
                },
                nest: () {
                  builder.element(
                    'a:solidFill',
                    nest: () {
                      builder.element(
                        'a:srgbClr',
                        attributes: {'val': OpenXmlUtils.colorToHex(run.color)},
                      );
                    },
                  );
                  builder.element(
                    'a:latin',
                    attributes: {'typeface': run.fontFamily},
                  );
                },
              );
              builder.element(
                'a:t',
                nest: () {
                  builder.text(run.text);
                },
              );
            },
          );
        }
        builder.element('a:endParaRPr');
      },
    );
  }

  String _emu(double pixels) => (pixels * 914400 / 96).round().toString();

  String _buildTheme(PresentationTheme theme) {
    final builder = XmlBuilder();
    builder.processing(
      'xml',
      'version="1.0" encoding="UTF-8" standalone="yes"',
    );
    builder.element(
      'a:theme',
      nest: () {
        builder.namespace(
          'http://schemas.openxmlformats.org/drawingml/2006/main',
          'a',
        );
        builder.attribute('name', theme.name);

        builder.element(
          'a:themeElements',
          nest: () {
            builder.element(
              'a:clrScheme',
              attributes: {
                'name': theme.colors.text1.toARGB32().toRadixString(16),
              },
              nest: () {
                _writeSchemeColor(builder, 'dk1', theme.colors.text1);
                _writeSchemeColor(builder, 'lt1', theme.colors.background1);
                _writeSchemeColor(builder, 'accent1', theme.colors.accent1);
                _writeSchemeColor(builder, 'accent2', theme.colors.accent2);
                _writeSchemeColor(builder, 'accent3', theme.colors.accent3);
                _writeSchemeColor(builder, 'accent4', theme.colors.accent4);
                _writeSchemeColor(builder, 'accent5', theme.colors.accent5);
                _writeSchemeColor(builder, 'accent6', theme.colors.accent6);
                _writeSchemeColor(builder, 'hlink', theme.colors.hyperlink);
                _writeSchemeColor(
                  builder,
                  'folHlink',
                  theme.colors.followedHyperlink,
                );
              },
            );

            builder.element(
              'a:fontScheme',
              attributes: {'name': 'Office'},
              nest: () {
                builder.element(
                  'a:majorFont',
                  nest: () {
                    builder.element(
                      'a:latin',
                      attributes: {'typeface': theme.fonts.majorFont},
                    );
                  },
                );
                builder.element(
                  'a:minorFont',
                  nest: () {
                    builder.element(
                      'a:latin',
                      attributes: {'typeface': theme.fonts.minorFont},
                    );
                  },
                );
              },
            );

            builder.element(
              'a:fmtScheme',
              attributes: {'name': 'Office'},
              nest: () {
                builder.element('a:fillStyleLst');
                builder.element('a:lnStyleLst');
                builder.element('a:effectStyleLst');
                builder.element('a:bgFillStyleLst');
              },
            );
          },
        );
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }

  void _writeSchemeColor(XmlBuilder builder, String name, Color color) {
    builder.element(
      'a:$name',
      nest: () {
        builder.element(
          'a:srgbClr',
          attributes: {'val': OpenXmlUtils.colorToHex(color)},
        );
      },
    );
  }
}
