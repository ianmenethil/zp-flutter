// Fixture-based tests for check_claude_md.dart, in the same temp-directory
// style as apply_platform_config_test.dart: each case builds a throwaway
// document and, where coverage is involved, the matching source tree on
// disk, then asserts the exact violations reported.
import 'dart:io';

import 'package:test/test.dart';

import 'check_claude_md.dart';

const _sections = ['Related Guides', 'Verification'];

void main() {
  group('parseTemplate', () {
    test('extracts required sections and coverage globs, ignores prose', () {
      final template = parseTemplate('''
# Header (ignored)

## Related Guides

## Verification

coverage: lib/**/*.dart
coverage: *.dart

### Matching rules (ignored)
''');
      expect(template.requiredSections, ['Related Guides', 'Verification']);
      expect(template.coverageGlobs, ['lib/**/*.dart', '*.dart']);
    });
  });

  group('checkClaudeMd — sections', () {
    test('passes a conforming document', () {
      final violations = checkClaudeMd(
        docText: '''
# package — description

## Related Guides

- **[Monorepo Root](../CLAUDE.md)** — overview.

## 3. Verification Commands

```pwsh
melos run test
```
''',
        sourceDir: Directory.systemTemp.createTempSync().path,
        template: const ClmTemplate(requiredSections: _sections, coverageGlobs: []),
      );
      expect(violations, isEmpty);
    });

    test('reports a missing title and a missing section', () {
      final violations = checkClaudeMd(
        docText: '## Verification\n\nsome text\n',
        sourceDir: Directory.systemTemp.createTempSync().path,
        template: const ClmTemplate(requiredSections: _sections, coverageGlobs: []),
      );
      expect(
        violations,
        containsAll([
          'missing top-level `# ` title',
          'missing section: ## Related Guides',
        ]),
      );
    });

    test('accepts CRLF and CR line endings', () {
      final violations = checkClaudeMd(
        docText: '# package — description\r\n\r\n## Related Guides\r\n\r\n- link\r\n\r\n## Verification\r\n',
        sourceDir: Directory.systemTemp.createTempSync().path,
        template: const ClmTemplate(requiredSections: _sections, coverageGlobs: []),
      );
      expect(violations, isEmpty);
    });

    test('reports sections out of order', () {
      final violations = checkClaudeMd(
        docText: '# t\n\n## Verification\n\n## Related Guides\n',
        sourceDir: Directory.systemTemp.createTempSync().path,
        template: const ClmTemplate(requiredSections: _sections, coverageGlobs: []),
      );
      expect(
        violations,
        contains(
          'sections out of order: ## Verification appears before ## Related Guides',
        ),
      );
    });
  });

  group('checkClaudeMd — coverage', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync());
    tearDown(() => dir.deleteSync(recursive: true));

    test('passes when every file has a dedicated entry', () {
      Directory('${dir.path}/lib/src').createSync(recursive: true);
      File('${dir.path}/lib/src/foo.dart').createSync();
      File('${dir.path}/lib/bar.dart').createSync();
      File('${dir.path}/top.dart').createSync();

      final violations = checkClaudeMd(
        docText: '''
# package — description

## Related Guides

- **[Monorepo Root](../CLAUDE.md)** — overview.

## Verification

### `lib/src/foo.dart`

- **`lib/bar.dart`** — does B.

- **[top.dart](top.dart)** — the entrypoint.
''',
        sourceDir: dir.path,
        template: const ClmTemplate(
          requiredSections: [],
          coverageGlobs: ['lib/**/*.dart', '*.dart'],
        ),
      );
      expect(violations, isEmpty);
    });

    test('accepts the link style with the path inside a markdown link', () {
      Directory('${dir.path}/lib/src').createSync(recursive: true);
      File('${dir.path}/lib/src/foo.dart').createSync();

      final violations = checkClaudeMd(
        docText: '# package\n\n- **[foo.dart](lib/src/foo.dart)**: Implements F.\n',
        sourceDir: dir.path,
        template: const ClmTemplate(
          requiredSections: [],
          coverageGlobs: ['lib/**/*.dart'],
        ),
      );
      expect(violations, isEmpty);
    });

    test('reports a file mentioned only in prose, not as an entry', () {
      Directory('${dir.path}/lib/src').createSync(recursive: true);
      File('${dir.path}/lib/src/foo.dart').createSync();

      final violations = checkClaudeMd(
        docText: 'See lib/src/foo.dart for the details.\n',
        sourceDir: dir.path,
        template: const ClmTemplate(
          requiredSections: [],
          coverageGlobs: ['lib/**/*.dart'],
        ),
      );
      expect(violations, contains('missing file entry: lib/src/foo.dart'));
    });

    test('the top-level glob does not reach into subdirectories', () {
      Directory('${dir.path}/lib').createSync();
      File('${dir.path}/lib/nested.dart').createSync();
      File('${dir.path}/top.dart').createSync();

      final violations = checkClaudeMd(
        docText: '# package\n\n- `top.dart` — the entrypoint.\n',
        sourceDir: dir.path,
        template: const ClmTemplate(
          requiredSections: [],
          coverageGlobs: ['*.dart'],
        ),
      );
      expect(violations, isEmpty);
    });
  });
}
