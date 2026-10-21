import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'tooling.py'


def load():
    spec = importlib.util.spec_from_file_location('tooling_policy', SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ToolingTests(unittest.TestCase):
    def test_missing_tool_has_setup_instruction(self):
        module = load()
        with tempfile.TemporaryDirectory() as folder:
            with patch.object(module, 'ROOT', Path(folder)), patch.object(module.shutil, 'which', return_value=None):
                with self.assertRaisesRegex(ValueError, 'setup-dev.sh --install-tools'):
                    module.executable('gitleaks')

    def test_bad_download_checksum_prevents_extraction(self):
        module = load()
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root / 'archive'
            source.write_bytes(b'not a trusted archive')
            config = {'tools': {'example': {'version': '1.2.3', 'url': source.as_uri(), 'sha256': '0'*64, 'archive': 'tar'}}}
            with patch.object(module, 'ROOT', root), patch.object(module, 'MANIFEST', config), patch.object(module, 'version', side_effect=ValueError('missing')), patch.object(module.platform, 'system', return_value='Darwin'), patch.object(module.platform, 'machine', return_value='arm64'):
                with self.assertRaisesRegex(ValueError, 'checksum mismatch'):
                    module.install()
            self.assertFalse((root / '.tools').exists())

    def test_existing_hook_configuration_is_preserved(self):
        import subprocess
        module = load()
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            subprocess.run(['git', '-C', str(root), 'config', 'core.hooksPath', 'custom-hooks'], check=True)
            with patch.object(module, 'ROOT', root):
                with self.assertRaisesRegex(ValueError, 'preserved'):
                    module.install_hook()
            value = subprocess.check_output(['git', '-C', str(root), 'config', 'core.hooksPath'], text=True)
            self.assertEqual(value.strip(), 'custom-hooks')


if __name__ == '__main__':
    unittest.main()
