import 'dart:convert';
import 'dart:io';

/// Reads all sono_*.arb files and writes a const map
/// of locale => completion fraction (0.0 - 1.0) based on
/// the English templates key set
///
/// Run with: dart run scripts/compute_translation_progress.dart
void main() {
  const translationsDir = 'lib/l10n/translations';
  const templatePath = '$translationsDir/sono_en.arb';
  const outputPath = 'lib/l10n/generated/translation_progress.dart';

  final templateJson =
      jsonDecode(File(templatePath).readAsStringSync()) as Map<String, dynamic>;

  //skip @@locale and any @-prefixed metadata keys
  final templateKeys = templateJson.keys
      .where((k) => !k.startsWith('@'))
      .toSet();
  final total = templateKeys.length;

  if (total == 0) {
    stderr.writeln('No translatabl keys in $templatePath');
    exit(1);
  }

  //pattern: sono_<locale>.arb
  final filenamePattern = RegExp(r'^sono_(.+)\.arb$');

  final completion = <String, double>{};
  for (final entity in Directory(translationsDir).listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    final match = filenamePattern.firstMatch(name);
    if (match == null) continue;
    final locale = match.group(1)!;

    final json = jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>;

    final translated = templateKeys.where((key) {
      final value = json[key];
      return value is String && value.trim().isNotEmpty;
    }).length;

    completion[locale] = translated / total;
  }

  final sorted = completion.keys.toList()..sort();
  final buffer = StringBuffer()
    ..writeln('// GENERATED – do not edit by hand!')
    ..writeln(
      '// Regenerate: dart run scripts/compute_translation_progress.dart',
    )
    ..writeln()
    ..writeln('/// Completion fraction (0.0 - 1.0) per locale code')
    ..writeln('const translationProgress = <String, double>{');
  for (final key in sorted) {
    buffer.writeln("   '$key': ${completion[key]!.toStringAsFixed(3)},");
  }
  buffer.writeln('};');

  Directory('lib/l10n/generated').createSync(recursive: true);
  File(outputPath).writeAsStringSync(buffer.toString());

  print('Wrote $outputPath');
  for (final key in sorted) {
    final pct = (completion[key]! * 100).toStringAsFixed(1);
    print('   $key -> $pct%');
  }
}
