// Translation coverage checker for the QueueNova citizen mobile app.
//
// Run with:
//   dart run tool/check_translations.dart
//
// What it does (detection only — it never writes translations for you):
//   1. Compares assets/translations/en.json, si.json, ta.json and reports any
//      key that exists in one locale but not the others.
//   2. Scans lib/screens/, lib/services/, lib/providers/ and lib/main.dart
//      (the citizen-facing app — lib/web/ is the separate staff/admin portal
//      and is intentionally out of scope) for string literals that look like
//      hardcoded UI text NOT wrapped in `.tr()`, and lists them so a human
//      (or a future Claude session) can add proper translations for them.
//
// This is a heuristic, regex-based scan, not a full Dart parser — it will
// have some false positives (e.g. non-UI string constants) and can miss
// unusual code shapes. Treat its output as a checklist to review, not as a
// hard pass/fail gate.

import 'dart:convert';
import 'dart:io';

const _translationsDir = 'assets/translations';
const _locales = ['en', 'si', 'ta'];

// Directories/files that make up the citizen mobile app's UI surface.
// lib/web/ (staff/admin portal) is deliberately excluded — it does not use
// easy_localization at all today; see the conversation history for why.
const _scanTargets = [
  'lib/screens',
  'lib/services',
  'lib/providers',
  'lib/main.dart',
];

void main() {
  final projectRoot = Directory.current;
  print('QueueNova translation coverage check');
  print('=====================================\n');

  final keyIssues = _checkKeyParity(projectRoot);
  final stringIssues = _scanForUntranslatedStrings(projectRoot);

  print('\n-------------------------------------');
  print('Summary: $keyIssues key-parity issue(s), $stringIssues possibly-untranslated string(s) found.');
  if (keyIssues == 0 && stringIssues == 0) {
    print('Everything looks fully wired up. ✅');
  } else {
    print('Review the items above. Every entry needs a matching key added to');
    print('en.json / si.json / ta.json with a real Sinhala/Tamil translation —');
    print('this script only finds gaps, it does not fill them in.');
  }
}

/// Loads a JSON translation file as a flat String->String map.
Map<String, dynamic> _loadLocale(Directory root, String locale) {
  final file = File('${root.path}/$_translationsDir/$locale.json');
  if (!file.existsSync()) {
    stderr.writeln('ERROR: missing translation file ${file.path}');
    exit(1);
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

int _checkKeyParity(Directory root) {
  final locales = {for (final l in _locales) l: _loadLocale(root, l)};
  final allKeys = <String>{};
  for (final m in locales.values) {
    allKeys.addAll(m.keys);
  }

  var issues = 0;
  print('1. Key parity across ${_locales.join(', ')}.json');
  print('----------------------------------------------');
  for (final key in allKeys.toList()..sort()) {
    final missingIn = <String>[];
    for (final locale in _locales) {
      if (!locales[locale]!.containsKey(key)) missingIn.add(locale);
    }
    if (missingIn.isNotEmpty) {
      issues++;
      print('  "$key" is missing from: ${missingIn.join(', ')}');
    }
  }
  if (issues == 0) print('  All ${allKeys.length} keys are present in every locale.');
  return issues;
}

// Strings that look like format patterns, asset paths, URLs, or other
// non-natural-language content — safe to ignore even though they're quoted
// literals sitting next to UI code.
final _dateFormatPattern = RegExp(r"^[dMyHhmsaEE/\-:., ]+$");
final _looksLikeIdentifierOrCode = RegExp(r'^[a-z][a-zA-Z0-9_]*$');

bool _looksTranslatable(String s) {
  if (s.trim().isEmpty) return false;
  if (s.length < 2) return false;
  if (s.startsWith('http://') || s.startsWith('https://')) return false;
  if (s.startsWith('assets/') || s.startsWith('package:')) return false;
  if (_dateFormatPattern.hasMatch(s) && s.contains(RegExp(r'[dMyHhmsa]'))) return false;
  if (!RegExp(r'[A-Za-z]').hasMatch(s)) return false; // no letters at all
  // Single lower-camel identifier-looking token (e.g. 'pdf', 'lkr') is
  // usually a code/data value, not UI copy — unless it contains a space.
  if (!s.contains(' ') && _looksLikeIdentifierOrCode.hasMatch(s)) return false;
  // Needs to look like a sentence/label: starts uppercase, or contains a
  // space (multi-word UI copy almost always does).
  final looksLikeSentence = RegExp(r'^[A-Z]').hasMatch(s) || s.contains(' ');
  return looksLikeSentence;
}

// A quoted literal on a line that also contains one of these is very likely
// UI copy being rendered, as opposed to a data/key/route/color string.
final _uiContextHint = RegExp(
    r'Text\(|hintText\s*:|labelText\s*:|tooltip\s*:|:\s*Text\(|label\s*:|title\s*:|content\s*:');

// Matches 'single' or "double" quoted string literals, capturing the quote
// char and the body so we can look at what follows the closing quote.
final _stringLiteral = RegExp(r"""(['"])((?:\\.|(?!\1).)*)\1""");

int _scanForUntranslatedStrings(Directory root) {
  print('\n2. Hardcoded strings that are not wrapped in .tr()');
  print('----------------------------------------------------');

  var found = 0;
  final files = <File>[];
  for (final target in _scanTargets) {
    final entity = FileSystemEntity.typeSync('${root.path}/$target');
    if (entity == FileSystemEntityType.directory) {
      files.addAll(Directory('${root.path}/$target')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')));
    } else if (entity == FileSystemEntityType.file) {
      files.add(File('${root.path}/$target'));
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.startsWith('//')) continue;
      if (trimmed.startsWith('debugPrint(') || trimmed.startsWith('print(')) continue;
      if (!_uiContextHint.hasMatch(line)) continue;

      for (final match in _stringLiteral.allMatches(line)) {
        final body = match.group(2)!;
        if (!_looksTranslatable(body)) continue;

        final after = line.substring(match.end);
        if (after.trimLeft().startsWith('.tr(')) continue; // already localized
        if (after.trimLeft().startsWith('.tr,')) continue; // tear-off, rare

        found++;
        final relPath = file.path.substring(root.path.length + 1).replaceAll('\\', '/');
        print('  $relPath:${i + 1}: "$body"');
      }
    }
  }
  if (found == 0) print('  No un-.tr()\'d UI strings found in the scanned files.');
  return found;
}
