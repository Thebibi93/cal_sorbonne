import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String storageKey = 'calendrier-masters.selection';
  static const String ueKey = 'calendrier-masters.ues';
  static const String roomKey = 'calendrier-masters.showOnlyRoom';

  List<String> _selectedMasters = [];
  List<String> _selectedUes = [];
  bool _showOnlyRoom = false;
  List<String> _availableUes = [];

  List<String> get selectedMasters => _selectedMasters;
  List<String> get selectedUes => _selectedUes;
  bool get showOnlyRoom => _showOnlyRoom;
  List<String> get availableUes => _availableUes;
  bool get hasConfigured => _selectedMasters.isNotEmpty;

  Future<void> loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    try {
      String? rawMasters = prefs.getString(storageKey);
      if (rawMasters != null) {
        _selectedMasters = List<String>.from(jsonDecode(rawMasters));
      }
      String? rawUes = prefs.getString(ueKey);
      if (rawUes != null) _selectedUes = List<String>.from(jsonDecode(rawUes));
      _showOnlyRoom = prefs.getBool(roomKey) ?? false;
    } catch (e) {
      _selectedMasters = [];
      _selectedUes = [];
      _showOnlyRoom = false;
    }
    notifyListeners();
  }

  Future<void> setSelectedMasters(List<String> masters) async {
    _selectedMasters = masters;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(masters));
    notifyListeners();
  }

  Future<void> setSelectedUes(List<String> ues) async {
    _selectedUes = ues;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(ueKey, jsonEncode(ues));
    notifyListeners();
  }

  Future<void> setShowOnlyRoom(bool value) async {
    _showOnlyRoom = value;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(roomKey, value);
    notifyListeners();
  }

  void updateAvailableUes(List<String> newUes) {
    _availableUes = newUes;
    // Si aucune UE n'était sélectionnée ou qu'on vient de changer de master,
    // on coche toutes les nouvelles UEs par défaut localement.
    if (_selectedUes.isEmpty) {
      _selectedUes = List.from(newUes);
    } else {
      // Conserver uniquement les UEs sélectionnées qui existent dans la nouvelle liste
      _selectedUes = _selectedUes.where((ue) => newUes.contains(ue)).toList();
      if (_selectedUes.isEmpty) {
        _selectedUes = List.from(newUes);
      }
    }
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(ueKey, jsonEncode(_selectedUes));
    });
    notifyListeners();
  }
}
