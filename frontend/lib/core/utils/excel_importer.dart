import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../../features/properties/domain/entities/leasing_unit.dart';

/// Parses a Bogineni leasing area Excel file (.xlsx) into a list of [LeasingUnit]s.
///
/// Expected column layout (row 1 = header):
/// A: Unit Name | B: Floor | C: Category | D: Area Type | E: Sq.Ft | F: Rate
///
/// The parser also handles the original Bogineni format where:
/// - Column A contains the entity name (may span multiple rows via empty cells)
/// - Column B contains the floor description
/// - Remaining cells describe individual area entries
///
/// Returns an empty list if the file cannot be parsed.
List<LeasingUnit> parseExcelBytes(Uint8List bytes) {
  try {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.first;
    final rows = sheet.rows;
    if (rows.isEmpty) return [];

    // Try flat template format first (header in row 0)
    final header = rows.first.map((c) => _str(c).toLowerCase()).toList();
    if (_isTemplateFormat(header)) {
      return _parseTemplate(rows.skip(1).toList());
    }

    // Fall back to Bogineni native format
    return _parseNativeFormat(rows);
  } catch (_) {
    return [];
  }
}

bool _isTemplateFormat(List<String> header) =>
    header.any((h) => h.contains('name')) &&
    header.any((h) => h.contains('sqft') || h.contains('area'));

// ── Flat template parser ──────────────────────────────────────────────
// Row: Name | Floor | Category | Area Type | Sq.Ft | Rate | Status | Contact | Email | Notes

List<LeasingUnit> _parseTemplate(List<List<Data?>> rows) {
  final groups = <String, List<_RowData>>{};

  for (final row in rows) {
    if (row.length < 5) continue;
    final name = _str(row[0]);
    if (name.isEmpty) continue;

    groups.putIfAbsent(name, () => []).add(_RowData(
          name: name,
          floor: _str(row.elementAtOrNull(1)),
          category: _str(row.elementAtOrNull(2)),
          areaType: _str(row.elementAtOrNull(3)),
          sqft: _num(row.elementAtOrNull(4)),
          rate: _num(row.elementAtOrNull(5)),
          status: _str(row.elementAtOrNull(6)),
          contact: _str(row.elementAtOrNull(7)),
          email: _str(row.elementAtOrNull(8)),
          notes: _str(row.elementAtOrNull(9)),
        ));
  }

  int idCounter = DateTime.now().millisecondsSinceEpoch;
  return groups.entries.map((e) {
    final first = e.value.first;
    return LeasingUnit(
      id: 'imp_${idCounter++}',
      name: e.key,
      category: first.category.isNotEmpty ? first.category : 'Other',
      floor: first.floor.isNotEmpty ? first.floor : 'Ground Floor',
      status: _normalizeStatus(first.status),
      contact: first.contact.isNotEmpty ? first.contact : null,
      email: first.email.isNotEmpty ? first.email : null,
      notes: first.notes.isNotEmpty ? first.notes : null,
      areas: e.value
          .where((r) => r.sqft > 0)
          .map((r) => AreaEntry(
                type: _normalizeAreaType(r.areaType),
                sqft: r.sqft,
                rate: r.rate,
              ))
          .toList(),
    );
  }).toList();
}

// ── Bogineni native format parser ─────────────────────────────────────
// Columns: Floor/Levels | Area | Rate | Rent | Category
// Column A: entity name (present only on first row of each group)

List<LeasingUnit> _parseNativeFormat(List<List<Data?>> rows) {
  final units = <LeasingUnit>[];
  int idCounter = DateTime.now().millisecondsSinceEpoch;

  String currentName = '';
  String currentCategory = '';
  String currentStatus = '';
  final currentFloors = <String>[];
  final currentAreas = <AreaEntry>[];

  void flush() {
    if (currentName.isNotEmpty) {
      units.add(LeasingUnit(
        id: 'imp_${idCounter++}',
        name: currentName,
        category: currentCategory.isNotEmpty ? currentCategory : 'Other',
        floor: currentFloors.isNotEmpty
            ? currentFloors.join(' & ')
            : 'Ground Floor',
        status: _normalizeStatus(currentStatus),
        areas: List.of(currentAreas),
      ));
      currentFloors.clear();
      currentAreas.clear();
    }
  }

  for (int i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (row.isEmpty) continue;

    final colA = _str(row.elementAtOrNull(0)); // Entity name
    final colB = _str(row.elementAtOrNull(1)); // Floor / area type
    final colC = _num(row.elementAtOrNull(2)); // Sq.ft (area)
    final colD = _num(row.elementAtOrNull(3)); // Rate
    final colF = _str(row.elementAtOrNull(5)); // Category
    final colG = _str(row.elementAtOrNull(6)); // Status

    // Skip header row
    if (colB.toLowerCase().contains('floor') && colC == 0 && i == 0) continue;
    if (colB.toLowerCase() == 'area' || colA.toLowerCase() == 'floor') continue;

    // New entity starts when column A is non-empty (but not a stray
    // dimension note like "Indoor : 20 x 31ft", which some rows carry
    // in column A instead of leaving it blank).
    if (colA.isNotEmpty &&
        !_isFloorLabel(colA) &&
        !_isAreaTypeLabel(colA) &&
        !_looksLikeMeasurementNote(colA)) {
      flush();
      currentName = colA;
      currentCategory = _normalizeCategory(colF);
      currentStatus = colG;
    }

    if (colF.isNotEmpty) currentCategory = _normalizeCategory(colF);
    if (colG.isNotEmpty) currentStatus = colG;

    if (_isFloorLabel(colB)) {
      final normalized = _normalizeFloorLabel(colB);
      if (!currentFloors.contains(normalized)) currentFloors.add(normalized);
    } else if (_isAreaTypeLabel(colB) && colC > 0) {
      currentAreas.add(AreaEntry(
        type: _normalizeAreaType(colB),
        sqft: colC,
        rate: colD,
      ));
    }
  }
  flush();

  return units;
}

// ── Helpers ───────────────────────────────────────────────────────────

class _RowData {
  const _RowData({
    required this.name,
    required this.floor,
    required this.category,
    required this.areaType,
    required this.sqft,
    required this.rate,
    required this.status,
    required this.contact,
    required this.email,
    required this.notes,
  });

  final String name, floor, category, areaType, status, contact, email, notes;
  final double sqft, rate;
}

String _str(Data? cell) {
  if (cell == null) return '';
  final v = cell.value;
  if (v == null) return '';
  return v.toString().trim();
}

double _num(Data? cell) {
  if (cell == null) return 0;
  final v = cell.value;
  if (v == null) return 0;
  // CellValue is a sealed class — stringify and parse to stay version-agnostic
  final raw = v.toString().replaceAll(',', '').replaceAll('₹', '').trim();
  return double.tryParse(raw) ?? 0;
}

/// Fixes common source-sheet typos so the value matches
/// [LeasingUnit.categories] (falls back to the raw value otherwise, which
/// the edit form treats as a custom category).
String _normalizeCategory(String s) {
  final trimmed = s.trim();
  final l = trimmed.toLowerCase();
  if (l == 'resturant') return 'Restaurant';
  if (l == 'cafe & resturant') return 'Cafe & Restaurant';
  return trimmed;
}

bool _looksLikeMeasurementNote(String s) =>
    RegExp(r'\d+\s*[x×]\s*\d+', caseSensitive: false).hasMatch(s);

bool _isFloorLabel(String s) {
  final l = s.toLowerCase();
  return l.contains('floor') || l.contains('outdoor') || l == 'floor';
}

/// Fixes common source-sheet typos (e.g. "Secound Floor") so the stored
/// value matches [LeasingUnit.floors].
String _normalizeFloorLabel(String s) {
  final l = s.toLowerCase();
  if (l.contains('ground')) return 'Ground Floor';
  if (l.contains('first')) return 'First Floor';
  if (l.contains('sec')) return 'Second Floor'; // covers "Secound"/"Second"
  if (l.contains('outdoor')) return 'Outdoor';
  return s;
}

bool _isAreaTypeLabel(String s) {
  final l = s.toLowerCase();
  return l.contains('covered') || l.contains('open') || l.contains('common');
}

String _normalizeAreaType(String s) {
  final l = s.toLowerCase();
  if (l.contains('covered')) return 'covered';
  if (l.contains('open')) return 'open';
  if (l.contains('common')) return 'common';
  return 'covered';
}

String _normalizeStatus(String s) {
  final l = s.toLowerCase();
  if (l.contains('in-house') || l.contains('in house')) return 'in_house';
  if (l.contains('owner')) return 'owner_occupied';
  if (l.contains('vacant')) return 'vacant';
  if (l.contains('occupied')) return 'occupied';
  return 'vacant';
}
