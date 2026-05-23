import 'package:flutter/material.dart';
import '../../models/table.dart' as powerx_table;

class TableWidget extends StatelessWidget {
  final powerx_table.TableElement table;
  const TableWidget({super.key, required this.table});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: table.size.width,
      height: table.size.height,
      decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
      child: Column(
        children: table.rows.map((row) {
          final rowCells = table.cells.where((c) => c.rowId == row.id).toList();
          return SizedBox(
            height: row.height,
            child: Row(
              children: rowCells.map((cell) {
                final col = table.columns.firstWhere((c) => c.id == cell.colId);
                final colSpan = cell.colSpan;
                final width = col.width * colSpan;

                return Container(
                  width: width,
                  height: row.height,
                  decoration: BoxDecoration(
                    color: cell.fillColor ?? _getBandedColor(row, table),
                    border: Border(
                      right: const BorderSide(color: Colors.grey, width: 0.5),
                      bottom: const BorderSide(color: Colors.grey, width: 0.5),
                    ),
                  ),
                  padding: cell.margins,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: _mapVerticalAlign(cell.verticalAlign),
                    children: cell.paragraphs.map((para) {
                      return RichText(
                        text: TextSpan(
                          children: para.runs.map((run) {
                            return TextSpan(
                              text: run.text,
                              style: TextStyle(
                                fontFamily: run.fontFamily,
                                fontSize: run.fontSize,
                                color: run.color,
                                fontWeight: run.bold
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontStyle: run.italic
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color? _getBandedColor(
    powerx_table.TableRow row,
    powerx_table.TableElement table,
  ) {
    if (!table.bandedRows) return null;
    final rowIndex = table.rows.indexOf(row);
    if (table.firstRowHeader && rowIndex == 0)
      return const Color(0xFF4472C4).withOpacity(0.2);
    if (rowIndex.isOdd) return Colors.grey[100];
    return null;
  }

  MainAxisAlignment _mapVerticalAlign(powerx_table.VerticalAlignment align) {
    switch (align) {
      case powerx_table.VerticalAlignment.top:
        return MainAxisAlignment.start;
      case powerx_table.VerticalAlignment.middle:
        return MainAxisAlignment.center;
      case powerx_table.VerticalAlignment.bottom:
        return MainAxisAlignment.end;
    }
  }
}
