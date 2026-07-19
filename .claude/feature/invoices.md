# Invoices (PDF Generator)

## Purpose
A client-side-only dialog for generating a printable/shareable GST tax invoice, rent receipt, or proforma invoice PDF for a given `LeasingUnit`. It is a standalone document-generation tool — it does **not** read from or write to the `transactions` table or any backend, and is unrelated to the accounting feature's "Generate Invoices" button (see `accounting.md`) other than sharing the word "invoice".

## Frontend
- **Screens/Dialogs**: `frontend/lib/features/invoices/presentation/invoice_generator_dialog.dart` — `InvoiceGeneratorDialog` (`static Future<void> show(BuildContext, LeasingUnit unit)`). Modal with a template picker (GST Tax Invoice / Rent Receipt / Proforma Invoice), invoice meta fields (invoice no., invoice date, due date, billing month), "Bill To" fields, an editable line-items table (description, amount, taxable checkbox), a live totals panel (subtotal, CGST, SGST, grand total), a settings sub-form (seller/owner details, logo, bank details), and action buttons: Preview (opens system print/preview via `Printing.layoutPdf`), Share (bottom sheet with WhatsApp/Email/Download/Copy-text options), Download PDF (`Printing.sharePdf`, then increments the invoice-number counter and closes the dialog).
  - Called from: `frontend/lib/features/tenants/presentation/screens/tenant_list_screen.dart:170` (`_generateInvoice`) and `frontend/lib/features/properties/presentation/screens/leasing_list_screen.dart:350` (`_generateInvoice`) — both just call `InvoiceGeneratorDialog.show(context, unit)`.
- **Providers**: `frontend/lib/features/invoices/providers/invoice_settings_provider.dart` — `InvoiceSettingsProvider extends ChangeNotifier` (registered globally in `main.dart:47` via `..load()`). Holds `InvoiceSettings settings` and a running `_lastInvoiceNo` counter (seeded at 284). Persists both to `SharedPreferences` (browser local storage) under keys `invoice_settings` and `invoice_last_no` — **no backend/database persistence at all**. `nextInvoiceNo()` previews the next number; `consumeInvoiceNo()` increments and saves it (only called after a successful Download).
- **Repositories**: none — no backend integration for this feature.
- **Domain entities/models**: `frontend/lib/features/invoices/models/invoice_models.dart`:
  - `InvoiceTemplate` enum: `gstTaxInvoice | simpleReceipt | proformaInvoice`.
  - `InvoiceLineItem` (description, amount, taxable bool).
  - `InvoiceSettings` (ownerName, companyName, address, gstin, rera, email, bankName, accountNo, ifscCode, logoBase64, hsnSac, stateCode, stateName, cgstRate, sgstRate) — hardcoded defaults are the real Bogineni Group business details (owner name, GSTIN, RERA no., HDFC bank account); `toJson`/`fromJson`/`toJsonString` for SharedPreferences round-trip.

## Backend
- Router: none — this feature has no backend router. `grep -rn "invoice" backend/routers/` only turns up unrelated hits: `accounting.py` (rent-transaction generation, a different concept), `tenant.py` `GET /my-invoices` (reads `transactions` table for the tenant portal), `stripe_payments.py` (comments referring to a `transactions` row loosely as "the invoice"), and `notifications.py` (an `invoice_generated` template name for email/WhatsApp dispatch). None of these are called by or connected to this feature's PDF generator.
- Key endpoints: N/A.

## Database
- Tables: none — not persisted. All invoice/receipt data (line items, invoice number, dates, bill-to info) lives only in the dialog's local widget state for the duration it's open; only `InvoiceSettings` (seller profile) and the invoice-number counter survive between sessions, and only in the browser's `SharedPreferences`, not Supabase.

## Key patterns / architecture notes
- PDF library: `pdf` (`^3.10.8`, package `pdf/widgets.dart as pw`) builds the document; `printing` (`^5.12.0`) handles preview (`Printing.layoutPdf`) and share/download (`Printing.sharePdf`). Fonts loaded via `PdfGoogleFonts.notoSansRegular/Bold` specifically so the ₹ (U+20B9) glyph renders. Logo upload uses `file_picker` (`^8.0.7`) to read image bytes, stored as base64 in `InvoiceSettings.logoBase64`.
- `frontend/lib/features/invoices/utils/invoice_pdf.dart` — `generateInvoicePdf(...)` returns `Uint8List` PDF bytes. Two page builders: `_buildGstPage` (used for both `gstTaxInvoice` and `proformaInvoice`, the latter via an `isProforma` flag that changes the title, hides the "Payment Due Date" line, and skips nothing else — GST math still runs even in proforma mode) and `_buildReceiptPage` (no GST, used for `simpleReceipt`). Includes an `amountToWords` helper (Indian numbering: Lakh/Crore) for the "Amount Chargeable in words" line mimicking standard Indian tax-invoice formats (Tally-style layout).
- Default line items when the dialog opens: "Leave and License Fee for a Month" pre-filled with `unit.totalRent`, plus an empty "Utility Charges" row — both editable/deletable.
- CGST/SGST rates (default 9%/9%) come from `InvoiceSettings`, editable indirectly by editing the settings form (rate fields themselves aren't exposed in `_SettingsForm`, only via the `InvoiceSettings` constructor defaults).
- Share sheet builds a WhatsApp deep link (`wa.me/?text=...`) and a `mailto:` link with pre-filled subject/body; the PDF itself is not attached automatically to either — user must attach manually after it downloads (explicitly noted in the UI's info banner).

## Known Issues
- No link whatsoever to `transactions`/accounting data: generating and downloading an invoice here does not create a rent transaction, and generating a rent transaction via the Accounting screen's "Generate Invoices" button does not produce a PDF. The two "invoice" concepts can drift out of sync (e.g., invoice numbers, amounts) since they're maintained completely independently — worth flagging to product/users if they expect one action to do both.
- Invoice-number counter (`_lastInvoiceNo`) is stored in browser `SharedPreferences`, so it is per-browser/per-device, not shared across users or machines — two people generating invoices from different browsers will get colliding/duplicate invoice numbers.
- `proformaInvoice` template still computes and prints full CGST/SGST amounts via `_buildGstPage`, despite being intended as a pre-tax estimate; only the title and due-date line differ from a real GST tax invoice.

## Related features
- `accounting.md` — separate backend-persisted "Rent" transaction generation (`POST /api/v1/accounting/invoices/generate`); shares terminology ("invoice") but no code or data path in common with this feature.
- Tenant portal (`backend/routers/tenant.py` `GET /my-invoices`) — displays `transactions` rows to tenants; unrelated to this PDF generator.
