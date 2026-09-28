import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// One titled block of a report (e.g. one branch): its data rows plus a
/// bold total row shown at the bottom.
class ReportSection {
  final String title;
  final List<List<String>> rows;
  final List<String> totalRow;

  const ReportSection({
    required this.title,
    required this.rows,
    required this.totalRow,
  });
}

/// Everything needed to render a grouped report as a PDF or Excel file.
/// Kept as plain strings so this service knows nothing about invoices,
/// sales or purchases and can be reused by any other report screen.
class ReportData {
  final String title;
  final String subtitle;
  final List<String> columns;

  /// Relative width of each column (same length as [columns]).
  final List<double> columnFlex;

  /// Indexes of columns that hold numbers (right-aligned in the PDF and
  /// written as real numeric cells in Excel so they can be summed).
  final Set<int> numericColumns;
  final List<ReportSection> sections;
  final List<String> overallRow;

  const ReportData({
    required this.title,
    required this.subtitle,
    required this.columns,
    required this.columnFlex,
    required this.numericColumns,
    required this.sections,
    required this.overallRow,
  });
}

/// Print / export helpers built on the `pdf`, `printing`, `excel` and
/// `file_saver` packages. Unlike the earlier dart:html version these work
/// on web, Android, iOS and desktop alike.
class ReportExportService {
  const ReportExportService._();

  static const PdfColor _navy = PdfColor.fromInt(0xFF0B2A5B);
  static const PdfColor _navyLight = PdfColor.fromInt(0xFF14336B);
  static const PdfColor _tint = PdfColor.fromInt(0xFFEDF1FB);

  /// Opens the system print / PDF-preview dialog for [data]. From that
  /// dialog the user can print or save the report as a PDF.
  static Future<void> printReport(ReportData data, {String? fileName}) async {
    final bytes = await _buildPdf(data);
    await Printing.layoutPdf(
      name: fileName ?? 'report',
      onLayout: (_) async => bytes,
    );
  }

  /// Builds a real .xlsx workbook from [data] and saves / downloads it.
  static Future<void> exportExcel(ReportData data, String fileName) async {
    final excel = Excel.createExcel();
    const sheetName = 'Report';
    excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
    final sheet = excel[sheetName];

    int row = 0;

    void put(int col, CellValue value, {CellStyle? style}) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        value,
        cellStyle: style,
      );
    }

    CellValue cellFor(int col, String text) {
      if (data.numericColumns.contains(col)) {
        final number = double.tryParse(text.replaceAll(',', ''));
        if (number != null) return DoubleCellValue(number);
      }
      return TextCellValue(text);
    }

    final titleStyle = CellStyle(bold: true, fontSize: 14);
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#14336B'),
    );
    final sectionStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#EDF1FB'),
    );
    final totalStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#EDF1FB'),
    );

    put(0, TextCellValue(data.title), style: titleStyle);
    row++;
    put(0, TextCellValue(data.subtitle));
    row += 2;

    for (final section in data.sections) {
      put(0, TextCellValue(section.title), style: sectionStyle);
      row++;

      for (var c = 0; c < data.columns.length; c++) {
        put(c, TextCellValue(data.columns[c]), style: headerStyle);
      }
      row++;

      for (final values in section.rows) {
        for (var c = 0; c < values.length; c++) {
          put(c, cellFor(c, values[c]));
        }
        row++;
      }

      for (var c = 0; c < section.totalRow.length; c++) {
        put(c, cellFor(c, section.totalRow[c]), style: totalStyle);
      }
      row += 2;
    }

    for (var c = 0; c < data.overallRow.length; c++) {
      put(c, cellFor(c, data.overallRow[c]), style: totalStyle);
    }

    for (var c = 0; c < data.columns.length; c++) {
      sheet.setColumnWidth(c, data.columnFlex[c] * 8 + 6);
    }

    final encoded = excel.encode();
    if (encoded == null) {
      throw Exception('Could not build the Excel file.');
    }

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: Uint8List.fromList(encoded),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  static Future<Uint8List> _buildPdf(ReportData data) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            data.title,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: _navy,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            data.subtitle,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          for (final section in data.sections) ...[
            pw.SizedBox(height: 16),
            pw.Container(
              width: double.infinity,
              color: _navy,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 5),
              child: pw.Text(
                section.title,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            _table(data, section),
          ],
          pw.SizedBox(height: 16),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _tint,
              border: pw.Border.all(color: PdfColors.blue200, width: 1.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              data.overallRow
                  .where((cell) => cell.isNotEmpty)
                  .join('     |     '),
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _table(ReportData data, ReportSection section) {
    pw.Widget cell(int col, String text,
        {bool bold = false, PdfColor? color}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: pw.Text(
          text,
          textAlign: data.numericColumns.contains(col)
              ? pw.TextAlign.right
              : pw.TextAlign.left,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        for (var i = 0; i < data.columnFlex.length; i++)
          i: pw.FlexColumnWidth(data.columnFlex[i]),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _navyLight),
          children: [
            for (var c = 0; c < data.columns.length; c++)
              cell(c, data.columns[c], bold: true, color: PdfColors.white),
          ],
        ),
        for (final values in section.rows)
          pw.TableRow(
            children: [
              for (var c = 0; c < values.length; c++) cell(c, values[c]),
            ],
          ),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _tint),
          children: [
            for (var c = 0; c < section.totalRow.length; c++)
              cell(c, section.totalRow[c], bold: true),
          ],
        ),
      ],
    );
  }
}