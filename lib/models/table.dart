import 'package:equatable/equatable.dart';
import 'package:flutter/rendering.dart';
import 'elements.dart';
import 'text_styles.dart';

class TableElement extends SlideElement {
  final List<TableRow> rows;
  final List<TableColumn> columns;
  final List<TableCell> cells;
  final TableStyle? tableStyle;
  final bool bandedRows;
  final bool bandedColumns;
  final bool firstRowHeader;
  final bool firstColumnHeader;

  const TableElement({
    required super.id,
    required super.position,
    required super.size,
    super.rotation,
    super.isLocked,
    required super.zIndex,
    super.name,
    super.hidden,
    required this.rows,
    required this.columns,
    required this.cells,
    this.tableStyle,
    this.bandedRows = true,
    this.bandedColumns = false,
    this.firstRowHeader = true,
    this.firstColumnHeader = false,
  });

  @override
  TableElement copyWith({
    Offset? position,
    Size? size,
    double? rotation,
    bool? isLocked,
    int? zIndex,
    String? name,
    bool? hidden,
    List<TableRow>? rows,
    List<TableColumn>? columns,
    List<TableCell>? cells,
    TableStyle? tableStyle,
    bool? bandedRows,
    bool? bandedColumns,
    bool? firstRowHeader,
    bool? firstColumnHeader,
  }) => TableElement(
    id: id,
    position: position ?? this.position,
    size: size ?? this.size,
    rotation: rotation ?? this.rotation,
    isLocked: isLocked ?? this.isLocked,
    zIndex: zIndex ?? this.zIndex,
    name: name ?? this.name,
    hidden: hidden ?? this.hidden,
    rows: rows ?? this.rows,
    columns: columns ?? this.columns,
    cells: cells ?? this.cells,
    tableStyle: tableStyle ?? this.tableStyle,
    bandedRows: bandedRows ?? this.bandedRows,
    bandedColumns: bandedColumns ?? this.bandedColumns,
    firstRowHeader: firstRowHeader ?? this.firstRowHeader,
    firstColumnHeader: firstColumnHeader ?? this.firstColumnHeader,
  );

  @override
  List<Object?> get props => [id, rows, columns, cells, zIndex];
}

class TableRow extends Equatable {
  final String id;
  final double height;
  const TableRow({required this.id, this.height = 30});
  @override
  List<Object?> get props => [id, height];
}

class TableColumn extends Equatable {
  final String id;
  final double width;
  const TableColumn({required this.id, this.width = 100});
  @override
  List<Object?> get props => [id, width];
}

class TableCell extends Equatable {
  final String id;
  final String rowId;
  final String colId;
  final int rowSpan;
  final int colSpan;
  final List<RichParagraph> paragraphs;
  final Color? fillColor;
  final EdgeInsets margins;
  final BorderProperties? borders;
  final VerticalAlignment verticalAlign;

  const TableCell({
    required this.id,
    required this.rowId,
    required this.colId,
    this.rowSpan = 1,
    this.colSpan = 1,
    this.paragraphs = const [],
    this.fillColor,
    this.margins = const EdgeInsets.all(4),
    this.borders,
    this.verticalAlign = VerticalAlignment.middle,
  });

  @override
  List<Object?> get props => [
    id,
    rowId,
    colId,
    rowSpan,
    colSpan,
    paragraphs,
    fillColor,
  ];
}

class TableStyle extends Equatable {
  final String name;
  const TableStyle({this.name = 'Table Grid'});
  @override
  List<Object?> get props => [name];
}

class BorderProperties extends Equatable {
  final BorderSide? top;
  final BorderSide? bottom;
  final BorderSide? left;
  final BorderSide? right;
  final BorderSide? insideH;
  final BorderSide? insideV;
  const BorderProperties({
    this.top,
    this.bottom,
    this.left,
    this.right,
    this.insideH,
    this.insideV,
  });
  @override
  List<Object?> get props => [top, bottom, left, right, insideH, insideV];
}

enum VerticalAlignment { top, middle, bottom }
