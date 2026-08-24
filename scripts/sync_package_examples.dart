// Copies example/backend and example/app into each published package's own
// example/ directory, so `dart pub publish` can bundle a real, working
// example without duplicating source by hand.
//
// Run before publishing either package:
//
//   dart run scripts/sync_package_examples.dart
//
// example/backend and example/app stay the single source of truth. Every
// destination below is pure generated output — gitignored (see .gitignore),
// safe to delete, and fully replaced on every run. Never hand-edit anything
// under zenpay_dart/example/ or zenpay_flutter/example/; edit
// example/backend or example/app instead and re-run this script.
//
// Each copy only includes what `git` would track under the source directory
// (via `git ls-files --others --exclude-standard --cached`), so it
// automatically honours that directory's own .gitignore — .env, build/,
// .dart_tool/, and friends never ship inside a published package.
import 'dart:io';

import 'package:args/args.dart';

/// Skipped by basename regardless of directory: internal agent-guideline
/// docs, not part of the published API surface — matching the existing
/// `zenpay_dart/.pubignore` convention. `AGENTS.md` is also always a
/// symlink to a sibling `CLAUDE.md` (an absolute, MSYS-style path on this
/// machine), which `File.copySync` cannot resolve as a native Windows path
/// — excluding it here sidesteps that rather than trying to dereference it.
const _excludedBasenames = {'CLAUDE.md', 'AGENTS.md'};

/// One copy this script performs: `source` and `destination` are both
/// relative to the repo root. `localOverrides` maps a package name to its
/// path *relative to `destination`* — written to a generated
/// `pubspec_overrides.yaml` so the copy resolves against the in-repo package
/// instead of requiring it to already be published on pub.dev.
typedef _SyncTarget = ({String source, String destination, Map<String, String> localOverrides});

const _targets = <_SyncTarget>[
  (source: 'example/backend', destination: 'zenpay_dart/example', localOverrides: {'zenpay_dart': '..'}),
  (source: 'example/backend', destination: 'zenpay_flutter/example/backend', localOverrides: {'zenpay_dart': '../../../zenpay_dart'}),
  (
    source: 'example/app',
    destination: 'zenpay_flutter/example/app',
    localOverrides: {'zenpay_flutter': '../..', 'zenpay_embedded': '../../../zenpay_embedded'},
  ),
];

/// Builds the `--root` parser. A top-level function so tests can exercise
/// parsing without invoking [main] (which calls [exit]).
ArgParser buildParser() => ArgParser()
  ..addOption('root', help: 'Repo root. Defaults to the current directory.')
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this usage.');

void main(List<String> arguments) {
  final parser = buildParser();
  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr
      ..writeln(error.message)
      ..writeln(parser.usage);
    exit(64);
  }

  if (results['help'] as bool) {
    stdout.writeln(parser.usage);
    return;
  }

  final root = results['root'] as String? ?? Directory.current.path;
  for (final target in _targets) {
    syncExample(root, target.source, target.destination, localOverrides: target.localOverrides);
    stdout.writeln('Synced ${target.source} -> ${target.destination}');
  }
}

/// Copies every file `git` tracks (or would track — respecting that
/// directory's own `.gitignore`) under `$root/$source` into
/// `$root/$destination`, replacing whatever was there. Public so tests can
/// call it directly against a temp directory.
void syncExample(
  String root,
  String source,
  String destination, {
  Map<String, String> localOverrides = const {},
}) {
  final sourceDir = Directory('$root/$source');
  if (!sourceDir.existsSync()) {
    stderr.writeln('Source not found: ${sourceDir.path}');
    exit(1);
  }

  final destPath = '$root/$destination';
  // A prior run (or a hand-made symlink) could have left the destination as
  // a link rather than a real directory — remove just the link, not
  // whatever it points at, before recreating it as a real directory below.
  if (FileSystemEntity.typeSync(destPath, followLinks: false) == FileSystemEntityType.link) {
    Link(destPath).deleteSync();
  } else if (Directory(destPath).existsSync()) {
    Directory(destPath).deleteSync(recursive: true);
  }

  final result = Process.runSync('git', [
    'ls-files',
    '--others',
    '--exclude-standard',
    '--cached',
    '--',
    source,
  ], workingDirectory: root);
  if (result.exitCode != 0) {
    stderr.writeln('git ls-files failed for $source: ${result.stderr}');
    exit(1);
  }

  final relativePaths = (result.stdout as String).split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty);

  for (final relativePath in relativePaths) {
    if (_excludedBasenames.contains(relativePath.split('/').last)) {
      continue;
    }
    final sourceFile = File('$root/$relativePath');
    if (!sourceFile.existsSync()) {
      continue; // staged-for-deletion or otherwise gone from disk.
    }
    final targetFile = File('$destPath${relativePath.substring(source.length)}');
    targetFile.parent.createSync(recursive: true);
    sourceFile.copySync(targetFile.path);
  }

  _stripWorkspaceResolution(destPath);
  _writeDependencyOverrides(destPath, localOverrides);
  _fixAnalysisOptionsInclude(destPath);
}

/// Removes the copied `pubspec.yaml`'s `resolution: workspace` declaration.
///
/// `example/backend` and `example/app` are real members of this repo's pub
/// workspace, so their `pubspec.yaml` declares `resolution: workspace` —
/// copied verbatim, that breaks `dart pub get` for the *entire* monorepo,
/// since the destination (e.g. `zenpay_dart/example`) isn't itself a
/// declared workspace member. Every dependency already uses a normal,
/// publishable version constraint (see `example/app/pubspec.yaml`'s own
/// comment on this), so the workspace-resolution line is the only thing
/// that doesn't survive the copy as a standalone package.
void _stripWorkspaceResolution(String destPath) {
  final pubspecFile = File('$destPath/pubspec.yaml');
  if (!pubspecFile.existsSync()) return;
  final content = pubspecFile.readAsStringSync();
  // These files are authored with CRLF line endings — match whichever this
  // one actually uses rather than assuming.
  final eol = content.contains('\r\n') ? '\r\n' : '\n';
  final patched = content.replaceFirst('${eol}resolution: workspace$eol$eol', eol);
  pubspecFile.writeAsStringSync(patched);
}

/// Writes `pubspec_overrides.yaml` at [destPath] pointing [localOverrides]
/// (package name -> path relative to [destPath]) at the in-repo package,
/// via `dependency_overrides`.
///
/// Without this, `dart pub get` on the standalone copy fails outright: its
/// `pubspec.yaml` still names the real published version constraint (e.g.
/// `zenpay_dart: ^0.1.0`), which does not resolve before that package's
/// first real pub.dev publish. `pubspec_overrides.yaml` is pub's own
/// mechanism for exactly this — local-only, and (like `.git/`) always
/// excluded from a published package archive — so the committed constraint
/// in `pubspec.yaml` is untouched for when this copy *is* extracted
/// standalone from a real pub.dev download. No-ops if [localOverrides] is
/// empty (nothing to override) or there is no `pubspec.yaml` to override.
void _writeDependencyOverrides(String destPath, Map<String, String> localOverrides) {
  if (localOverrides.isEmpty || !File('$destPath/pubspec.yaml').existsSync()) return;

  final buffer = StringBuffer(
    '# Generated by scripts/sync_package_examples.dart — local-dev only.\n'
    '# Resolves this example against the in-repo package instead of\n'
    '# requiring it to already be published on pub.dev. Never shipped in a\n'
    '# published archive; safe to delete.\n'
    'dependency_overrides:\n',
  );
  for (final entry in localOverrides.entries) {
    buffer.write('  ${entry.key}:\n    path: ${entry.value}\n');
  }
  File('$destPath/pubspec_overrides.yaml').writeAsStringSync(buffer.toString());
}

/// Repoints the copied `analysis_options.yaml`'s `include:` away from
/// `../../analysis_options.yaml` (the monorepo root's file, only reachable
/// because `example/backend`/`example/app` share the workspace's single
/// resolved package graph — see [_stripWorkspaceResolution]). Once copied
/// out as a standalone package, that include can't resolve
/// `package:very_good_analysis/...` at all: the standalone copy was never
/// given that dependency. Repoints it at `package:lints/recommended.yaml`
/// instead, which every copied package's own `pubspec.yaml` genuinely
/// depends on (`lints: ^6.1.0`), so it resolves standalone. The
/// `analyzer: exclude:` block above it is untouched.
void _fixAnalysisOptionsInclude(String destPath) {
  final file = File('$destPath/analysis_options.yaml');
  if (!file.existsSync()) return;
  final content = file.readAsStringSync();
  final patched = content.replaceFirst(
    RegExp(r'^include:\s*\.\./\.\./analysis_options\.yaml\s*$', multiLine: true),
    'include: package:lints/recommended.yaml',
  );
  if (patched != content) {
    file.writeAsStringSync(patched);
  }
}
