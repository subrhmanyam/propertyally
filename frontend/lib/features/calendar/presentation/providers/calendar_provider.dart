import '../../../../core/base/base_provider.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../domain/entities/calendar_event.dart';

class CalendarProvider extends BaseProvider {
  CalendarProvider() : _repo = CalendarRepository();

  final CalendarRepository _repo;

  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;
  List<CalendarEvent> _events = [];

  DateTime get focusedMonth => _focusedMonth;
  DateTime? get selectedDay => _selectedDay;
  List<CalendarEvent> get allEvents => _events;

  List<CalendarEvent> eventsForDay(DateTime day) => _events
      .where((e) =>
          e.startAt.year == day.year &&
          e.startAt.month == day.month &&
          e.startAt.day == day.day)
      .toList();

  List<CalendarEvent> get selectedDayEvents =>
      _selectedDay != null ? eventsForDay(_selectedDay!) : [];

  List<CalendarEvent> get upcomingEvents {
    final now = DateTime.now();
    return _events
        .where((e) => e.startAt.isAfter(now))
        .take(10)
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  Future<void> load() async {
    final start = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    final end = DateTime(_focusedMonth.year, _focusedMonth.month + 2, 0);
    await runAsync(() async {
      _events = await _repo.getEvents(start: start, end: end);
      return _events;
    });
  }

  void selectDay(DateTime day) {
    _selectedDay = day;
    notifyListeners();
  }

  void nextMonth() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    _selectedDay = null;
    notifyListeners();
    load();
  }

  void prevMonth() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    _selectedDay = null;
    notifyListeners();
    load();
  }

  Future<void> addEvent(CalendarEvent event) async {
    await runAsync(() async {
      final created = await _repo.createEvent(event);
      _events = [..._events, created];
      return created;
    });
  }

  Future<void> deleteEvent(String id) async {
    await runAsync(() async {
      await _repo.deleteEvent(id);
      _events = _events.where((e) => e.id != id).toList();
      return null;
    });
  }

  Future<void> syncFromLeases() async {
    await runAsync(() async {
      await _repo.syncFromLeases();
      await load();
      return null;
    });
  }
}
