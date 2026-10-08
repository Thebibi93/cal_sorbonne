class Specialite {
  final String code;
  final String label;
  const Specialite({required this.code, required this.label});
}

class Master {
  final String id;
  final String label;
  final String path;
  const Master({required this.id, required this.label, required this.path});
}

const String caldavHost = 'https://cal.ufr-info-p6.jussieu.fr';
const String caldavBase = '/caldav.php';
const String defaultUsername = 'student.master';
const String defaultPassword = 'guest';

const List<Master> masters = [
  Master(id: 'm1-androide', label: 'M1_ANDROIDE', path: 'ANDROIDE/M1_ANDROIDE'),
  Master(id: 'm2-androide', label: 'M2_ANDROIDE', path: 'ANDROIDE/M2_ANDROIDE'),

  Master(id: 'm1-bim', label: 'M1_BIM', path: 'BIM/M1_BIM'),
  Master(id: 'm2-bim', label: 'M2_BIM', path: 'BIM/M2_BIM'),

  Master(id: 'm1-dac', label: 'M1_DAC', path: 'DAC/M1_DAC'),
  Master(id: 'm2-dac', label: 'M2_DAC', path: 'DAC/M2_DAC'),

  Master(id: 'm1-ima', label: 'M1_IMA', path: 'IMA/M1_IMA'),
  Master(id: 'm2-ima', label: 'M2_IMA', path: 'IMA/M2_IMA'),

  Master(id: 'm1-iq', label: 'M1_IQ', path: 'IQ/M1_IQ'),
  Master(id: 'm2-iq', label: 'M2_IQ', path: 'IQ/M2_IQ'),

  Master(
    id: 'm1-res-digital',
    label: 'M1_DIGITAL',
    path: 'RES/M1_RES-EIT-Digital',
  ),
  Master(id: 'm1-res', label: 'M1_RES', path: 'RES/M1_RES'),
  Master(id: 'm1-res-alt', label: 'M1_RES_ALT', path: 'RES/M1_RES-ITESCIA'),
  Master(
    id: 'm2-res-digital',
    label: 'M2_DIGITAL',
    path: 'RES/M2_RES-EIT-Digital',
  ),
  Master(id: 'm2-res', label: 'M2_RES', path: 'RES/M2_RES'),
  Master(id: 'm2-res-dev', label: 'M2_RES-DEV', path: 'RES/M2_RES-INSTA'),
  Master(id: 'm2-res-sec', label: 'M2_RES-SEC', path: 'RES/M2_RES-ITESCIA'),

  Master(id: 'm1-sar', label: 'M1_SAR', path: 'SAR/M1_SAR'),
  Master(id: 'm2-sar', label: 'M2_SAR', path: 'SAR/M2_SAR'),

  Master(id: 'm1-sesi', label: 'M1_SESI', path: 'SESI/M1_SESI'),
  Master(id: 'm2-sesi', label: 'M2_SESI', path: 'SESI/M2_SESI'),

  Master(id: 'm1-cca', label: 'M1_CCA', path: 'SFPN/M1_SFPN'),
  Master(id: 'm1-ssi-alt', label: 'M1_SSI-ALT', path: 'SFPN/M1_SFPN-AFTI'),
  Master(id: 'm2-cca', label: 'M2_CCA', path: 'SFPN/M2_SFPN'),
  Master(id: 'm2-ssi-alt', label: 'M2_SSI-ALT', path: 'SFPN/M2_SFPN-AFTI'),

  Master(id: 'm1-stl', label: 'M1_STL', path: 'STL/M1_STL'),
  Master(id: 'm2-stl', label: 'M2_STL', path: 'STL/M2_STL'),
  Master(id: 'm2-stl-insta', label: 'M2_STL-INSTA', path: 'STL/M2_STL-INSTA'),
];

const List<String> colors = [
  '#3b82f6',
  '#ef4444',
  '#10b981',
  '#f59e0b',
  '#8b5cf6',
  '#ec4899',
  '#06b6d4',
  '#84cc16',
  '#f97316',
  '#14b8a6',
  '#a855f7',
  '#eab308',
  '#64748b',
  '#f43f5e',
];

Master? getMasterById(String id) {
  try {
    return masters.firstWhere((m) => m.id == id);
  } catch (e) {
    return null;
  }
}

String getMasterUrl(Master master) {
  return '$caldavHost$caldavBase/${master.path}';
}

String getMasterColor(int index) {
  return colors[index % colors.length];
}

const Set<String> sessionTypes = {
  'COURS',
  'TME',
  'TD',
  'TP',
  'CM',
  'EXAM',
  'EXAMEN',
  'EXAMENS',
  'AMPHI',
  'CONF',
  'REUNION',
  'RÉUNION',
  'SOUTENANCE',
  'ANNUL',
  'ANNULATION',
};

bool isSessionType(String? token) {
  if (token == null) return false;
  return sessionTypes.contains(token.toUpperCase());
}

final RegExp alwaysShownPattern = RegExp(
  r'\b(soutenance|soutenances|th[eè]se|jury|r[eé]union\s+info|amphi\s+g[eé]n[eé]ral)',
  caseSensitive: false,
);

bool isAlwaysShown(String? summary) {
  return alwaysShownPattern.hasMatch(summary ?? '');
}

List<String> mergeUes(List<String> rawUes) {
  final Map<String, String> ueMap = {};

  for (final ue in rawUes) {
    final matchCode = RegExp(
      r'^(UM\d[0-9A-Z]+)',
      caseSensitive: false,
    ).firstMatch(ue);
    if (matchCode == null) continue;

    final code = matchCode.group(1)!.toUpperCase();
    final hasLabel = ue.contains(' - ');

    if (!ueMap.containsKey(code)) {
      ueMap[code] = ue;
    } else {
      if (hasLabel && !ueMap[code]!.contains(' - ')) {
        ueMap[code] = ue;
      }
    }
  }

  return ueMap.values.toList()..sort();
}

List<String> extractAllUes(String? summary) {
  if (summary == null) return [];
  String s = summary
      .replaceFirst(RegExp(r'^ANNULE[-\s]*', caseSensitive: false), '')
      .trim();

  final codeRegex = RegExp(r'\b(UM\d[0-9A-Z]+)\b', caseSensitive: false);
  final matches = codeRegex.allMatches(s);

  if (matches.isEmpty) return [];

  final List<String> ues = [];
  final tokens = s
      .split(RegExp(r'[\s\-–—/\\_]+'))
      .where((t) => t.isNotEmpty)
      .toList();

  for (final match in matches) {
    final code = match.group(1)!.toUpperCase();
    String? label;

    int codeIdx = tokens.indexWhere((t) => t.toUpperCase() == code);
    if (codeIdx != -1) {
      for (int i = codeIdx + 1; i < tokens.length; i++) {
        final t = tokens[i].toUpperCase();
        if (!isSessionType(t) && t != 'AND' && !t.startsWith('UM')) {
          label = t;
          break;
        }
      }
    }

    if (label != null) {
      ues.add('$code - $label');
    } else {
      ues.add(code);
    }
  }

  return mergeUes(ues);
}

String? extractUe(String? summary) {
  final list = extractAllUes(summary);
  return list.isNotEmpty ? list.first : null;
}

bool shouldShowEvent(String? title, List<String> selectedUes) {
  if (title == null || title.isEmpty) return true;
  if (isAlwaysShown(title)) return true;

  final eventUes = extractAllUes(title);

  if (eventUes.isEmpty) return true;

  for (final eventUe in eventUes) {
    final eventBaseCode = eventUe.split(' - ').first;

    for (final selected in selectedUes) {
      final selectedBaseCode = selected.split(' - ').first;
      if (eventBaseCode == selectedBaseCode) return true;
    }
  }

  return false;
}
