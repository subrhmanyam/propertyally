import 'dart:convert';

enum InvoiceTemplate { gstTaxInvoice, simpleReceipt, proformaInvoice }

class InvoiceLineItem {
  InvoiceLineItem({
    required this.description,
    required this.amount,
    this.taxable = true,
  });

  String description;
  double amount;
  bool taxable;

  InvoiceLineItem copyWith(
          {String? description, double? amount, bool? taxable}) =>
      InvoiceLineItem(
        description: description ?? this.description,
        amount: amount ?? this.amount,
        taxable: taxable ?? this.taxable,
      );
}

class InvoiceSettings {
  InvoiceSettings({
    this.ownerName = 'Bogineni Jagadeeswara Babu',
    this.companyName = 'BOGINENI BLACK',
    this.address =
        'Ground Floor, 87/2A and 87/3, SH-35\nSeegehalli, Whitefield-Hoskote Road\nBengaluru',
    this.gstin = '29ADWPJ3154H2Z2',
    this.rera = 'ACK/KA/RERA/1251/309/AG/210811/002799',
    this.email = 'accounts@boginenigroup.com',
    this.bankName = 'HDFC Bank',
    this.accountNo = '50200096979343',
    this.ifscCode = 'HDFC0003637',
    this.logoBase64,
    this.hsnSac = '997212',
    this.stateCode = '29',
    this.stateName = 'Karnataka',
    this.cgstRate = 9.0,
    this.sgstRate = 9.0,
  });

  String ownerName;
  String companyName;
  String address;
  String gstin;
  String rera;
  String email;
  String bankName;
  String accountNo;
  String ifscCode;
  String? logoBase64;
  String hsnSac;
  String stateCode;
  String stateName;
  double cgstRate;
  double sgstRate;

  Map<String, dynamic> toJson() => {
        'ownerName': ownerName,
        'companyName': companyName,
        'address': address,
        'gstin': gstin,
        'rera': rera,
        'email': email,
        'bankName': bankName,
        'accountNo': accountNo,
        'ifscCode': ifscCode,
        'logoBase64': logoBase64,
        'hsnSac': hsnSac,
        'stateCode': stateCode,
        'stateName': stateName,
        'cgstRate': cgstRate,
        'sgstRate': sgstRate,
      };

  factory InvoiceSettings.fromJson(Map<String, dynamic> j) => InvoiceSettings(
        ownerName: j['ownerName'] ?? 'Bogineni Jagadeeswara Babu',
        companyName: j['companyName'] ?? 'BOGINENI BLACK',
        address: j['address'] ??
            'Ground Floor, 87/2A and 87/3, SH-35\nSeegehalli, Whitefield-Hoskote Road\nBengaluru',
        gstin: j['gstin'] ?? '29ADWPJ3154H2Z2',
        rera: j['rera'] ?? 'ACK/KA/RERA/1251/309/AG/210811/002799',
        email: j['email'] ?? 'accounts@boginenigroup.com',
        bankName: j['bankName'] ?? 'HDFC Bank',
        accountNo: j['accountNo'] ?? '50200096979343',
        ifscCode: j['ifscCode'] ?? 'HDFC0003637',
        logoBase64: j['logoBase64'] as String?,
        hsnSac: j['hsnSac'] ?? '997212',
        stateCode: j['stateCode'] ?? '29',
        stateName: j['stateName'] ?? 'Karnataka',
        cgstRate: (j['cgstRate'] as num?)?.toDouble() ?? 9.0,
        sgstRate: (j['sgstRate'] as num?)?.toDouble() ?? 9.0,
      );

  String toJsonString() => jsonEncode(toJson());
  static InvoiceSettings fromJsonString(String s) =>
      InvoiceSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
