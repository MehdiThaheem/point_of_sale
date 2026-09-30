import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// One line of the balance sheet (label + amount), plus the optional
// breakdown shown when the row is expanded on screen.
class SheetLine {
  final String label;
  final double amount;
  final List<SheetDetail> details;

  const SheetLine(this.label, this.amount, {this.details = const []});
}

class SheetDetail {
  final String label;
  final double amount;
  const SheetDetail(this.label, this.amount);
}

String _fmtDate(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

String _fmtAmount(double v) => v.toStringAsFixed(2);

Future<void> printBalanceSheet({
  required String branchLabel,
  required DateTime from,
  required DateTime to,
  required List<SheetLine> assets,
  required List<SheetLine> liabilities,
  required double totalAssets,
  required double totalLiabilities,
}) async {
  const blue = PdfColor.fromInt(0xFF0D6EFD);
  const dark = PdfColor.fromInt(0xFF343A40);
  const line = PdfColor.fromInt(0xFFDEE2E6);

  pw.Widget section(String title, List<SheetLine> rows, double total,
      String totalLabel) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          color: blue,
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Center(
            child: pw.Text(title,
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold)),
          ),
        ),
        ...rows.map((r) => pw.Container(
          padding:
          const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: line))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(r.label,
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Text(_fmtAmount(r.amount),
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        )),
        pw.Container(
          color: dark,
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(totalLabel,
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold)),
              pw.Text(_fmtAmount(total),
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        pw.Text('Balance Sheet',
            style:
            pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('$branchLabel   |   ${_fmtDate(from)} - ${_fmtDate(to)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 16),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
                child: section(
                    'ASSETS', assets, totalAssets, 'TOTAL ASSETS')),
            pw.SizedBox(width: 12),
            pw.Expanded(
                child: section('LIABILITIES & EQUITY', liabilities,
                    totalLiabilities, 'TOTAL LIAB + EQUITY')),
          ],
        ),
      ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) async => doc.save(),
    name: 'balance_sheet.pdf',
  );
}