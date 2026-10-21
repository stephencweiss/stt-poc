"""Repository policies. No medical data is inspected for semantic privacy."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args])


def paths(root, staged=False):
    args = ('diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z') if staged else (
        'ls-files', '--cached', '--others', '--exclude-standard', '-z')
    return sorted(set(p.decode() for p in git(root, *args).split(b'\0') if p))


def protected(path):
    p = Path(path)
    fixture = p.parts[:3] == ('Fixtures', 'Benchmark', 'audio')
    return (
        any(part in {'.local', '.tools', '.aws', '.ssh'} for part in p.parts)
        or p.name.startswith('.env')
        or p.suffix.lower() in {'.pem', '.key', '.sqlite', '.sqlite3', '.db', '.bin', '.gguf', '.m4a', '.mp3', '.wav', '.flac'} and not (
            fixture and p.suffix.lower() in {'.m4a', '.mp3', '.wav', '.flac'})
        or '.mlmodelc' in path or path.endswith(('.db-wal', '.db-shm'))
    )


def check_paths(root, staged):
    for name in paths(root, staged):
        if protected(name):
            raise ValueError(f'protected path: {name}')
        mode = git(root, 'ls-files', '-s', '--', name).decode()
        if mode.startswith('120000') or (root / name).is_symlink():
            raise ValueError(f'symlink is not permitted: {name}')


def convention_index(text):
    match = re.search(r'^## Conventions\s*\n(.*?)(?=^## |\Z)', text, re.M | re.S)
    return re.findall(r'^- \[([^]]+)\]\((docs/conventions/[^)]+)\)', match[1] if match else '', re.M)


def check_documents(root):
    readme = root / 'README.md'
    agents = root / 'AGENTS.md'
    if not readme.exists() or not agents.exists():
        raise ValueError('README.md and AGENTS.md are required')
    index = convention_index(readme.read_text())
    if not index or index != convention_index(agents.read_text()):
        raise ValueError('convention indexes must match and must not be empty')
    expected = {str(p.relative_to(root)) for p in (root / 'docs/conventions').glob('*.md')}
    if {p for _, p in index} != expected:
        raise ValueError('convention index must list every convention exactly once')
    if len(index) != len(expected):
        raise ValueError('duplicate convention index entry')
    for name in paths(root):
        if not name.endswith('.md') or name == 'medical_stt_procedure_log_mvp_specification.md':
            continue  # Preserve the supplied source document verbatim.
        source = root / name
        if not source.is_file():
            continue
        text = re.sub(r'```.*?```', '', source.read_text(), flags=re.S)
        for link in re.findall(r'\]\(([^)]+)\)', text):
            if re.match(r'^[a-zA-Z][\w+.-]*:', link) or link.startswith('#'):
                continue
            target = unquote(link.split('#')[0].strip('<>'))
            if target and not (source.parent / target).exists():
                raise ValueError(f'{name}: missing local link {target}')


def checked_file(base, value):
    if not isinstance(value, str):
        raise ValueError('fixture path must be text')
    target = (base / value).resolve()
    if not target.is_relative_to(base.resolve()) or not target.is_file():
        raise ValueError('fixture file missing or outside fixture directory')
    return target


def check_fixtures(root):
    base = root / 'Fixtures/Benchmark'
    if not base.exists():
        if (root / 'Package.swift').exists():
            raise ValueError('Application package requires its benchmark fixture suite')
        print('Fixture suite not installed yet (application PR 1).')
        return
    data = json.loads((base / 'manifest.json').read_text())
    cases = data.get('cases')
    if data.get('version') != 1 or not isinstance(cases, list) or not cases:
        raise ValueError('fixture manifest requires version 1 and nonempty cases')
    ids = set()
    listed = set()
    for case in cases:
        if not isinstance(case, dict) or not isinstance(case.get('id'), str) or not case['id'] or case['id'] in ids:
            raise ValueError('fixture IDs must be unique nonempty strings')
        ids.add(case['id'])
        if not case.get('origin') or not case.get('category') or not isinstance(case.get('expectedFacts'), list):
            raise ValueError('fixture origin, category, and expectedFacts are required')
        for field in ('audio', 'reference'):
            file = checked_file(base, case.get(field))
            listed.add(file)
            actual = hashlib.sha256(file.read_bytes()).hexdigest()
            if actual != case.get(field + 'Sha256'):
                raise ValueError(f'fixture checksum mismatch: {case["id"]} {field}')

    actual = {p.resolve() for folder in ('audio', 'references') for p in (base / folder).rglob('*') if p.is_file()}
    if actual - listed:
        raise ValueError('fixture inventory contains files absent from the manifest')


def check_staged_fixtures(root):
    import tempfile
    with tempfile.TemporaryDirectory(prefix='stt-staged-fixtures-') as folder:
        snapshot = Path(folder)
        names = git(root, 'ls-files', '-z', '--', 'Fixtures/Benchmark', 'Package.swift')
        for raw in names.split(b'\0'):
            if not raw:
                continue
            name = raw.decode()
            target = snapshot / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(git(root, 'show', ':' + name))
        check_fixtures(snapshot)


def source_status(root):
    source = any((root / 'Sources').rglob('*.swift')) or any((root / 'Tests').rglob('*.swift'))
    if source and not (root / 'Package.swift').is_file():
        raise ValueError('Swift source requires Package.swift and mandatory build/test checks')
    if not (root / 'Package.swift').exists():
        print('Swift app build, XCTest, and packaging NOT INSTALLED (application PR 1).')


def scan_secrets(root, staged, executable):
    # Materialize index blobs so a clean worktree cannot conceal a staged secret.
    import tempfile
    with tempfile.TemporaryDirectory(prefix='stt-secret-check-') as folder:
        destination = Path(folder)
        for name in paths(root, staged):
            if name.startswith(('.build/', '.tools/')):
                continue
            source = root / name
            content = git(root, 'show', ':' + name) if staged else (source.read_bytes() if source.is_file() else b'')
            target = destination / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
        subprocess.run([executable, 'dir', str(destination), '--redact', '--no-banner', '--exit-code', '1'], check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('check', choices=['paths', 'documents', 'fixtures', 'source-status', 'secrets'])
    parser.add_argument('--staged', action='store_true')
    parser.add_argument('--scanner', default='gitleaks')
    args = parser.parse_args()
    root = args.root.resolve()
    if args.check == 'paths':
        check_paths(root, args.staged)
    elif args.check == 'documents':
        check_documents(root)
    elif args.check == 'fixtures':
        if args.staged:
            check_staged_fixtures(root)
        else:
            check_fixtures(root)
    elif args.check == 'source-status':
        source_status(root)
    else:
        scan_secrets(root, args.staged, args.scanner)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print(f'Repository check failed: {error}', file=sys.stderr)
        sys.exit(1)
