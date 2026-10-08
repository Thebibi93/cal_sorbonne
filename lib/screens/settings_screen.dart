import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/masters.dart';
import '../providers/settings_provider.dart';
import '../api/caldav.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onReloadRequired;

  const SettingsScreen({super.key, required this.onReloadRequired});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isFetchingMasters = false;

  Future<void> _onMasterToggled(
    SettingsProvider settings,
    String masterId,
    bool isChecked,
  ) async {
    List<String> updatedMasters = List.from(settings.selectedMasters);
    if (isChecked) {
      updatedMasters.add(masterId);
    } else {
      updatedMasters.remove(masterId);
    }

    if (updatedMasters.isEmpty) return;

    // Enregistrer instantanément le nouveau Master
    await settings.setSelectedMasters(updatedMasters);

    setState(() {
      _isFetchingMasters = true;
    });

    // Recharger depuis le serveur pour mettre à jour les UEs disponibles
    final mastersList = updatedMasters
        .map(getMasterById)
        .whereType<Master>()
        .toList();

    try {
      final result = await fetchAllCalendars(mastersList);
      List<Map<String, dynamic>> rawEvents = List<Map<String, dynamic>>.from(
        result['events'],
      );

      Set<String> cleanUes = {};
      for (var ev in rawEvents) {
        String title = ev['title'] ?? '';
        for (var u in extractAllUes(title)) {
          cleanUes.add(u);
        }
      }

      settings.updateAvailableUes(cleanUes.toList()..sort());
      widget.onReloadRequired();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isFetchingMasters = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Row(
            children: [
              const Text(
                'Choisir mes masters',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (_isFetchingMasters) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ...masters.map((m) {
            final isChecked = settings.selectedMasters.contains(m.id);
            return CheckboxListTile(
              title: Text(m.label),
              value: isChecked,
              onChanged: _isFetchingMasters
                  ? null
                  : (val) {
                      if (val != null) {
                        _onMasterToggled(settings, m.id, val);
                      }
                    },
            );
          }),
          const Divider(height: 32),
          const Text(
            'Choisir mes UEs',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              "Cochez les UEs à afficher. Le filtre est appliqué instantanément.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          if (settings.availableUes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Aucune UE détectée pour le moment.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ...settings.availableUes.map((ue) {
            final isChecked = settings.selectedUes.contains(ue);
            return CheckboxListTile(
              title: Text(ue),
              value: isChecked,
              onChanged: (val) {
                if (val == null) return;
                List<String> currentSelected = List.from(settings.selectedUes);
                if (val) {
                  currentSelected.add(ue);
                } else {
                  currentSelected.remove(ue);
                }
                settings.setSelectedUes(currentSelected);
              },
            );
          }),
          const Divider(height: 32),
          const Text(
            'Affichage',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SwitchListTile(
            title: const Text('🏫 Afficher uniquement la salle'),
            subtitle: const Text('Remplace le nom du cours par la salle'),
            value: settings.showOnlyRoom,
            onChanged: (val) {
              settings.setShowOnlyRoom(val);
            },
          ),
        ],
      ),
    );
  }
}
