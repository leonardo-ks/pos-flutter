import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../reports/models/sale_transaction.dart';
import '../formatters.dart';

Future<void> printReceipt(SaleTransaction transaction) async {
  final document = pw.Document();
  document.addPage(
    pw.Page(
      pageFormat: const PdfPageFormat(226, double.infinity, marginAll: 12),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'POS Kasir',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            _line('No', '#${transaction.id}'),
            _line('Tanggal', shortDate(transaction.time)),
            _line('Kasir', transaction.user.name),
            _line('Pelanggan', transaction.customer?.name ?? 'Umum'),
            pw.Divider(),
            for (final item in transaction.items) ...[
              pw.Text(item.productName),
              _line(
                '${item.quantity} x ${rupiah(item.unitPrice)}',
                rupiah(item.subtotal),
              ),
              pw.SizedBox(height: 4),
            ],
            pw.Divider(),
            _line('Subtotal', rupiah(transaction.totalBeforeDiscount)),
            _line('Diskon', '-${rupiah(transaction.discount)}'),
            pw.SizedBox(height: 4),
            _line('Total', rupiah(transaction.totalFinal), bold: true),
            _line('Bayar', _paymentLabel(transaction.paymentMethod)),
            if (transaction.paymentMethod == 'cash') ...[
              _line('Uang Diterima', rupiah(transaction.cashReceived ?? 0)),
              _line('Kembalian', rupiah(transaction.changeAmount)),
            ],
            pw.SizedBox(height: 10),
            pw.Center(child: pw.Text('Terima kasih')),
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(
    name: 'nota-${transaction.id}.pdf',
    onLayout: (_) async => document.save(),
  );
}

pw.Widget _line(String label, String value, {bool bold = false}) {
  final style = bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null;
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(child: pw.Text(label, style: style)),
      pw.SizedBox(width: 8),
      pw.Text(value, style: style),
    ],
  );
}

String _paymentLabel(String method) {
  return switch (method) {
    'qris' => 'QRIS',
    'debit' => 'Debit',
    'transfer' => 'Transfer',
    _ => 'Tunai',
  };
}
