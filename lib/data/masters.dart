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

const List<Specialite> specialites = [
  Specialite(code: 'DAC', label: 'DAC'),
  Specialite(code: 'STL', label: 'STL'),
  Specialite(code: 'SAR', label: 'SAR'),
  Specialite(code: 'BIOINFO', label: 'Bio-informatique'),
  Specialite(code: 'AGREG', label: 'Agrégation'),
  Specialite(code: 'ANDROIDE', label: 'Android'),
];

const List<String> levels = ['M1', 'M2'];

final List<Master> masters = levels.expand((level) {
  return specialites.map((spec) {
    return Master(
      id: '$level-${spec.code}'.toLowerCase(),
      label: '$level ${spec.label}',
      path: '${spec.code}/${level}_${spec.code}',
    );
  });
}).toList();

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
  return token
      .split(RegExp(r'[\/\s\-]+'))
      .where((t) => t.isNotEmpty)
      .any((t) => sessionTypes.contains(t.toUpperCase()));
}

List<String> extractAllUes(String? summary) {
  if (summary == null) return [];
  String s = summary
      .replaceFirst(RegExp(r'^ANNULE[-\s]*', caseSensitive: false), '')
      .trim();

  // Exige strictement UM suivi d'un chiffre (ex: UM4IN500, UM4LVAN2)
  final ueRegex = RegExp(
    r'\b(UM\d[0-9A-Z]+)(?:\s*[-\\]\s*|\s+)([A-Z0-9]+)?\b',
    caseSensitive: false,
  );

  List<String> ues = [];
  final matches = ueRegex.allMatches(s);

  for (final match in matches) {
    String code = match.group(1)!.toUpperCase();
    String? name = match.group(2);

    if (name != null && !isSessionType(name) && name.toUpperCase() != 'AND') {
      ues.add('$code - ${name.toUpperCase()}');
    } else {
      ues.add(code);
    }
  }

  return ues.toSet().toList();
}

/// Retourne l'UE principale du titre
String? extractUe(String? summary) {
  final list = extractAllUes(summary);
  return list.isNotEmpty ? list.first : null;
}

final RegExp alwaysShownPattern = RegExp(
  r'\b(soutenance|soutenances|th[eè]se|jury|r[eé]union\s+info|amphi\s+g[eé]n[eé]ral)',
  caseSensitive: false,
);

bool isAlwaysShown(String? summary) {
  return alwaysShownPattern.hasMatch(summary ?? '');
}
