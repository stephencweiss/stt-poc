import json
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'repository.py'


class RepositoryPolicyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)

    def tearDown(self):
        self.temp.cleanup()

    def run_check(self, *args):
        return subprocess.run(['python3', str(SCRIPT), '--root', str(self.root), *args], capture_output=True, text=True)

    def write(self, path, content):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
        return target

    def test_private_audio_rejected_but_reviewed_fixture_allowed(self):
        self.write('practice.wav', 'private')
        result = self.run_check('paths')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('protected path', result.stderr)
        (self.root / 'practice.wav').unlink()
        self.write('Fixtures/Benchmark/audio/test.wav', 'fictional')
        self.assertEqual(self.run_check('paths').returncode, 0)

    def test_staged_blob_is_checked_instead_of_clean_working_copy(self):
        self.write('.env', 'PRIVATE=example')
        subprocess.run(['git', '-C', str(self.root), 'add', '.env'], check=True)
        (self.root / '.env').unlink()
        result = self.run_check('paths', '--staged')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('protected path', result.stderr)

    def test_document_links_and_indexes_are_checked(self):
        self.write('README.md', '# Guide\n## Conventions\n- [Rules](docs/conventions/rules.md)\n')
        self.write('AGENTS.md', '# Agent\n## Conventions\n- [Rules](docs/conventions/rules.md)\n')
        self.write('docs/conventions/rules.md', '# Rules\n')
        self.assertEqual(self.run_check('documents').returncode, 0)
        self.write('AGENTS.md', '# Agent\n## Conventions\n')
        self.assertNotEqual(self.run_check('documents').returncode, 0)
        self.write('AGENTS.md', '# Agent\n## Conventions\n- [Rules](docs/conventions/rules.md)\n')
        self.write('docs/conventions/rules.md', '[Missing](missing.md)\n')
        self.assertNotEqual(self.run_check('documents').returncode, 0)

    def write_fixture(self):
        import hashlib
        self.write('Fixtures/Benchmark/audio/test.wav', 'fictional')
        self.write('Fixtures/Benchmark/references/test.txt', 'test')
        case = {'id': 'test', 'audio': 'audio/test.wav', 'reference': 'references/test.txt',
                'audioSha256': hashlib.sha256(b'fictional').hexdigest(),
                'referenceSha256': hashlib.sha256(b'test').hexdigest(),
                'category': 'clear', 'origin': 'fictional policy fixture', 'expectedFacts': []}
        self.write('Fixtures/Benchmark/manifest.json', json.dumps({'version': 1, 'cases': [case]}))

    def test_fixture_checksum_and_missing_pair_fail(self):
        self.write_fixture()
        self.assertEqual(self.run_check('fixtures').returncode, 0)
        self.write('Fixtures/Benchmark/audio/test.wav', 'changed')
        self.assertNotEqual(self.run_check('fixtures').returncode, 0)
        (self.root / 'Fixtures/Benchmark/references/test.txt').unlink()
        self.assertNotEqual(self.run_check('fixtures').returncode, 0)

    def test_unlisted_fixture_audio_fails(self):
        self.write_fixture()
        self.write('Fixtures/Benchmark/audio/unlisted.wav', 'unreviewed')
        self.assertNotEqual(self.run_check('fixtures').returncode, 0)

    def test_staged_fixture_mismatch_cannot_hide_in_clean_working_copy(self):
        self.write_fixture()
        subprocess.run(['git', '-C', str(self.root), 'add', 'Fixtures'], check=True)
        self.assertEqual(self.run_check('fixtures', '--staged').returncode, 0)
        self.write('Fixtures/Benchmark/audio/test.wav', 'changed')
        subprocess.run(['git', '-C', str(self.root), 'add', 'Fixtures'], check=True)
        self.write('Fixtures/Benchmark/audio/test.wav', 'fictional')
        self.assertEqual(self.run_check('fixtures').returncode, 0)
        self.assertNotEqual(self.run_check('fixtures', '--staged').returncode, 0)

    def test_fixture_path_escape_rejected(self):
        self.write('Fixtures/Benchmark/manifest.json', json.dumps({'version': 1, 'cases': [
            {'id': 'bad', 'audio': '../../../outside.wav', 'reference': 'x', 'audioSha256': '0'*64,
             'referenceSha256': '0'*64, 'category': 'x', 'origin': 'x', 'expectedFacts': []}]}))
        result = self.run_check('fixtures')
        self.assertNotEqual(result.returncode, 0)

    def test_source_without_package_cannot_pass_as_foundation_only(self):
        self.write('Sources/Feature.swift', 'struct Feature {}')
        result = self.run_check('source-status')
        self.assertNotEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main()
