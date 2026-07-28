import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/calendar_event.dart';

class CalendarRepository {
  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  Future<List<CalendarEvent>> getEvents(
      {DateTime? start, DateTime? end, String? eventType}) async {
    final params = <String, dynamic>{};
    if (start != null) params['start'] = start.toIso8601String();
    if (end != null) params['end'] = end.toIso8601String();
    if (eventType != null) params['event_type'] = eventType;
    final res = await ApiClient.instance.get(
      '/api/v1/calendar/',
      queryParameters: params.isEmpty ? null : params,
    );
    return ((res.data as List?) ?? [])
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CalendarEvent>> getUpcoming({int days = 30}) async {
    final res = await ApiClient.instance
        .get('/api/v1/calendar/upcoming', queryParameters: {'days': days});
    return ((res.data as List?) ?? [])
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CalendarEvent> createEvent(CalendarEvent event) async {
    final res = await ApiClient.instance.post(
      '/api/v1/calendar/',
      queryParameters: {if (_userId != null) 'user_id': _userId},
      data: event.toCreateJson(),
    );
    return CalendarEvent.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteEvent(String id) async {
    await ApiClient.instance.delete(
      '/api/v1/calendar/$id',
      queryParameters: {if (_userId != null) 'user_id': _userId},
    );
  }

  Future<void> syncFromLeases() async {
    await ApiClient.instance.post(
      '/api/v1/calendar/sync-from-leases',
      queryParameters: {if (_userId != null) 'user_id': _userId},
    );
  }
}
