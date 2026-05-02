import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../properties/domain/entities/leasing_unit.dart';
import '../models/invoice_models.dart';
import '../providers/invoice_settings_provider.dart';
import '../utils/invoice_pdf.dart';

class InvoiceGeneratorDialog extends StatefulWidget {
  const InvoiceGeneratorDialog({super.key, required this.unit});

  final LeasingUnit unit;

  static Future<void> show(BuildContext context, LeasingUnit unit) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => InvoiceGeneratorDialog(unit: unit),
    );
  }

  @override
  State<InvoiceGeneratorDialog> createState() => _InvoiceGeneratorDialogState();
}

class _InvoiceGeneratorDialogState extends State<InvoiceGeneratorDialog> {
  InvoiceTemplate _template = InvoiceTemplate.gstTaxInvoice;
  bool _showSettings = false;
  bool _generating = false;

  // Invoice meta
  late final TextEditingController _invoiceNoCtrl;
  late DateTime _invoiceDate;
  late DateTime _dueDate;
  late final TextEditingController _monthCtrl;

  // Bill To
  late final TextEditingController _billToNameCtrl;
  late final TextEditingController _billToAddressCtrl;
  late final TextEditingController _billToGstinCtrl;

  // Line items
  late List<InvoiceLineItem> _items;

  // Settings form controllers
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _companyCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _gstinCtrl;
  late TextEditingController _reraCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _bankNameCtrl;
  late TextEditingController _accountNoCtrl;
  late TextEditingController _ifscCtrl;

  @override
  void initState() {
    super.initState();
    final sp = context.read<InvoiceSettingsProvider>();
    final s = sp.settings;
    final now = DateTime.now();

    _invoiceNoCtrl = TextEditingController(text: '${sp.nextInvoiceNo()}');
    _invoiceDate = now;
    _dueDate = now.add(const Duration(days: 4));
    _monthCtrl = TextEditingController(
        text: DateFormat('MMMM yyyy').format(now).toUpperCase());

    _billToNameCtrl = TextEditingController(text: widget.unit.companyName);
    _billToAddressCtrl = TextEditingController();
    _billToGstinCtrl = TextEditingController();

    _items = [
      InvoiceLineItem(
        description:
            'Leave and License Fee for a Month\n${_monthCtrl.text}',
        amount: widget.unit.totalRent,
        taxable: true,
      ),
      InvoiceLineItem(
        description: 'Utility Charges',
        amount: 0,
        taxable: true,
      ),
    ];

    _ownerNameCtrl = TextEditingController(text: s.ownerName);
    _companyCtrl = TextEditingController(text: s.companyName);
    _addressCtrl = TextEditingController(text: s.address);
    _gstinCtrl = TextEditingController(text: s.gstin);
    _reraCtrl = TextEditingController(text: s.rera);
    _emailCtrl = TextEditingController(text: s.email);
    _bankNameCtrl = TextEditingController(text: s.bankName);
    _accountNoCtrl = TextEditingController(text: s.accountNo);
    _ifscCtrl = TextEditingController(text: s.ifscCode);
  }

  @override
  void dispose() {
    for (final c in [
      _invoiceNoCtrl, _monthCtrl, _billToNameCtrl, _billToAddressCtrl,
      _billToGstinCtrl, _ownerNameCtrl, _companyCtrl, _addressCtrl,
      _gstinCtrl, _reraCtrl, _emailCtrl, _bankNameCtrl, _accountNoCtrl, _ifscCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Calculations ──────────────────────────────────────────────────

  double get _taxableTotal =>
      _items.where((i) => i.taxable).fold(0.0, (a, b) => a + b.amount);
  double get _subtotal => _items.fold(0.0, (a, b) => a + b.amount);
  double get _cgst =>
      _taxableTotal * context.read<InvoiceSettingsProvider>().settings.cgstRate / 100;
  double get _sgst =>
      _taxableTotal * context.read<InvoiceSettingsProvider>().settings.sgstRate / 100;
  double get _grandTotal =>
      _template == InvoiceTemplate.simpleReceipt ? _subtotal : _subtotal + _cgst + _sgst;

  // ── PDF actions ───────────────────────────────────────────────────

  Future<Uint8List> _buildPdf() async {
    final sp = context.read<InvoiceSettingsProvider>();
    final s = _settingsFromForm(sp.settings);
    return generateInvoicePdf(
      template: _template,
      settings: s,
      invoiceNo: _invoiceNoCtrl.text.trim(),
      invoiceDate: _invoiceDate,
      dueDate: _dueDate,
      billToName: _billToNameCtrl.text.trim(),
      billToAddress: _billToAddressCtrl.text.trim(),
      billToGstin: _billToGstinCtrl.text.trim(),
      items: _items.where((i) => i.amount > 0 || i.description.isNotEmpty).toList(),
      month: _monthCtrl.text.trim(),
    );
  }

  Future<void> _preview() async {
    setState(() => _generating = true);
    try {
      final bytes = await _buildPdf();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _share() async {
    setState(() => _generating = true);
    final sp = context.read<InvoiceSettingsProvider>();
    final invoiceNo = _invoiceNoCtrl.text.trim();
    final billTo = _billToNameCtrl.text.trim();
    final month = _monthCtrl.text.trim();
    final total = _grandTotal;
    final due = _dueDate;
    final settings = _settingsFromForm(sp.settings);
    final filename =
        'Invoice_${invoiceNo}_${billTo.replaceAll(' ', '_')}.pdf';
    try {
      final bytes = await _buildPdf();
      if (!mounted) return;
      setState(() => _generating = false);
      await _InvoiceShareSheet.show(
        context,
        bytes: bytes,
        filename: filename,
        invoiceNo: invoiceNo,
        billToName: billTo,
        month: month,
        grandTotal: total,
        dueDate: due,
        settings: settings,
      );
    } catch (e) {
      if (mounted) _snack('Error: $e');
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _download() async {
    setState(() => _generating = true);
    // Capture context-dependent values before the first await
    final sp = context.read<InvoiceSettingsProvider>();
    final filename =
        'Invoice_${_invoiceNoCtrl.text.trim()}_${_billToNameCtrl.text.trim().replaceAll(' ', '_')}.pdf';
    try {
      final bytes = await _buildPdf();
      await Printing.sharePdf(bytes: bytes, filename: filename);
      await sp.consumeInvoiceNo();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  InvoiceSettings _settingsFromForm(InvoiceSettings existing) => InvoiceSettings(
        ownerName: _ownerNameCtrl.text.trim(),
        companyName: _companyCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        gstin: _gstinCtrl.text.trim(),
        rera: _reraCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        bankName: _bankNameCtrl.text.trim(),
        accountNo: _accountNoCtrl.text.trim(),
        ifscCode: _ifscCtrl.text.trim(),
        logoBase64: existing.logoBase64,
        hsnSac: existing.hsnSac,
        stateCode: existing.stateCode,
        stateName: existing.stateName,
        cgstRate: existing.cgstRate,
        sgstRate: existing.sgstRate,
      );

  Future<void> _saveSettings() async {
    final sp = context.read<InvoiceSettingsProvider>();
    await sp.saveSettings(_settingsFromForm(sp.settings));
    if (mounted) _snack('Settings saved');
  }

  Future<void> _uploadLogo() async {
    final sp = context.read<InvoiceSettingsProvider>();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    await sp.updateLogo(bytes);
    if (mounted) setState(() {});
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<InvoiceSettingsProvider>();
    final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN');

    return Dialog(
      backgroundColor: AppColors.cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.of(context).size.height - 64,
        ),
        child: Column(
          children: [
            // ── Title bar ───────────────────────────────────────
            _TitleBar(
              unit: widget.unit,
              showSettings: _showSettings,
              onSettingsToggle: () => setState(() => _showSettings = !_showSettings),
              onClose: () => Navigator.pop(context),
            ),
            const Divider(color: AppColors.border, height: 1),

            // ── Body ────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.spaceLG),
                child: _showSettings
                    ? _SettingsForm(
                        sp: sp,
                        ownerNameCtrl: _ownerNameCtrl,
                        companyCtrl: _companyCtrl,
                        addressCtrl: _addressCtrl,
                        gstinCtrl: _gstinCtrl,
                        reraCtrl: _reraCtrl,
                        emailCtrl: _emailCtrl,
                        bankNameCtrl: _bankNameCtrl,
                        accountNoCtrl: _accountNoCtrl,
                        ifscCtrl: _ifscCtrl,
                        onSave: _saveSettings,
                        onUploadLogo: _uploadLogo,
                        onClearLogo: () => sp.clearLogo(),
                      )
                    : _InvoiceForm(
                        template: _template,
                        onTemplateChange: (t) => setState(() => _template = t),
                        invoiceNoCtrl: _invoiceNoCtrl,
                        invoiceDate: _invoiceDate,
                        dueDate: _dueDate,
                        monthCtrl: _monthCtrl,
                        billToNameCtrl: _billToNameCtrl,
                        billToAddressCtrl: _billToAddressCtrl,
                        billToGstinCtrl: _billToGstinCtrl,
                        items: _items,
                        onItemsChanged: () => setState(() {}),
                        onDateChange: (d, isDue) => setState(
                            () => isDue ? _dueDate = d : _invoiceDate = d),
                        showGst: _template != InvoiceTemplate.simpleReceipt,
                        taxableTotal: _taxableTotal,
                        cgst: _cgst,
                        sgst: _sgst,
                        grandTotal: _grandTotal,
                        fmt: fmt,
                        settings: sp.settings,
                      ),
              ),
            ),

            // ── Action bar ──────────────────────────────────────
            const Divider(color: AppColors.border, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spaceLG, vertical: AppDimensions.spaceMD),
              child: Row(
                children: [
                  Text(
                    'Total: ${fmt.format(_grandTotal)}',
                    style: const TextStyle(
                        fontSize: AppDimensions.fontBase,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentGold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.preview_outlined, size: 16),
                    label: const Text('Preview'),
                    onPressed: _generating ? null : _preview,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share'),
                    onPressed: _generating ? null : _share,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: _generating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.bgOuter))
                        : const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Download PDF'),
                    onPressed: _generating ? null : _download,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentSilver,
                      foregroundColor: AppColors.bgOuter,
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Title bar ──────────────────────────────────────────────────────────────

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.unit,
    required this.showSettings,
    required this.onSettingsToggle,
    required this.onClose,
  });

  final LeasingUnit unit;
  final bool showSettings;
  final VoidCallback onSettingsToggle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.spaceLG, AppDimensions.spaceMD,
          AppDimensions.spaceSM, AppDimensions.spaceMD),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 20, color: AppColors.accentGold),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Generate Invoice',
                  style: TextStyle(
                      fontSize: AppDimensions.fontH3,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              Text(unit.name,
                  style: const TextStyle(
                      fontSize: AppDimensions.fontSM,
                      color: AppColors.textMuted)),
            ],
          ),
          const Spacer(),
          Tooltip(
            message: showSettings ? 'Back to Invoice' : 'Invoice Settings',
            child: IconButton(
              icon: Icon(
                showSettings ? Icons.receipt_outlined : Icons.settings_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: onSettingsToggle,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

// ── Settings form ──────────────────────────────────────────────────────────

class _SettingsForm extends StatelessWidget {
  const _SettingsForm({
    required this.sp,
    required this.ownerNameCtrl,
    required this.companyCtrl,
    required this.addressCtrl,
    required this.gstinCtrl,
    required this.reraCtrl,
    required this.emailCtrl,
    required this.bankNameCtrl,
    required this.accountNoCtrl,
    required this.ifscCtrl,
    required this.onSave,
    required this.onUploadLogo,
    required this.onClearLogo,
  });

  final InvoiceSettingsProvider sp;
  final TextEditingController ownerNameCtrl;
  final TextEditingController companyCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController gstinCtrl;
  final TextEditingController reraCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController bankNameCtrl;
  final TextEditingController accountNoCtrl;
  final TextEditingController ifscCtrl;
  final VoidCallback onSave;
  final VoidCallback onUploadLogo;
  final VoidCallback onClearLogo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Owner / Seller Details'),
        const SizedBox(height: AppDimensions.spaceMD),

        // Logo row
        Row(
          children: [
            Container(
              width: 80,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.pageBg,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
              ),
              child: sp.settings.logoBase64 != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
                      child: Image.memory(
                        base64Decode(sp.settings.logoBase64!),
                        fit: BoxFit.contain,
                      ),
                    )
                  : const Icon(Icons.image_outlined,
                      size: 28, color: AppColors.textMuted),
            ),
            const SizedBox(width: AppDimensions.spaceMD),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_outlined, size: 16),
                  label: const Text('Upload Logo'),
                  onPressed: onUploadLogo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sidebarItemActive,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                  ),
                ),
                if (sp.settings.logoBase64 != null)
                  TextButton(
                    onPressed: onClearLogo,
                    child: const Text('Remove',
                        style: TextStyle(color: AppColors.error, fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceMD),

        Row(children: [
          Expanded(child: _Field('Owner Name', ownerNameCtrl)),
          const SizedBox(width: AppDimensions.spaceMD),
          Expanded(child: _Field('Company Name', companyCtrl)),
        ]),
        const SizedBox(height: AppDimensions.spaceSM),
        _Field('Address', addressCtrl, maxLines: 3),
        const SizedBox(height: AppDimensions.spaceSM),
        Row(children: [
          Expanded(child: _Field('GSTIN', gstinCtrl)),
          const SizedBox(width: AppDimensions.spaceMD),
          Expanded(child: _Field('Email', emailCtrl)),
        ]),
        const SizedBox(height: AppDimensions.spaceSM),
        _Field('RERA Number', reraCtrl),
        const SizedBox(height: AppDimensions.spaceLG),

        _SectionTitle('Bank Details'),
        const SizedBox(height: AppDimensions.spaceMD),
        Row(children: [
          Expanded(child: _Field('Bank Name', bankNameCtrl)),
          const SizedBox(width: AppDimensions.spaceMD),
          Expanded(child: _Field('Account Number', accountNoCtrl)),
          const SizedBox(width: AppDimensions.spaceMD),
          Expanded(child: _Field('IFSC Code', ifscCtrl)),
        ]),
        const SizedBox(height: AppDimensions.spaceLG),

        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentSilver,
              foregroundColor: AppColors.bgOuter,
              elevation: 0,
            ),
            child: const Text('Save Settings'),
          ),
        ),
      ],
    );
  }
}

// ── Invoice form ───────────────────────────────────────────────────────────

class _InvoiceForm extends StatelessWidget {
  const _InvoiceForm({
    required this.template,
    required this.onTemplateChange,
    required this.invoiceNoCtrl,
    required this.invoiceDate,
    required this.dueDate,
    required this.monthCtrl,
    required this.billToNameCtrl,
    required this.billToAddressCtrl,
    required this.billToGstinCtrl,
    required this.items,
    required this.onItemsChanged,
    required this.onDateChange,
    required this.showGst,
    required this.taxableTotal,
    required this.cgst,
    required this.sgst,
    required this.grandTotal,
    required this.fmt,
    required this.settings,
  });

  final InvoiceTemplate template;
  final ValueChanged<InvoiceTemplate> onTemplateChange;
  final TextEditingController invoiceNoCtrl;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final TextEditingController monthCtrl;
  final TextEditingController billToNameCtrl;
  final TextEditingController billToAddressCtrl;
  final TextEditingController billToGstinCtrl;
  final List<InvoiceLineItem> items;
  final VoidCallback onItemsChanged;
  final void Function(DateTime, bool isDue) onDateChange;
  final bool showGst;
  final double taxableTotal;
  final double cgst;
  final double sgst;
  final double grandTotal;
  final NumberFormat fmt;
  final InvoiceSettings settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Template picker
        _SectionTitle('Invoice Template'),
        const SizedBox(height: AppDimensions.spaceMD),
        Row(children: [
          _TemplateCard(
            icon: Icons.receipt_long_outlined,
            title: 'GST Tax Invoice',
            subtitle: 'Full CGST/SGST breakdown',
            selected: template == InvoiceTemplate.gstTaxInvoice,
            onTap: () => onTemplateChange(InvoiceTemplate.gstTaxInvoice),
          ),
          const SizedBox(width: AppDimensions.spaceMD),
          _TemplateCard(
            icon: Icons.receipt_outlined,
            title: 'Rent Receipt',
            subtitle: 'Simple receipt, no GST',
            selected: template == InvoiceTemplate.simpleReceipt,
            onTap: () => onTemplateChange(InvoiceTemplate.simpleReceipt),
          ),
          const SizedBox(width: AppDimensions.spaceMD),
          _TemplateCard(
            icon: Icons.description_outlined,
            title: 'Proforma Invoice',
            subtitle: 'Estimate / advance invoice',
            selected: template == InvoiceTemplate.proformaInvoice,
            onTap: () => onTemplateChange(InvoiceTemplate.proformaInvoice),
          ),
        ]),
        const SizedBox(height: AppDimensions.spaceLG),

        // Invoice meta
        _SectionTitle('Invoice Details'),
        const SizedBox(height: AppDimensions.spaceMD),
        Row(children: [
          Expanded(child: _Field('Invoice No.', invoiceNoCtrl)),
          const SizedBox(width: AppDimensions.spaceMD),
          Expanded(
            child: _DateField(
              label: 'Invoice Date',
              date: invoiceDate,
              onChanged: (d) => onDateChange(d, false),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceMD),
          Expanded(
            child: _DateField(
              label: 'Due Date',
              date: dueDate,
              onChanged: (d) => onDateChange(d, true),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceMD),
          Expanded(child: _Field('Billing Month', monthCtrl)),
        ]),
        const SizedBox(height: AppDimensions.spaceLG),

        // Bill To
        _SectionTitle('Bill To'),
        const SizedBox(height: AppDimensions.spaceMD),
        Row(children: [
          Expanded(flex: 2, child: _Field('Company / Tenant Name', billToNameCtrl)),
          const SizedBox(width: AppDimensions.spaceMD),
          Expanded(child: _Field('GSTIN (optional)', billToGstinCtrl)),
        ]),
        const SizedBox(height: AppDimensions.spaceSM),
        _Field('Address (optional)', billToAddressCtrl, maxLines: 2),
        const SizedBox(height: AppDimensions.spaceLG),

        // Line items
        _SectionTitle('Line Items'),
        const SizedBox(height: AppDimensions.spaceSM),
        _LineItemsTable(
          items: items,
          showGst: showGst,
          onChanged: onItemsChanged,
        ),
        const SizedBox(height: AppDimensions.spaceLG),

        // Totals summary
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(AppDimensions.spaceMD),
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
            ),
            child: Column(
              children: [
                _TotalRow('Subtotal (taxable)', fmt.format(taxableTotal)),
                if (showGst) ...[
                  _TotalRow(
                      'CGST @ ${settings.cgstRate.toStringAsFixed(0)}%',
                      fmt.format(cgst)),
                  _TotalRow(
                      'SGST @ ${settings.sgstRate.toStringAsFixed(0)}%',
                      fmt.format(sgst)),
                ],
                const Divider(color: AppColors.border),
                _TotalRow('Grand Total', fmt.format(grandTotal),
                    bold: true, color: AppColors.accentGold),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Line items table ───────────────────────────────────────────────────────

class _LineItemsTable extends StatelessWidget {
  const _LineItemsTable({
    required this.items,
    required this.showGst,
    required this.onChanged,
  });

  final List<InvoiceLineItem> items;
  final bool showGst;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceMD, vertical: AppDimensions.spaceSM),
          decoration: const BoxDecoration(
            color: AppColors.pageBg,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              const Expanded(flex: 5, child: _TH('Description')),
              const Expanded(flex: 2, child: _TH('Amount (₹)', right: true)),
              if (showGst)
                const SizedBox(
                    width: 70, child: _TH('Taxable', right: true)),
              const SizedBox(width: 32),
            ],
          ),
        ),

        // Rows
        ...items.asMap().entries.map((e) => _LineItemRow(
              item: e.value,
              showGst: showGst,
              onChanged: onChanged,
              onDelete: items.length > 1
                  ? () {
                      items.removeAt(e.key);
                      onChanged();
                    }
                  : null,
            )),

        // Add item button
        TextButton.icon(
          icon: const Icon(Icons.add, size: 16, color: AppColors.accentSilver),
          label: const Text('Add Item',
              style: TextStyle(
                  fontSize: AppDimensions.fontSM, color: AppColors.accentSilver)),
          onPressed: () {
            items.add(InvoiceLineItem(description: '', amount: 0));
            onChanged();
          },
        ),
      ],
    );
  }
}

class _LineItemRow extends StatefulWidget {
  const _LineItemRow({
    required this.item,
    required this.showGst,
    required this.onChanged,
    this.onDelete,
  });

  final InvoiceLineItem item;
  final bool showGst;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  @override
  State<_LineItemRow> createState() => _LineItemRowState();
}

class _LineItemRowState extends State<_LineItemRow> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _amtCtrl;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.item.description);
    _amtCtrl = TextEditingController(
        text: widget.item.amount > 0 ? widget.item.amount.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spaceMD, vertical: 6),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: TextField(
              controller: _descCtrl,
              maxLines: 2,
              style: const TextStyle(
                  fontSize: AppDimensions.fontSM, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Description',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                isDense: true,
              ),
              onChanged: (v) {
                widget.item.description = v;
                widget.onChanged();
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _amtCtrl,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                  fontSize: AppDimensions.fontSM, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '0',
                hintStyle: TextStyle(color: AppColors.textMuted),
                isDense: true,
              ),
              onChanged: (v) {
                widget.item.amount = double.tryParse(v) ?? 0;
                widget.onChanged();
              },
            ),
          ),
          if (widget.showGst)
            SizedBox(
              width: 70,
              child: Checkbox(
                value: widget.item.taxable,
                activeColor: AppColors.accentSilver,
                onChanged: (v) {
                  setState(() => widget.item.taxable = v ?? true);
                  widget.onChanged();
                },
              ),
            ),
          SizedBox(
            width: 32,
            child: widget.onDelete != null
                ? IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: AppColors.error),
                    onPressed: widget.onDelete,
                    padding: EdgeInsets.zero,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Shared small widgets ───────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppDimensions.spaceMD),
          decoration: BoxDecoration(
            color: selected ? AppColors.sidebarItemActive : AppColors.pageBg,
            border: Border.all(
              color: selected ? AppColors.accentSilver : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 28,
                  color: selected ? AppColors.accentSilver : AppColors.textMuted),
              const SizedBox(height: 6),
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: AppDimensions.fontSM,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.accentSilver : AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: _inputDec(label),
        child: Text(DateFormat('dd-MMM-yyyy').format(date),
            style: const TextStyle(
                fontSize: AppDimensions.fontSM, color: AppColors.textPrimary)),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.controller, {this.maxLines = 1});

  final String label;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
          fontSize: AppDimensions.fontSM, color: AppColors.textPrimary),
      decoration: _inputDec(label),
    );
  }
}

InputDecoration _inputDec(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      filled: true,
      fillColor: AppColors.pageBg,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.accentSilver),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
    );

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: AppDimensions.fontSM,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.5));
}

class _TH extends StatelessWidget {
  const _TH(this.label, {this.right = false});

  final String label;
  final bool right;

  @override
  Widget build(BuildContext context) => Text(label,
      textAlign: right ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
          fontSize: AppDimensions.fontXS,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.5));
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, {this.bold = false, this.color});

  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? AppDimensions.fontBase : AppDimensions.fontSM,
      fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
      color: color ?? AppColors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text(label, style: style),
        const Spacer(),
        Text(value, style: style),
      ]),
    );
  }
}

// ── Share sheet ────────────────────────────────────────────────────────────

class _InvoiceShareSheet {
  static Future<void> show(
    BuildContext context, {
    required Uint8List bytes,
    required String filename,
    required String invoiceNo,
    required String billToName,
    required String month,
    required double grandTotal,
    required DateTime dueDate,
    required InvoiceSettings settings,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ShareSheetContent(
        bytes: bytes,
        filename: filename,
        invoiceNo: invoiceNo,
        billToName: billToName,
        month: month,
        grandTotal: grandTotal,
        dueDate: dueDate,
        settings: settings,
      ),
    );
  }
}

class _ShareSheetContent extends StatefulWidget {
  const _ShareSheetContent({
    required this.bytes,
    required this.filename,
    required this.invoiceNo,
    required this.billToName,
    required this.month,
    required this.grandTotal,
    required this.dueDate,
    required this.settings,
  });

  final Uint8List bytes;
  final String filename;
  final String invoiceNo;
  final String billToName;
  final String month;
  final double grandTotal;
  final DateTime dueDate;
  final InvoiceSettings settings;

  @override
  State<_ShareSheetContent> createState() => _ShareSheetContentState();
}

class _ShareSheetContentState extends State<_ShareSheetContent> {
  bool _downloading = false;
  bool _copied = false;

  String get _amtFormatted =>
      NumberFormat.currency(symbol: '₹', decimalDigits: 2, locale: 'en_IN')
          .format(widget.grandTotal);

  String get _dueDateFormatted =>
      DateFormat('dd-MMM-yyyy').format(widget.dueDate);

  String get _whatsAppText =>
      'Invoice #${widget.invoiceNo} from ${widget.settings.companyName}\n'
      'Tenant: ${widget.billToName}\n'
      'Month: ${widget.month}\n'
      'Amount: $_amtFormatted\n'
      'Due Date: $_dueDateFormatted\n\n'
      'Please find the attached PDF invoice.';

  String get _emailBody =>
      'Dear ${widget.billToName},\n\n'
      'Please find the invoice details below:\n\n'
      'Invoice No : ${widget.invoiceNo}\n'
      'Month      : ${widget.month}\n'
      'Amount     : $_amtFormatted\n'
      'Due Date   : $_dueDateFormatted\n\n'
      'Kindly make the payment by the due date.\n\n'
      'Regards,\n'
      '${widget.settings.ownerName}\n'
      '${widget.settings.companyName}\n'
      '${widget.settings.email}';

  String get _emailSubject =>
      'Invoice #${widget.invoiceNo} — ${widget.month} | ${widget.settings.companyName}';

  Future<void> _downloadPdf() async {
    setState(() => _downloading = true);
    try {
      await Printing.sharePdf(
          bytes: widget.bytes, filename: widget.filename);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _shareWhatsApp() async {
    await _downloadPdf();
    final encoded = Uri.encodeComponent(_whatsAppText);
    final uri = Uri.parse('https://wa.me/?text=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareEmail() async {
    await _downloadPdf();
    final uri = Uri(
      scheme: 'mailto',
      query: _encodeMailtoParams({
        'subject': _emailSubject,
        'body': _emailBody,
      }),
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _copyText() async {
    await Clipboard.setData(ClipboardData(text: _whatsAppText));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  static String _encodeMailtoParams(Map<String, String> params) =>
      params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Share Invoice #${widget.invoiceNo}',
            style: const TextStyle(
                fontSize: AppDimensions.fontH3,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          Text(
            '${widget.billToName}  •  ${widget.month}  •  $_amtFormatted',
            style: const TextStyle(
                fontSize: AppDimensions.fontSM,
                color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),

          // Share options row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareOption(
                icon: _whatsAppIcon(),
                label: 'WhatsApp',
                sublabel: 'Download + open chat',
                color: const Color(0xFF25D366),
                onTap: _shareWhatsApp,
                loading: _downloading,
              ),
              _ShareOption(
                icon: const Icon(Icons.email_outlined, size: 32,
                    color: Color(0xFF4285F4)),
                label: 'Email',
                sublabel: 'Open mail client',
                color: const Color(0xFF4285F4),
                onTap: _shareEmail,
                loading: false,
              ),
              _ShareOption(
                icon: const Icon(Icons.download_outlined, size: 32,
                    color: AppColors.accentSilver),
                label: 'Download',
                sublabel: 'Save PDF locally',
                color: AppColors.accentSilver,
                onTap: _downloadPdf,
                loading: _downloading,
              ),
              _ShareOption(
                icon: Icon(
                  _copied ? Icons.check_circle : Icons.copy_outlined,
                  size: 32,
                  color: _copied ? AppColors.success : AppColors.textMuted,
                ),
                label: _copied ? 'Copied!' : 'Copy Text',
                sublabel: 'Invoice summary',
                color: AppColors.textMuted,
                onTap: _copyText,
                loading: false,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Info note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PDF will be downloaded to your device. '
                    'Attach it manually in WhatsApp or Email if needed.',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _whatsAppIcon() => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF25D366),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.chat, size: 18, color: Colors.white),
      );
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
    required this.loading,
  });

  final Widget icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: SizedBox(
        width: 90,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.pageBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: loading
                  ? Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: color),
                      ),
                    )
                  : Center(child: icon),
            ),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            Text(sublabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
