import 'dart:io';

import '../data/local/seed/seed_models.dart';

const _inputPath = 'seed_source/lift_catalog.csv';
const _outputPath = 'lib/data/local/seed/lift_catalog_seed.generated.dart';

const _requiredHeaders = {
  'lift_key',
  'name',
  'equipment',
  'score_type',
  'input_mode',
  'primary_muscles',
  'secondary_muscles',
  'needs_review',
};

final _liftKeyPattern = RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$');

void main() {
  final inputFile = File(_inputPath);
  if (!inputFile.existsSync()) {
    throw StateError('CSV file not found at $_inputPath');
  }

  final lines = inputFile.readAsLinesSync();
  if (lines.isEmpty) {
    throw StateError('CSV file is empty: $_inputPath');
  }

  final headers = _parseCsvLine(lines.first).map((h) => h.trim()).toList();
  final headerIndex = <String, int>{};
  for (var i = 0; i < headers.length; i++) {
    headerIndex[headers[i]] = i;
  }

  final missingHeaders = _requiredHeaders.where((h) => !headerIndex.containsKey(h)).toList();
  if (missingHeaders.isNotEmpty) {
    throw StateError('Missing required CSV headers: ${missingHeaders.join(', ')}');
  }

  final lifts = <SeedLift>[];
  final seenLiftKeys = <String>{};
  final muscleKeyOrder = <String>[];
  final seenMuscleKeys = <String>{};

  for (var lineNumber = 2; lineNumber <= lines.length; lineNumber++) {
    final line = lines[lineNumber - 1];
    if (line.trim().isEmpty) continue;

    final values = _parseCsvLine(line);
    String getValue(String header) {
      final idx = headerIndex[header]!;
      if (idx >= values.length) return '';
      return values[idx].trim();
    }

    final needsReview = getValue('needs_review');
    if (needsReview.isNotEmpty && needsReview != '0') {
      continue;
    }

    final liftKey = getValue('lift_key');
    final name = getValue('name');
    final equipment = getValue('equipment');
    final scoreType = getValue('score_type');
    final inputMode = getValue('input_mode');
    final primaryMuscle = getValue('primary_muscles');
    final secondaryMusclesRaw = getValue('secondary_muscles');

    final requiredValues = {
      'lift_key': liftKey,
      'name': name,
      'equipment': equipment,
      'score_type': scoreType,
      'input_mode': inputMode,
      'primary_muscles': primaryMuscle,
    };
    final blankRequired = requiredValues.entries.where((e) => e.value.isEmpty).map((e) => e.key).toList();
    if (blankRequired.isNotEmpty) {
      throw StateError('Line $lineNumber has blank required fields: ${blankRequired.join(', ')}');
    }

    if (!_liftKeyPattern.hasMatch(liftKey)) {
      throw StateError('Line $lineNumber has invalid lift_key "$liftKey". Expected snake_case.');
    }

    if (!seenLiftKeys.add(liftKey)) {
      throw StateError('Duplicate lift_key "$liftKey" found at line $lineNumber.');
    }

    void addMuscle(String key) {
      if (seenMuscleKeys.add(key)) muscleKeyOrder.add(key);
    }

    addMuscle(primaryMuscle);

    final liftMuscles = <SeedLiftMuscleGroup>[
      SeedLiftMuscleGroup(muscleKey: primaryMuscle, role: 'primary', sortOrder: 1),
    ];

    var secondarySort = 2;
    for (final secondary in secondaryMusclesRaw.split(';')) {
      final muscle = secondary.trim();
      if (muscle.isEmpty) continue;
      addMuscle(muscle);
      liftMuscles.add(
        SeedLiftMuscleGroup(muscleKey: muscle, role: 'secondary', sortOrder: secondarySort++),
      );
    }

    lifts.add(
      SeedLift(
        liftKey: liftKey,
        name: name,
        scoreType: scoreType,
        equipment: equipment,
        inputMode: inputMode,
        muscleGroups: liftMuscles,
      ),
    );
  }

  final muscleGroups = <SeedMuscleGroup>[];
  for (var i = 0; i < muscleKeyOrder.length; i++) {
    final key = muscleKeyOrder[i];
    muscleGroups.add(
      SeedMuscleGroup(
        muscleKey: key,
        name: _displayNameFromMuscleKey(key),
        sortOrder: i + 1,
      ),
    );
  }

  final output = StringBuffer()
    ..writeln("import 'seed_models.dart';")
    ..writeln()
    ..writeln('const generatedMuscleGroups = [');

  for (final m in muscleGroups) {
    output.writeln(
      "  SeedMuscleGroup(muscleKey: '${_escape(m.muscleKey)}', name: '${_escape(m.name)}', sortOrder: ${m.sortOrder}),",
    );
  }
  output
    ..writeln('];')
    ..writeln()
    ..writeln('const generatedLifts = [');

  for (final lift in lifts) {
    output.writeln('  SeedLift(');
    output.writeln("    liftKey: '${_escape(lift.liftKey)}',");
    output.writeln("    name: '${_escape(lift.name)}',");
    output.writeln("    scoreType: '${_escape(lift.scoreType)}',");
    output.writeln("    equipment: '${_escape(lift.equipment ?? '')}',");
    output.writeln("    inputMode: '${_escape(lift.inputMode)}',");
    output.writeln('    muscleGroups: [');
    for (final muscle in lift.muscleGroups) {
      output.writeln(
        "      SeedLiftMuscleGroup(muscleKey: '${_escape(muscle.muscleKey)}', role: '${_escape(muscle.role)}', sortOrder: ${muscle.sortOrder}),",
      );
    }
    output.writeln('    ],');
    output.writeln('  ),');
  }

  output.writeln('];');

  final outputFile = File(_outputPath);
  outputFile.writeAsStringSync(output.toString());
  stdout.writeln('Generated ${lifts.length} lifts and ${muscleGroups.length} muscle groups at $_outputPath');
}

List<String> _parseCsvLine(String line) {
  final result = <String>[];
  final current = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        current.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      result.add(current.toString());
      current.clear();
    } else {
      current.write(char);
    }
  }
  result.add(current.toString());
  return result;
}

String _displayNameFromMuscleKey(String key) =>
    key.split('_').map((part) => '${part[0].toUpperCase()}${part.substring(1)}').join(' ');

String _escape(String value) => value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
