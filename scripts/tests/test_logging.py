from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'logging_policy.py'


class LoggingPolicyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.git('init', '-q')
        self.write('Sources/Audio.swift', 'let logger = Logger(subsystem: "STTPOC", category: "Audio")\nlogger.error(\n    "Old failure"\n)\n')
        self.write('docs/log-catalog.md', '# Logs\n\nOld failure.\n')
        self.git('add', '.')
        self.git('-c', 'user.name=Policy Test', '-c', 'user.email=policy@example.invalid',
                 'commit', '-qm', 'baseline')

    def tearDown(self):
        self.temp.cleanup()

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.root), *args])

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def check(self, staged=True):
        args = ['--staged'] if staged else []
        return subprocess.run(['python3', str(SCRIPT), '--root', str(self.root), *args],
                              capture_output=True, text=True)

    def test_logging_add_change_remove_and_rename_need_catalog(self):
        for operation in ('add', 'change', 'remove', 'rename'):
            with self.subTest(operation=operation):
                self.git('reset', '--hard', '-q', 'HEAD')
                if operation == 'add':
                    self.write('Sources/New.swift', 'let diagnostic = Logger(subsystem: "STTPOC", category: "New")\n')
                    self.git('add', 'Sources/New.swift')
                elif operation == 'change':
                    path = self.root / 'Sources/Audio.swift'
                    path.write_text(path.read_text().replace('Old failure', 'New failure'))
                    self.git('add', 'Sources/Audio.swift')
                elif operation == 'remove':
                    self.git('rm', '-q', 'Sources/Audio.swift')
                else:
                    self.git('mv', 'Sources/Audio.swift', 'Sources/Renamed.swift')
                result = self.check()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('docs/log-catalog.md', result.stderr)
                self.write('docs/log-catalog.md', '# Logs\n\nUpdated definitions.\n')
                self.git('add', 'docs/log-catalog.md')
                self.assertEqual(self.check().returncode, 0)

    def test_unstaged_catalog_cannot_hide_missing_staged_update(self):
        self.write('Sources/Audio.swift', 'logger.error("Changed")\n')
        self.git('add', 'Sources/Audio.swift')
        self.write('docs/log-catalog.md', '# Logs\n\nChanged.\n')
        self.assertNotEqual(self.check().returncode, 0)
        self.assertEqual(self.check(staged=False).returncode, 0)
        self.git('add', 'docs/log-catalog.md')
        self.write('docs/log-catalog.md', '# Logs\n\nOld failure.\n')
        self.assertEqual(self.check().returncode, 0)
        self.assertNotEqual(self.check(staged=False).returncode, 0)

    def test_deleted_empty_or_whitespace_only_catalog_change_fails(self):
        self.write('Sources/Audio.swift', 'logger.fault("Changed")\n')
        self.git('add', 'Sources/Audio.swift')
        for content in (None, ' \n', '# Logs\n\nOld failure.\n\n'):
            with self.subTest(content=content):
                if content is None:
                    (self.root / 'docs/log-catalog.md').unlink()
                else:
                    self.write('docs/log-catalog.md', content)
                self.git('add', '-A', 'docs/log-catalog.md')
                self.assertNotEqual(self.check().returncode, 0)

    def test_unrelated_swift_change_does_not_need_catalog(self):
        self.write('Sources/State.swift', 'enum State { case idle }\n')
        self.git('add', 'Sources/State.swift')
        self.assertEqual(self.check().returncode, 0)

    def test_new_untracked_logging_file_is_checked_in_full_mode(self):
        self.write('Sources/New.swift', 'os_log("Failure")\n')
        self.assertNotEqual(self.check(staged=False).returncode, 0)
        self.assertEqual(self.check().returncode, 0)

    def test_first_commit_full_check_includes_indexed_source(self):
        self.git('update-ref', '-d', 'HEAD')
        (self.root / 'docs/log-catalog.md').unlink()
        result = self.check(staged=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('docs/log-catalog.md', result.stderr)

    def test_first_commit_supports_staged_catalog(self):
        self.git('update-ref', '-d', 'HEAD')
        self.assertEqual(self.check().returncode, 0)
        self.git('rm', '--cached', '-q', 'docs/log-catalog.md')
        self.assertNotEqual(self.check().returncode, 0)


if __name__ == '__main__':
    unittest.main()
