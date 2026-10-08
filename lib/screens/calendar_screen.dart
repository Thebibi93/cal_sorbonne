import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../api/caldav.dart';
import '../data/masters.dart';
import '../providers/settings_provider.dart';
import 'settings_screen.dart';

class CalendarEvent {
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String location;
  final String masterId;
  final String masterLabel;
  final String? ue;
  final String originalTitle;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.location,
    required this.masterId,
    required this.masterLabel,
    this.ue,
    required this.originalTitle,
  });
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  List<CalendarEvent> _allEvents = [];
  bool _loading = true;
  List<Map<String, dynamic>> _errors = [];
  bool _isCached = false;
  Map<String, String> _colorByMaster = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final settings = context.read<SettingsProvider>();
    setState(() {
      _loading = true;
      _errors = [];
    });

    final mastersList = settings.selectedMasters
        .map(getMasterById)
        .whereType<Master>()
        .toList();

    try {
      final result = await fetchAllCalendars(mastersList);

      List<Map<String, dynamic>> rawEvents = List<Map<String, dynamic>>.from(
        result['events'],
      );
      List<Map<String, dynamic>> errors = List<Map<String, dynamic>>.from(
        result['errors'],
      );
      bool loadedFromCache = result['loadedFromCache'] as bool;

      List<CalendarEvent> enriched = rawEvents.map((ev) {
        String title = ev['title'] ?? '';
        String? ue = extractUe(title);
        return CalendarEvent(
          id: ev['id'],
          title: title,
          start: DateTime.parse(ev['start']),
          end: DateTime.parse(ev['end']),
          location: ev['location'] ?? '',
          masterId: ev['extendedProps']['masterId'],
          masterLabel: ev['extendedProps']['masterLabel'],
          ue: ue,
          originalTitle: title,
        );
      }).toList();

      Set<String> uesSet = enriched
          .map((ev) => ev.ue)
          .whereType<String>()
          .toSet();
      settings.updateAvailableUes(uesSet.toList()..sort());

      Map<String, String> colorMap = {};
      for (int i = 0; i < settings.selectedMasters.length; i++) {
        String id = settings.selectedMasters[i];
        colorMap[id] = getMasterColor(i);
      }

      if (!mounted) return;
      setState(() {
        _allEvents = enriched;
        _errors = errors;
        _isCached = loadedFromCache;
        _colorByMaster = colorMap;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  List<CalendarEvent> _getFilteredEvents() {
    final settings = context.read<SettingsProvider>();
    if (settings.selectedUes.isEmpty) return _allEvents;

    return _allEvents.where((ev) {
      if (ev.ue == null) return true;
      if (isAlwaysShown(ev.originalTitle)) return true;
      return settings.selectedUes.contains(ev.ue);
    }).toList();
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final settings = context.read<SettingsProvider>();
    return _getFilteredEvents().where((ev) => isSameDay(ev.start, day)).map((
      ev,
    ) {
      String displayTitle = settings.showOnlyRoom && ev.location.isNotEmpty
          ? ev.location
          : ev.title;
      return CalendarEvent(
        id: ev.id,
        title: displayTitle,
        start: ev.start,
        end: ev.end,
        location: ev.location,
        masterId: ev.masterId,
        masterLabel: ev.masterLabel,
        ue: ev.ue,
        originalTitle: ev.originalTitle,
      );
    }).toList();
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  Widget _buildEventCard(CalendarEvent event) {
    final color = _hexToColor(_colorByMaster[event.masterId] ?? '#3b82f6');
    final timeFormat = DateFormat('HH:mm');
    final timeStr =
        '${timeFormat.format(event.start)} - ${timeFormat.format(event.end)}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (event.ue != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              event.ue!,
                              style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (event.location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '📍 ${event.location}',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      event.masterLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDayEvents = _selectedDay != null
        ? _getEventsForDay(_selectedDay!)
        : <CalendarEvent>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendrier'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(onReloadRequired: _loadData),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isCached && !_loading)
            Container(
              width: double.infinity,
              color: Colors.green.shade50,
              padding: const EdgeInsets.all(8.0),
              child: const Text(
                '⚡ Emploi du temps chargé depuis le cache local',
                style: TextStyle(color: Colors.green, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          if (_errors.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.orange.shade50,
              padding: const EdgeInsets.all(8.0),
              child: Text(
                '⚠️ Impossible de charger : ${_errors.map((e) => e['master'].label).join(', ')}',
                style: const TextStyle(color: Colors.orange, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          if (_loading) const LinearProgressIndicator(),
          TableCalendar<CalendarEvent>(
            locale: 'fr_FR',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonShowsNext: false,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;
                return Positioned(
                  bottom: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: events.take(3).map((event) {
                      Color color = _hexToColor(
                        _colorByMaster[event.masterId] ?? '#3b82f6',
                      );
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.0),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: selectedDayEvents.isEmpty
                ? const Center(child: Text('Aucun cours ce jour-là.'))
                : ListView.builder(
                    itemCount: selectedDayEvents.length,
                    itemBuilder: (context, index) =>
                        _buildEventCard(selectedDayEvents[index]),
                  ),
          ),
        ],
      ),
    );
  }
}
