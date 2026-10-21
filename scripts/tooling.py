"""Pinned macOS tool setup and version checks; downloads are explicit."""

import argparse
import hashlib
import json
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = json.loads((ROOT / 'tooling.json').read_text())


def executable(name):
    local = ROOT / '.tools' / name / name
    candidate = str(local) if local.is_file() else shutil.which(name)
    if not candidate:
        raise ValueError(f'{name} is missing; run ./scripts/setup-dev.sh --install-tools')
    return candidate


def version(name):
    args = ['version'] if name in {'swiftlint', 'gitleaks'} else ['--version']
    result = subprocess.run([executable(name), *args], capture_output=True, text=True, check=True)
    match = re.search(r'\b\d+\.\d+\.\d+\b', result.stdout + result.stderr)
    if not match:
        raise ValueError(f'cannot read {name} version')
    return match[0]


def verify():
    if sys.version_info[:2] < tuple(MANIFEST['pythonMinimum']):
        raise ValueError('Python 3.11 or newer is required')
    if platform.system() != 'Darwin' or platform.machine() != 'arm64':
        raise ValueError('This foundation supports Apple Silicon macOS only')
    xcode = subprocess.check_output(['xcodebuild', '-version'], text=True).splitlines()[0]
    swift = subprocess.check_output(['swift', 'format', '--version'], text=True).strip()
    if xcode != 'Xcode ' + MANIFEST['xcode'] or swift != MANIFEST['swift']:
        raise ValueError(f'expected Xcode {MANIFEST["xcode"]} / Swift {MANIFEST["swift"]}; found {xcode} / {swift}')
    for name, config in MANIFEST['tools'].items():
        actual = version(name)
        if actual != config['version']:
            raise ValueError(f'{name}: expected {config["version"]}, found {actual}')
    print('Pinned tool versions verified.')


def install():
    if platform.system() != 'Darwin' or platform.machine() != 'arm64':
        raise ValueError('Pinned downloads support Apple Silicon macOS only')
    for name, config in MANIFEST['tools'].items():
        try:
            if version(name) == config['version']:
                continue
        except (ValueError, subprocess.CalledProcessError):
            pass
        print(f'Installing {name} {config["version"]} into .tools/', flush=True)
        with tempfile.TemporaryDirectory(prefix='stt-tool-') as folder:
            archive = Path(folder) / 'download'
            urllib.request.urlretrieve(config['url'], archive)
            if hashlib.sha256(archive.read_bytes()).hexdigest() != config['sha256']:
                raise ValueError(f'{name}: archive checksum mismatch')
            destination = ROOT / '.tools' / name
            destination.mkdir(parents=True, exist_ok=True)
            if config['archive'] == 'zip':
                with zipfile.ZipFile(archive) as bundle:
                    for member in bundle.infolist():
                        target = (destination / member.filename).resolve()
                        if not target.is_relative_to(destination.resolve()):
                            raise ValueError('archive path escapes tool directory')
                    bundle.extractall(destination)
            else:
                with tarfile.open(archive) as bundle:
                    members = [m for m in bundle.getmembers() if Path(m.name).name == name and m.isfile()]
                    if len(members) != 1:
                        raise ValueError(f'{name}: archive executable missing or ambiguous')
                    with bundle.extractfile(members[0]) as source:
                        (destination / name).write_bytes(source.read())
            binary = destination / name
            binary.chmod(binary.stat().st_mode | 0o111)
        if version(name) != config['version']:
            raise ValueError(f'{name}: installed version mismatch')
    verify()


def install_hook():
    result = subprocess.run(['git', 'config', '--get', 'core.hooksPath'], cwd=ROOT, capture_output=True, text=True)
    current = result.stdout.strip()
    if current and current != '.githooks':
        raise ValueError(f'existing hooksPath is preserved: {current}; invoke ./scripts/check.sh --quick directly')
    gitdir = Path(subprocess.check_output(['git', 'rev-parse', '--git-path', 'hooks'], cwd=ROOT, text=True).strip())
    if not current and gitdir.exists() and any(p.is_file() and not p.name.endswith('.sample') for p in gitdir.iterdir()):
        raise ValueError('existing local hooks are preserved; invoke checks directly')
    subprocess.run(['git', 'config', '--local', 'core.hooksPath', '.githooks'], cwd=ROOT, check=True)
    print('Local hook enabled: .githooks/pre-commit')


def swift_files():
    files = []
    for directory in ('Sources', 'Tests'):
        files.extend(sorted((ROOT / directory).rglob('*.swift')))
    if (ROOT / 'Package.swift').is_file():
        files.append(ROOT / 'Package.swift')
    return [str(p) for p in files]


def swift_checks(write=False):
    files = swift_files()
    if not files:
        print('Swift source formatting/lint: no application source yet; rule policy tests run separately.')
        return
    command = ['swift', 'format', 'format', '--in-place'] if write else ['swift', 'format', 'lint', '--strict']
    subprocess.run([*command, '--configuration', str(ROOT / '.swift-format'), *files], check=True)
    if not write:
        subprocess.run([executable('swiftlint'), 'lint', '--strict', '--quiet', '--no-cache', '--config', str(ROOT / '.swiftlint.yml'), *files], check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['verify', 'install', 'hooks', 'swift-check', 'format', 'path'])
    parser.add_argument('name', nargs='?')
    args = parser.parse_args()
    if args.operation == 'path':
        print(executable(args.name))
    elif args.operation == 'swift-check':
        swift_checks()
    elif args.operation == 'format':
        swift_checks(write=True)
    elif args.operation == 'hooks':
        install_hook()
    elif args.operation == 'install':
        install()
    else:
        verify()


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'Tool setup failed: {error}', file=sys.stderr)
        sys.exit(1)
