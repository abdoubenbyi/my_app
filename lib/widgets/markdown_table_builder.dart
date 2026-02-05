import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;

class MarkdownTableBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  MarkdownTableBuilder(this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag != 'table') return null;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.black.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildTable(element),
        ),
      ),
    );
  }

  Widget _buildTable(md.Element element) {
    List<TableRow> rows = [];

    for (var container in element.children ?? []) {
      if (container is md.Element) {
        if (container.tag == 'thead' || container.tag == 'tbody') {
          for (var row in container.children ?? []) {
            if (row is md.Element && row.tag == 'tr') {
              rows.add(_buildRow(row, container.tag == 'thead'));
            }
          }
        }
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: rows,
    );
  }

  TableRow _buildRow(md.Element row, bool isHeader) {
    List<Widget> cells = [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    for (var cell in row.children ?? []) {
      if (cell is md.Element && (cell.tag == 'td' || cell.tag == 'th')) {
        cells.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: _buildCellContent(cell, isHeader, isDark),
          ),
        );
      }
    }

    return TableRow(
      decoration: BoxDecoration(
        color: isHeader
            ? (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05))
            : null,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      children: cells,
    );
  }

  Widget _buildCellContent(md.Element cell, bool isHeader, bool isDark) {
    String text = cell.textContent;

    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: isHeader ? FontWeight.w700 : FontWeight.normal,
        color: isHeader
            ? (isDark ? Colors.white : Colors.black)
            : (isDark ? Colors.white70 : Colors.black87),
      ),
    );
  }
}
