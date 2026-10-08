import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/masters.dart';

const String cachePrefix = 'caldav_ics_cache_';
const String etagPrefix = 'caldav_etag_';

DateTime? parseIcsDate(String? dateStr) {
  if (dateStr == null) return null;
  String cleanStr = dateStr.contains(':') ? dateStr.split(':').last : dateStr;
  RegExp regExp = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$',
  );
  Match? match = regExp.firstMatch(cleanStr.trim());
  if (match == null) {
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return null;
    }
  }
  int y = int.parse(match.group(1)!);
  int m = int.parse(match.group(2)!);
  int d = int.parse(match.group(3)!);
  if (match.group(4) == null) {
    return DateTime.utc(y, m, d);
  }
  int hh = int.parse(match.group(4)!);
  int mm = int.parse(match.group(5)!);
  int ss = int.parse(match.group(6)!);
  if (match.group(7) == 'Z') {
    return DateTime.utc(y, m, d, hh, mm, ss);
  }
  return DateTime(y, m, d, hh, mm, ss);
}

String unfoldIcs(String icsData) {
  return icsData
      .replaceAll(RegExp(r'\r\n[ \t]'), '')
      .replaceAll(RegExp(r'\n[ \t]'), '');
}

List<Map<String, dynamic>> parseIcsNative(
  String icsData,
  DateTime startRange,
  DateTime endRange,
) {
  String unfolded = unfoldIcs(icsData);
  RegExp veventRegex = RegExp(
    r'BEGIN:VEVENT([\s\S]*?)END:VEVENT',
    caseSensitive: false,
  );
  List<Map<String, dynamic>> events = [];

  Iterable<Match> matches = veventRegex.allMatches(unfolded);
  for (Match match in matches) {
    String block = match.group(1)!;
    List<String> lines = block.split(RegExp(r'\r?\n'));
    String summary = '';
    String location = '';
    String description = '';
    String uid = '';
    String dtStartRaw = '';
    String dtEndRaw = '';
    String rruleStr = '';
    List<int> exdates = [];

    for (String line in lines) {
      int colIdx = line.indexOf(':');
      if (colIdx == -1) continue;
      String keyPart = line.substring(0, colIdx).toUpperCase();
      String valPart = line.substring(colIdx + 1).trim();

      if (keyPart.startsWith('SUMMARY')) {
        summary = valPart;
      } else if (keyPart.startsWith('LOCATION'))
        location = valPart;
      else if (keyPart.startsWith('DESCRIPTION'))
        description = valPart;
      else if (keyPart.startsWith('UID'))
        uid = valPart;
      else if (keyPart.startsWith('DTSTART'))
        dtStartRaw = valPart;
      else if (keyPart.startsWith('DTEND'))
        dtEndRaw = valPart;
      else if (keyPart.startsWith('RRULE'))
        rruleStr = valPart;
      else if (keyPart.startsWith('EXDATE')) {
        for (String ex in valPart.split(',')) {
          DateTime? parsedEx = parseIcsDate(ex);
          if (parsedEx != null) exdates.add(parsedEx.millisecondsSinceEpoch);
        }
      }
    }

    DateTime? startDate = parseIcsDate(dtStartRaw);
    if (startDate == null) continue;

    DateTime? endDate = parseIcsDate(dtEndRaw);
    int durationMs = endDate != null
        ? endDate.difference(startDate).inMilliseconds
        : 2 * 3600 * 1000;
    endDate ??= startDate.add(Duration(milliseconds: durationMs));

    if (rruleStr.isNotEmpty) {
      Map<String, String> rruleObj = {};
      for (String part in rruleStr.split(';')) {
        List<String> kv = part.split('=');
        if (kv.length == 2) rruleObj[kv[0].toUpperCase()] = kv[1];
      }

      DateTime untilDate = rruleObj.containsKey('UNTIL')
          ? (parseIcsDate(rruleObj['UNTIL']) ?? endRange)
          : endRange;
      DateTime effectiveEnd = untilDate.isBefore(endRange)
          ? untilDate
          : endRange;
      String freq = rruleObj['FREQ'] ?? 'WEEKLY';
      int interval = int.tryParse(rruleObj['INTERVAL'] ?? '1') ?? 1;

      Map<String, int> byDayMap = {
        'SU': 0,
        'MO': 1,
        'TU': 2,
        'WE': 3,
        'TH': 4,
        'FR': 5,
        'SA': 6,
      };
      List<int>? targetDays;
      if (rruleObj.containsKey('BYDAY')) {
        targetDays = rruleObj['BYDAY']!
            .split(',')
            .map((d) => byDayMap[d.trim().toUpperCase()])
            .where((d) => d != null)
            .cast<int>()
            .toList();
      }

      DateTime curr = DateTime.fromMillisecondsSinceEpoch(
        startDate.millisecondsSinceEpoch,
      );
      int maxCount = int.tryParse(rruleObj['COUNT'] ?? '500') ?? 500;
      int count = 0;

      while (!curr.isAfter(effectiveEnd) && count < maxCount) {
        int dayOfWeek = curr.weekday % 7;
        bool isDayMatched =
            targetDays == null || targetDays.contains(dayOfWeek);

        if (!curr.isBefore(startRange) && isDayMatched) {
          int currTime = curr.millisecondsSinceEpoch;
          bool isExcluded = exdates.any(
            (exTime) => (exTime - currTime).abs() < 120000,
          );

          if (!isExcluded) {
            events.add({
              'uid': uid,
              'summary': summary.isNotEmpty ? summary : 'Sans titre',
              'title': summary.isNotEmpty ? summary : 'Sans titre',
              'start': curr,
              'end': curr.add(Duration(milliseconds: durationMs)),
              'location': location,
              'description': description,
            });
          }
          count++;
        }

        if (freq == 'DAILY') {
          curr = curr.add(Duration(days: interval));
        } else if (freq == 'WEEKLY') {
          if (targetDays != null && targetDays.length > 1) {
            curr = curr.add(const Duration(days: 1));
          } else {
            curr = curr.add(Duration(days: 7 * interval));
          }
        } else if (freq == 'MONTHLY') {
          curr = DateTime(
            curr.year,
            curr.month + interval,
            curr.day,
            curr.hour,
            curr.minute,
            curr.second,
          );
        } else {
          curr = curr.add(const Duration(days: 7));
        }
      }
    } else {
      if (!startDate.isBefore(startRange) && !startDate.isAfter(endRange)) {
        events.add({
          'uid': uid,
          'summary': summary.isNotEmpty ? summary : 'Sans titre',
          'title': summary.isNotEmpty ? summary : 'Sans titre',
          'start': startDate,
          'end': endDate,
          'location': location,
          'description': description,
        });
      }
    }
  }
  return events;
}

Future<Map<String, dynamic>> fetchCalendar(Master master) async {
  String url = getMasterUrl(master);
  String authHeader =
      'Basic ${base64Encode(utf8.encode('$defaultUsername:$defaultPassword'))}';
  String cacheKey = cachePrefix + master.id;
  String etagKey = etagPrefix + master.id;

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? cachedEtag = prefs.getString(etagKey);
  Map<String, String> headers = {
    'Accept': 'text/calendar',
    'Authorization': authHeader,
  };
  if (cachedEtag != null) {
    headers['If-None-Match'] = cachedEtag;
  }

  String? icsData;
  bool isFromCache = false;

  try {
    http.Response response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 304) {
      icsData = prefs.getString(cacheKey);
      isFromCache = true;
    } else if (response.statusCode == 200) {
      icsData = response.body;
      String? newEtag = response.headers['etag'];
      if (newEtag != null) await prefs.setString(etagKey, newEtag);
      if (icsData.isNotEmpty) await prefs.setString(cacheKey, icsData);
    } else if (response.statusCode == 401) {
      throw Exception('Authentification refusée pour ${master.label}');
    } else {
      throw Exception('HTTP ${response.statusCode} pour ${master.label}');
    }
  } catch (err) {
    icsData = prefs.getString(cacheKey);
    if (icsData != null) {
      isFromCache = true;
    } else {
      rethrow;
    }
  }

  if (icsData == null || icsData.isEmpty) {
    return {'events': [], 'isFromCache': false};
  }

  List<Map<String, dynamic>> parsedEvents = parseIcs(icsData, master);
  return {'events': parsedEvents, 'isFromCache': isFromCache};
}

List<Map<String, dynamic>> parseIcs(String icsData, Master master) {
  DateTime startRange = DateTime(2000, 1, 1);
  DateTime endRange = DateTime(2100, 12, 31);

  List<Map<String, dynamic>> rawEvents = parseIcsNative(
    icsData,
    startRange,
    endRange,
  );

  return rawEvents.asMap().entries.map((entry) {
    int idx = entry.key;
    Map<String, dynamic> event = entry.value;
    DateTime startDate = event['start'] is DateTime
        ? event['start']
        : (parseIcsDate(event['start'].toString()) ?? DateTime.now());
    DateTime endDate = event['end'] is DateTime
        ? event['end']
        : (parseIcsDate(event['end'].toString()) ??
              startDate.add(const Duration(hours: 2)));

    return {
      'id':
          '${master.id}-${event['uid'] ?? idx}-${startDate.millisecondsSinceEpoch}',
      'title': event['title'] ?? event['summary'] ?? 'Sans titre',
      'start': startDate.toIso8601String(),
      'end': endDate.toIso8601String(),
      'location': event['location'] ?? '',
      'description': event['description'] ?? '',
      'extendedProps': {'masterId': master.id, 'masterLabel': master.label},
    };
  }).toList();
}

Future<Map<String, dynamic>> fetchAllCalendars(List<Master> mastersList) async {
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> errors = [];
  bool loadedFromCache = false;

  for (final m in mastersList) {
    try {
      final res = await fetchCalendar(m);
      final List<dynamic> evs = res['events'] as List<dynamic>;
      events.addAll(evs.cast<Map<String, dynamic>>());
      if (res['isFromCache'] == true) loadedFromCache = true;
    } catch (e) {
      errors.add({'master': m, 'message': e.toString()});
    }
  }

  return {
    'events': events,
    'errors': errors,
    'loadedFromCache': loadedFromCache,
  };
}
