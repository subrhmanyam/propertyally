import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/invoice_models.dart';

final _dateFmt = DateFormat('dd-MMM-yy');

Future<Uint8List> generateInvoicePdf({
  required InvoiceTemplate template,
  required InvoiceSettings settings,
  required String invoiceNo,
  required DateTime invoiceDate,
  required DateTime dueDate,
  required String billToName,
  required String billToAddress,
  required String billToGstin,
  required List<InvoiceLineItem> items,
  required String month,
}) async {
  // Load NotoSans which includes the ₹ (U+20B9) glyph
  final regularFont = await PdfGoogleFonts.notoSansRegular();
  final boldFont = await PdfGoogleFonts.notoSansBold();
  final theme = pw.ThemeData.withFont(base: regularFont, bold: boldFont);

  final doc = pw.Document();
  const pageFormat = PdfPageFormat.a4;

  pw.MemoryImage? logoImg;
  if (settings.logoBase64 != null && settings.logoBase64!.isNotEmpty) {
    try {
      logoImg = pw.MemoryImage(base64Decode(settings.logoBase64!));
    } catch (_) {
      logoImg = null;
    }
  }

  doc.addPage(
    pw.Page(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.all(28),
      theme: theme,
      build: (ctx) {
        return switch (template) {
          InvoiceTemplate.gstTaxInvoice => _buildGstPage(
              ctx, settings, logoImg, invoiceNo, invoiceDate, dueDate,
              billToName, billToAddress, billToGstin, items, month),
          InvoiceTemplate.simpleReceipt => _buildReceiptPage(
              ctx, settings, logoImg, invoiceNo, invoiceDate,
              billToName, billToAddress, items, month),
          InvoiceTemplate.proformaInvoice => _buildGstPage(
              ctx, settings, logoImg, invoiceNo, invoiceDate, dueDate,
              billToName, billToAddress, billToGstin, items, month,
              isProforma: true),
        };
      },
    ),
  );
  return doc.save();
}

// ── Shared helpers ─────────────────────────────────────────────────────────

const PdfColor _border = PdfColors.grey400;

pw.Widget _cell(String text, {
  pw.TextAlign align = pw.TextAlign.left,
  bool bold = false,
  double fontSize = 8,
  PdfColor? color,
  pw.EdgeInsets? padding,
}) =>
    pw.Padding(
      padding: padding ?? const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
      ),
    );

pw.TableBorder _tableBorder() => pw.TableBorder.all(color: _border, width: 0.5);

// ── GST Tax Invoice ────────────────────────────────────────────────────────

pw.Widget _buildGstPage(
  pw.Context ctx,
  InvoiceSettings s,
  pw.MemoryImage? logo,
  String invoiceNo,
  DateTime invoiceDate,
  DateTime dueDate,
  String billToName,
  String billToAddress,
  String billToGstin,
  List<InvoiceLineItem> items,
  String month, {
  bool isProforma = false,
}) {
  final taxableTotal = items.where((i) => i.taxable).fold(0.0, (a, b) => a + b.amount);
  final nonTaxableTotal = items.where((i) => !i.taxable).fold(0.0, (a, b) => a + b.amount);
  final subTotal = taxableTotal + nonTaxableTotal;
  final cgst = taxableTotal * s.cgstRate / 100;
  final sgst = taxableTotal * s.sgstRate / 100;
  final grandTotal = subTotal + cgst + sgst;

  String title = isProforma ? 'PROFORMA INVOICE' : 'Tax Invoice';

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      // Title
      pw.Center(
        child: pw.Text(title,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      ),
      pw.SizedBox(height: 6),

      // Header table: seller (left) + invoice meta (right)
      pw.Table(
        border: _tableBorder(),
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(children: [
            // Seller info
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logo != null)
                    pw.Image(logo, height: 30, fit: pw.BoxFit.contain),
                  if (logo != null) pw.SizedBox(height: 4),
                  pw.Text(s.ownerName,
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(s.companyName,
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 3),
                  pw.Text(s.address, style: const pw.TextStyle(fontSize: 7.5)),
                  pw.SizedBox(height: 3),
                  pw.Text('RERA NO: ${s.rera}', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text('GSTIN/UIN: ${s.gstin}',
                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text('State Name : ${s.stateName}, Code : ${s.stateCode}',
                      style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text('E-Mail : ${s.email}', style: const pw.TextStyle(fontSize: 7.5)),
                ],
              ),
            ),
            // Invoice meta
            pw.Table(
              border: _tableBorder(),
              children: [
                _metaRow('Invoice No.', 'Dated'),
                _metaRow(invoiceNo, _dateFmt.format(invoiceDate), bold: true),
                _metaRow('Delivery Note', 'Mode/Terms of Payment'),
                _metaRow('', isProforma ? 'Estimate' : 'Payable within 4 days'),
                _metaRow('Reference No. & Date.', 'Other References'),
                _metaRow('', ''),
              ],
            ),
          ]),
        ],
      ),

      // Buyer
      pw.Table(
        border: _tableBorder(),
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Buyer (Bill to)',
                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text(billToName,
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  if (billToAddress.isNotEmpty)
                    pw.Text(billToAddress, style: const pw.TextStyle(fontSize: 7.5)),
                  if (billToGstin.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text('GSTIN/UIN  :  $billToGstin',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text('State Name  :  ${s.stateName}, Code : ${s.stateCode}',
                        style: const pw.TextStyle(fontSize: 7.5)),
                  ],
                ],
              ),
            ),
            pw.Table(
              border: _tableBorder(),
              children: [
                _metaRow("Buyer's Order No.", 'Dated'),
                _metaRow('', ''),
                _metaRow('Dispatch Doc No.', 'Delivery Note Date'),
                _metaRow('', ''),
                _metaRow('Dispatched through', 'Destination'),
                _metaRow('', ''),
                _metaRow('Terms of Delivery', ''),
                _metaRow('', ''),
              ],
            ),
          ]),
        ],
      ),

      // Items table
      pw.Table(
        border: _tableBorder(),
        columnWidths: {
          0: const pw.FixedColumnWidth(22),
          1: const pw.FlexColumnWidth(4),
          2: const pw.FixedColumnWidth(40),
          3: const pw.FixedColumnWidth(30),
          4: const pw.FixedColumnWidth(35),
          5: const pw.FixedColumnWidth(22),
          6: const pw.FixedColumnWidth(55),
        },
        children: [
          // Header
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [
              _cell('Sl\nNo.', bold: true, align: pw.TextAlign.center),
              _cell('Description of Goods', bold: true),
              _cell('HSN/SAC', bold: true, align: pw.TextAlign.center),
              _cell('Quantity', bold: true, align: pw.TextAlign.center),
              _cell('Rate', bold: true, align: pw.TextAlign.center),
              _cell('per', bold: true, align: pw.TextAlign.center),
              _cell('Amount', bold: true, align: pw.TextAlign.right),
            ],
          ),
          // Line items
          ...items.asMap().entries.map((e) => pw.TableRow(children: [
                _cell('${e.key + 1}', align: pw.TextAlign.center),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                  child: pw.Text(
                    e.value.description,
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                _cell(s.hsnSac, align: pw.TextAlign.center),
                _cell('', align: pw.TextAlign.center),
                _cell('', align: pw.TextAlign.center),
                _cell('', align: pw.TextAlign.center),
                _cell(_fmtAmt(e.value.amount), align: pw.TextAlign.right, bold: true),
              ])),
          // GST rows
          pw.TableRow(children: [
            _cell(''),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: pw.Text('OUTPUT CGST @ ${s.cgstRate.toStringAsFixed(0)}%',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ),
            _cell(''),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                pw.Text(s.cgstRate.toStringAsFixed(0),
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(' %', style: const pw.TextStyle(fontSize: 8)),
              ]),
            ),
            _cell(''),
            _cell(''),
            _cell(_fmtAmt(cgst), align: pw.TextAlign.right, bold: true),
          ]),
          pw.TableRow(children: [
            _cell(''),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: pw.Text('OUTPUT SGST @${s.sgstRate.toStringAsFixed(0)}%',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            ),
            _cell(''),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                pw.Text(s.sgstRate.toStringAsFixed(0),
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(' %', style: const pw.TextStyle(fontSize: 8)),
              ]),
            ),
            _cell(''),
            _cell(''),
            _cell(_fmtAmt(sgst), align: pw.TextAlign.right, bold: true),
          ]),
          // Total row
          pw.TableRow(
            children: [
              pw.Container(),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: pw.Text('Total',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Container(),
              pw.Container(),
              pw.Container(),
              pw.Container(),
              _cell('₹ ${_fmtAmt(grandTotal)}',
                  align: pw.TextAlign.right, bold: true, fontSize: 9),
            ],
          ),
        ],
      ),

      // Amount in words
      pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _border, width: 0.5)),
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Row(children: [
          pw.Text('Amount Chargeable (in words)',
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
          pw.Spacer(),
          pw.Text('E. & O.E',
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
        ]),
      ),
      pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _border, width: 0.5)),
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(amountToWords(grandTotal),
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
      ),

      // Tax summary table
      pw.Table(
        border: _tableBorder(),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FixedColumnWidth(50),
          2: const pw.FixedColumnWidth(30),
          3: const pw.FixedColumnWidth(45),
          4: const pw.FixedColumnWidth(30),
          5: const pw.FixedColumnWidth(45),
          6: const pw.FixedColumnWidth(50),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [
              _cell('HSN/SAC', bold: true, align: pw.TextAlign.center),
              _cell('Taxable\nValue', bold: true, align: pw.TextAlign.center),
              _cell('Central Tax\nRate', bold: true, align: pw.TextAlign.center),
              _cell('Amount', bold: true, align: pw.TextAlign.center),
              _cell('State Tax\nRate', bold: true, align: pw.TextAlign.center),
              _cell('Amount', bold: true, align: pw.TextAlign.center),
              _cell('Total\nTax Amount', bold: true, align: pw.TextAlign.center),
            ],
          ),
          pw.TableRow(children: [
            _cell(s.hsnSac, align: pw.TextAlign.center),
            _cell(_fmtAmt(taxableTotal), align: pw.TextAlign.right),
            _cell('${s.cgstRate.toStringAsFixed(0)}%', align: pw.TextAlign.center),
            _cell(_fmtAmt(cgst), align: pw.TextAlign.right),
            _cell('${s.sgstRate.toStringAsFixed(0)}%', align: pw.TextAlign.center),
            _cell(_fmtAmt(sgst), align: pw.TextAlign.right),
            _cell(_fmtAmt(cgst + sgst), align: pw.TextAlign.right),
          ]),
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [
              _cell('Total', bold: true, align: pw.TextAlign.right),
              _cell(_fmtAmt(taxableTotal), align: pw.TextAlign.right, bold: true),
              _cell(''),
              _cell(_fmtAmt(cgst), align: pw.TextAlign.right, bold: true),
              _cell(''),
              _cell(_fmtAmt(sgst), align: pw.TextAlign.right, bold: true),
              _cell(_fmtAmt(cgst + sgst), align: pw.TextAlign.right, bold: true),
            ],
          ),
        ],
      ),

      // Tax amount in words
      pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _border, width: 0.5)),
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(
                text: 'Tax Amount (in words) :  ',
                style: const pw.TextStyle(fontSize: 8)),
            pw.TextSpan(
                text: amountToWords(cgst + sgst),
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
      ),

      pw.SizedBox(height: 4),

      // Payment due + bank + declaration
      if (!isProforma) ...[
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(
                  text: 'Payment Due Date: ',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue)),
              pw.TextSpan(
                  text: _dateFmt.format(dueDate),
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue)),
            ]),
          ),
        ),
        pw.SizedBox(height: 2),
      ],

      pw.Table(
        border: _tableBorder(),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(3),
        },
        children: [
          pw.TableRow(children: [
            // Note + bank details
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Note:',
                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    'Late fee Rs. 1,000 or 2% whichever is higher. As per the\n'
                    'Government directive, effective 1-July-17, 18% GST is\n'
                    'applicable on Late Fee Charges. No charge is levied for\n'
                    'any service without your explicit consent',
                    style: const pw.TextStyle(fontSize: 6.5),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text('Bank Details',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Bank Name      :  ${s.bankName}',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('A/c No.           :  ${s.accountNo}',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Branch & IFS Code : ${s.ifscCode}',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            // Declaration + signature
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text('for ${s.ownerName}',
                        style:
                            pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(height: 28),
                  pw.Divider(color: _border, thickness: 0.5),
                  pw.Text('Declaration',
                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    'We declare that this invoice shows the actual price of the\n'
                    'goods described and that all particulars are true and\ncorrect.',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text('Authorised Signatory',
                        style: const pw.TextStyle(fontSize: 7.5)),
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),

      // Footer
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('E&OE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.Text('This is a Computer Generated Invoice',
              style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    ],
  );
}

pw.TableRow _metaRow(String left, String right, {bool bold = false}) => pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: pw.Text(left,
              style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: pw.Text(right,
              style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
      ],
    );

// ── Simple Receipt ─────────────────────────────────────────────────────────

pw.Widget _buildReceiptPage(
  pw.Context ctx,
  InvoiceSettings s,
  pw.MemoryImage? logo,
  String invoiceNo,
  DateTime invoiceDate,
  String billToName,
  String billToAddress,
  List<InvoiceLineItem> items,
  String month,
) {
  final total = items.fold(0.0, (a, b) => a + b.amount);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      // Header
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null) pw.Image(logo, height: 40, fit: pw.BoxFit.contain),
              if (logo != null) pw.SizedBox(height: 6),
              pw.Text(s.ownerName,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text(s.companyName,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(s.address, style: const pw.TextStyle(fontSize: 8)),
              pw.Text('GSTIN: ${s.gstin}', style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('RENT RECEIPT',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700)),
              pw.SizedBox(height: 8),
              pw.Text('Receipt No: $invoiceNo',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text('Date: ${_dateFmt.format(invoiceDate)}',
                  style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 16),
      pw.Divider(color: PdfColors.grey400, thickness: 1),
      pw.SizedBox(height: 8),

      // Bill To
      pw.Text('Received From:', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      pw.Text(billToName,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      if (billToAddress.isNotEmpty)
        pw.Text(billToAddress, style: const pw.TextStyle(fontSize: 8)),
      pw.SizedBox(height: 16),

      // Items
      pw.Table(
        border: _tableBorder(),
        columnWidths: {
          0: const pw.FixedColumnWidth(24),
          1: const pw.FlexColumnWidth(4),
          2: const pw.FixedColumnWidth(80),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [
              _cell('#', bold: true, align: pw.TextAlign.center),
              _cell('Description', bold: true),
              _cell('Amount', bold: true, align: pw.TextAlign.right),
            ],
          ),
          ...items.asMap().entries.map((e) => pw.TableRow(children: [
                _cell('${e.key + 1}', align: pw.TextAlign.center),
                _cell(e.value.description,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5)),
                _cell(_fmtAmt(e.value.amount),
                    align: pw.TextAlign.right, bold: true, fontSize: 9),
              ])),
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [
              _cell(''),
              _cell('Total', bold: true, align: pw.TextAlign.right),
              _cell('₹ ${_fmtAmt(total)}',
                  align: pw.TextAlign.right, bold: true, fontSize: 10),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 8),

      // Amount in words
      pw.Text('Amount: ${amountToWords(total)}',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 24),

      // Footer
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Bank Details',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.Text('${s.bankName}  |  A/c: ${s.accountNo}  |  IFSC: ${s.ifscCode}',
                style: const pw.TextStyle(fontSize: 8)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Authorised Signatory',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.Text('for ${s.ownerName}', style: const pw.TextStyle(fontSize: 8)),
          ]),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Divider(color: PdfColors.grey400),
      pw.Center(
        child: pw.Text('This is a Computer Generated Receipt',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
      ),
    ],
  );
}

// ── Helpers ────────────────────────────────────────────────────────────────

String _fmtAmt(double v) {
  if (v == 0) return '';
  final fmt = NumberFormat('#,##,##0.00', 'en_IN');
  return fmt.format(v);
}

String amountToWords(double amount) {
  final total = amount.round();
  final rupees = total;
  final words = _numToWords(rupees);
  return 'INR $words Only';
}

String _numToWords(int n) {
  if (n == 0) return 'Zero';
  const ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen',
  ];
  const tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
  ];

  String words(int num) {
    if (num == 0) return '';
    if (num < 20) return ones[num];
    if (num < 100) {
      return tens[num ~/ 10] + (num % 10 != 0 ? ' ${ones[num % 10]}' : '');
    }
    if (num < 1000) {
      return '${ones[num ~/ 100]} Hundred'
          '${num % 100 != 0 ? ' ${words(num % 100)}' : ''}';
    }
    if (num < 100000) {
      return '${words(num ~/ 1000)} Thousand'
          '${num % 1000 != 0 ? ' ${words(num % 1000)}' : ''}';
    }
    if (num < 10000000) {
      return '${words(num ~/ 100000)} Lakh'
          '${num % 100000 != 0 ? ' ${words(num % 100000)}' : ''}';
    }
    return '${words(num ~/ 10000000)} Crore'
        '${num % 10000000 != 0 ? ' ${words(num % 10000000)}' : ''}';
  }

  return words(n);
}
