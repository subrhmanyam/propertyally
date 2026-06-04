import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/invoice_models.dart';

const _kSettingsKey = 'invoice_settings';
const _kLastInvoiceNoKey = 'invoice_last_no';

class InvoiceSettingsProvider extends ChangeNotifier {
  InvoiceSettings settings = InvoiceSettings();
  int _lastInvoiceNo = 284;
  bool _loaded = false;

  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kSettingsKey);
    if (json != null) {
      settings = InvoiceSettings.fromJsonString(json);
    }
    _lastInvoiceNo = prefs.getInt(_kLastInvoiceNoKey) ?? 284;
    _loaded = true;
    notifyListeners();
  }

  int nextInvoiceNo() => _lastInvoiceNo + 1;

  Future<void> consumeInvoiceNo() async {
    _lastInvoiceNo++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastInvoiceNoKey, _lastInvoiceNo);
    notifyListeners();
  }

  Future<void> saveSettings(InvoiceSettings updated) async {
    settings = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSettingsKey, updated.toJsonString());
    notifyListeners();
  }

  Future<void> updateLogo(Uint8List bytes) async {
    settings.logoBase64 = base64Encode(bytes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSettingsKey, settings.toJsonString());
    notifyListeners();
  }

  Future<void> clearLogo() async {
    settings.logoBase64 = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSettingsKey, settings.toJsonString());
    notifyListeners();
  }
}
