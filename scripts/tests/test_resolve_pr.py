import importlib.util
from pathlib import Path
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'resolve_pr.py'


class ResolvePRTests(unittest.TestCase):
    def load(self):
        spec = importlib.util.spec_from_file_location('resolve_pr', SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_open_local_pr_records_all_revisions(self):
        data = {'state': 'open', 'merge_commit_sha': 'a'*40,
                'head': {'sha': 'b'*40, 'repo': {'full_name': 'owner/project'}},
                'base': {'sha': 'c'*40, 'repo': {'full_name': 'owner/project'}}}
        result = self.load().revisions(data, 'owner/project')
        self.assertEqual(result, {'merge': 'a'*40, 'head': 'b'*40, 'base': 'c'*40})

    def test_closed_foreign_and_missing_merge_are_rejected(self):
        module = self.load()
        data = {'state': 'closed'}
        with self.assertRaises(ValueError):
            module.revisions(data, 'owner/project')
        data = {'state': 'open', 'merge_commit_sha': None,
                'head': {'sha': 'b'*40, 'repo': {'full_name': 'foreign/project'}},
                'base': {'sha': 'c'*40, 'repo': {'full_name': 'owner/project'}}}
        with self.assertRaises(ValueError):
            module.revisions(data, 'owner/project')


if __name__ == '__main__':
    unittest.main()
