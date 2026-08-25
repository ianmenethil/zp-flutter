// Checks every CLAUDE.md in this repo against scripts/claude_md_template.md,
// the single source of truth for what a CLAUDE.md must contain.
//
// Usage (from the repository root):
//   dart run scripts/check_claude_md.dart                          # every git-tracked CLAUDE.md
//   dart run scripts/check_claude_md.dart zenpay_dart/CLAUDE.md    # just one file
//
// Exit codes: 0 = every checked file conforms, 1 = violations reported,
// 64 = usage error.
//
// The template carries two kinds of rule (see claude_md_template.md for the
// full contract):
//   1. Required sections — the template's `## ` headings must appear as
//      headings in each document, in the same order.
//   2. File coverage — every file matched by a template `coverage:` glob
//      (expanded relative to the CLAUDE.md's own directory) must appear as a
//      dedicated entry: the file's path anywhere inside a heading or bullet
//      line. A passing mention inside prose does not count — the point of the
//      rule is a guide that *displays* every underlying source file with an
//      explanation of what it contains, not one that merely name-drops them.
import 'dart:convert';
import 'dart:io';

/// The parsed contract from `claude_md_template.md`.
final class ClmTemplate {
  const ClmTemplate({required this.requiredSections, required this.coverageGlobs});

  /// Section names (without the `## ` prefix) that must appear as `## `
  /// headings in every document, in this order.
  final List<String> requiredSections;

  /// File globs, relative to each CLAUDE.md's directory, whose every match
  /// must have a dedicated entry in that CLAUDE.md. Supported shapes:
  /// `*.ext` (top level of the directory only) and `dir/**/*.ext`
  /// (recursive).
  final List<String> coverageGlobs;
}

/// Parses [text] (the template file's contents) into its rules: every
/// `## ` heading becomes a required section, every `coverage: <glob>` line a
/// coverage glob; everything else is documentation and ignored.
ClmTemplate parseTemplate(String text) {
  final sections = <String>[];
  final globs = <String>[];
  for (final line in text.split('\n')) {
    final section = RegExp(r'^##\s+(.+)$').firstMatch(line.trim());
    if (section != null) {
      sections.add(section.group(1)!.trim());
      continue;
    }
    final coverage = RegExp(r'^coverage:\s*(\S+)$').firstMatch(line.trim());
    if (coverage != null) globs.add(coverage.group(1)!);
  }
  return ClmTemplate(requiredSections: sections, coverageGlobs: globs);
}

/// Checks [docText] (a CLAUDE.md's contents) against [template], expanding the
/// template's coverage globs under [sourceDir] (the CLAUDE.md's own
/// directory). Returns one human-readable violation per problem, empty when
/// the document conforms. Pure aside from the glob filesystem reads, so tests
/// can drive it with temp-directory fixtures.
List<String> checkClaudeMd({required String docText, required String sourceDir, required ClmTemplate template}) {
  final violations = <String>[];
  // Normalize CRLF/CR line endings first — a trailing \r makes Dart's `$`
  // anchor miss, so the heading and entry regexes below must see clean line
  // strings (mixed-ending repos hit this with CRLF files).
  final lines = docText.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

  // Every document must open with a top-level `# ` title.
  if (!lines.any((line) => RegExp(r'^#\s').hasMatch(line))) {
    violations.add('missing top-level `# ` title');
  }

  // Required sections: template order must be preserved in the document. A
  // document heading satisfies a required section when its text starts with
  // the section name, ignoring a leading `N. ` number — so
  // `## 3. Verification Commands` satisfies `## Verification`.
  final headingTexts = <String>[];
  for (final line in lines) {
    final heading = RegExp(r'^##\s+(.*)$').firstMatch(line);
    if (heading != null) {
      headingTexts.add(heading.group(1)!.trim().replaceFirst(RegExp(r'^\d+[.)]\s*'), ''));
    }
  }
  final foundAt = <int>[];
  for (final section in template.requiredSections) {
    final index = headingTexts.indexWhere((heading) => heading.startsWith(section));
    if (index == -1) {
      violations.add('missing section: ## $section');
    } else {
      foundAt.add(index);
    }
  }
  for (var i = 1; i < foundAt.length; i++) {
    if (foundAt[i] <= foundAt[i - 1]) {
      violations.add(
        'sections out of order: ## ${template.requiredSections[i]} '
        'appears before ## ${template.requiredSections[i - 1]}',
      );
      break;
    }
  }

  // File coverage: every file the globs expand to must have a dedicated
  // entry. Paths are made relative to the CLAUDE.md's own directory so the
  // same `lib/src/foo.dart` style the guides use is what gets matched.
  final sourcePrefix = _forward(sourceDir);
  for (final glob in template.coverageGlobs) {
    for (final filePath in _expandGlob(glob, sourcePrefix)) {
      final relative = filePath.substring(sourcePrefix.length + 1);
      if (!_hasEntry(relative, lines)) {
        violations.add('missing file entry: $relative');
      }
    }
  }
  return violations;
}

/// True when [path] has a dedicated entry — a heading (`### ...`) or bullet
/// (`- `/`* `) line containing the path anywhere in it, so both styles in use
/// pass: `` ### `lib/src/foo.dart` `` and the link style
/// `` - **[foo.dart](lib/src/foo.dart)**: does F.``. Mid-prose mentions
/// (`...see lib/src/foo.dart for...`) deliberately don't count.
bool _hasEntry(String path, List<String> lines) {
  final entryLine = RegExp(r'^\s*(?:#{1,3}\s+|[-*]\s+)');
  return lines.any((line) => entryLine.hasMatch(line) && line.contains(path));
}

/// Expands [glob] (a template `coverage:` pattern) under [sourceDir],
/// returning absolute forward-slashed file paths. Supports `*.ext` (top
/// level only) and `dir/**/*.ext` (recursive) — the only shapes the template
/// uses.
List<String> _expandGlob(String glob, String sourceDir) {
  final files = <String>[];
  final dotExt = '.${glob.split('.').last}';
  if (!glob.contains('/')) {
    final dir = Directory(sourceDir);
    if (!dir.existsSync()) return files;
    for (final entry in dir.listSync().whereType<File>()) {
      if (entry.path.endsWith(dotExt)) files.add(_forward(entry.path));
    }
    return files;
  }
  final prefix = glob.substring(0, glob.indexOf('/'));
  final dir = Directory('$sourceDir/$prefix');
  if (!dir.existsSync()) return files;
  for (final entry in dir.listSync(recursive: true).whereType<File>()) {
    if (entry.path.endsWith(dotExt)) files.add(_forward(entry.path));
  }
  return files;
}

/// Normalizes Windows path separators so relative-path string math below
/// never mixes `\` and `/`.
String _forward(String path) => path.replaceAll(r'\', '/');

/// Every CLAUDE.md git knows about under [root] — tracked plus untracked but
/// not ignored (the same selection `sync_package_examples.dart` uses) — so
/// the generated `zenpay_*/example/` copies (gitignored) are never checked.
List<String> _trackedClaudeMds(String root) {
  final result = Process.runSync('git', ['-C', root, 'ls-files', '--cached', '--others', '--exclude-standard', '--', '*CLAUDE.md']);
  if (result.exitCode != 0) {
    stderr.writeln('git ls-files failed: ${result.stderr}');
    exit(1);
  }
  return const LineSplitter().convert(result.stdout as String).where((line) => line.isNotEmpty).toList();
}

String _usage() => [
  'Checks every git-tracked CLAUDE.md (or one given path) against',
  'scripts/claude_md_template.md — required sections and per-file coverage.',
  '',
  'Usage: dart run scripts/check_claude_md.dart [path/to/CLAUDE.md]',
  'Exit codes: 0 = conforms, 1 = violations, 64 = usage error.',
].join('\n');

void main(List<String> arguments) {
  if (arguments.any((arg) => arg == '-h' || arg == '--help')) {
    stdout.writeln(_usage());
    return;
  }
  if (arguments.length > 1) {
    stderr
      ..writeln('Expected at most one CLAUDE.md path.')
      ..writeln()
      ..writeln(_usage());
    exit(64);
  }

  // The template lives next to this script — the two must never drift apart,
  // so it is resolved by the script's own location, not the working
  // directory. The repo root is this file's parent directory (`scripts/`
  // sits directly under it, per the repo layout).
  final scriptDir = File.fromUri(Platform.script).parent.path;
  final root = _forward(Directory(scriptDir).parent.path);
  final template = parseTemplate(File('$scriptDir/claude_md_template.md').readAsStringSync());

  final docs = arguments.isEmpty ? _trackedClaudeMds(root) : arguments;

  stdout
    ..writeln('Template: scripts/claude_md_template.md')
    ..writeln();

  var checked = 0;
  var failed = 0;
  for (final doc in docs) {
    final absolute = _forward(File(arguments.isEmpty ? '$root/$doc' : doc).absolute.path);
    if (!File(absolute).existsSync()) {
      failed++;
      checked++;
      stdout
        ..writeln('FAIL  $doc')
        ..writeln('        file not found: $absolute');
      continue;
    }
    final violations = checkClaudeMd(docText: File(absolute).readAsStringSync(), sourceDir: _forward(File(absolute).parent.path), template: template);
    checked++;
    if (violations.isEmpty) {
      stdout.writeln('PASS  $doc');
    } else {
      failed++;
      stdout.writeln('FAIL  $doc');
      for (final violation in violations) {
        stdout.writeln('        $violation');
      }
    }
  }

  stdout
    ..writeln()
    ..writeln('$checked checked, $failed with violations');
  if (failed > 0) exit(1);
}
