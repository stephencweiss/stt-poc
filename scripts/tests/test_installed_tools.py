"""Exercise the installed config, not a second implementation of lint rules."""

import importlib.util
from pathlib import Path
import random
import string
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('tooling', ROOT / 'scripts/tooling.py')
tooling = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tooling)


class InstalledToolTests(unittest.TestCase):
    def lint(self, text):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / 'Example.swift'
            source.write_text(text)
            return subprocess.run([tooling.executable('swiftlint'), 'lint', '--strict', '--quiet', '--no-cache', '--config', str(ROOT / '.swiftlint.yml'), str(source)], capture_output=True, text=True)

    def test_safe_optional_passes(self):
        self.assertEqual(self.lint('func value(_ input: Int?) -> Int { input ?? 0 }\n').returncode, 0)

    def test_forced_operations_fail(self):
        samples = [
            'func value(_ input: Int?) -> Int { input! }',
            'func value(_ input: Any) -> Int { input as! Int }',
            'func value() throws -> Int { 1 }; let result = try! value()',
            'var value: String!',
        ]
        for text in samples:
            with self.subTest(text=text):
                self.assertNotEqual(self.lint(text + '\n').returncode, 0)

    def test_legacy_logging_apis_fail(self):
        samples = [
            'let log = OSLog(subsystem: "Example", category: "Test")',
            'let log = OSLog.default',
            'typealias LegacyLog = OSLog',
            'NSLog("Failure")',
            'NSLogv("Failure", arguments)',
            'os_log("Failure")',
            'os_log_error(log, "Failure")',
            'let write = os_log',
        ]
        for text in samples:
            with self.subTest(text=text):
                result = self.lint(text + '\n')
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('logger_only', result.stdout + result.stderr)

    def test_logger_and_legacy_names_in_comments_and_strings_pass(self):
        text = '''import os
let logger = Logger(subsystem: "Example", category: "Test")
logger.error("Failure")
// OSLog, NSLog, and os_log are not used here.
let description = "OSLog NSLog os_log"
'''
        self.assertEqual(self.lint(text).returncode, 0)

    def test_oslog_module_import_for_logger_passes(self):
        text = '''import OSLog
let logger = OSLog.Logger(subsystem: "Example", category: "Test")
'''
        self.assertEqual(self.lint(text).returncode, 0)

    def test_complex_function_fails(self):
        text = 'func value(_ x: Int) {\n' + '\n'.join(f'if x == {n} {{ print(x) }}' for n in range(12)) + '\n}\n'
        self.assertNotEqual(self.lint(text).returncode, 0)

    def test_format_check_rejects_without_modifying(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / 'Example.swift'
            original = 'struct Example{let value:Int}\n'
            source.write_text(original)
            result = subprocess.run(['swift', 'format', 'lint', '--strict', '--configuration', str(ROOT / '.swift-format'), str(source)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(source.read_text(), original)

    def test_secret_scan_reads_staged_blob_and_redacts(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            token = 'ghp_' + ''.join(random.Random(42).choices(string.ascii_letters + string.digits, k=36))
            source = root / 'example.txt'
            source.write_text('token=' + token + '\n')
            subprocess.run(['git', '-C', str(root), 'add', 'example.txt'], check=True)
            source.write_text('clean working copy\n')
            result = subprocess.run([sys.executable, str(ROOT / 'scripts/repository.py'), '--root', str(root), 'secrets', '--staged', '--scanner', tooling.executable('gitleaks')], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn(token, result.stdout + result.stderr)
            subprocess.run(['git', '-C', str(root), 'add', 'example.txt'], check=True)
            clean = subprocess.run([sys.executable, str(ROOT / 'scripts/repository.py'), '--root', str(root), 'secrets', '--staged', '--scanner', tooling.executable('gitleaks')], capture_output=True)
            self.assertEqual(clean.returncode, 0)


if __name__ == '__main__':
    unittest.main()
