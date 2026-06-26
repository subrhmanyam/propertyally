import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

String _escapeCsv(dynamic value) {
  if (value == null) return '';
  final s = value.toString();
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String buildCsv(List<String> headers, List<List<dynamic>> rows) {
  final buf = StringBuffer();
  buf.writeln(headers.map(_escapeCsv).join(','));
  for (final row in rows) {
    buf.writeln(row.map(_escapeCsv).join(','));
  }
  return buf.toString();
}

void downloadCsv(String csvContent, String filename) {
  if (!kIsWeb) return;
  final blob = web.Blob(
    [csvContent.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8;'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
