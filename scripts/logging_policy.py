"""Require a catalog update with textual logging changes; do not judge catalog meaning."""

import argparse
from pathlib import Path
import re
import subprocess
import sys

CATALOG = 'docs/log-catalog.md'
LOG_EXPRESSION = re.compile(
    r'\bLogger\s*\('
    r'|\.\s*(?:trace|debug|info|notice|warning|error|fault|critical|log)\s*\('
)


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args])


def read_revision(root, revision, name):
    result = subprocess.run(['git', '-C', str(root), 'show', f'{revision}:{name}'],
                            capture_output=True)
    return result.stdout.decode() if result.returncode == 0 else ''


def logging_diff(patch):
    # Five context lines cover the current multiline calls. This is not a Swift parser.
    for section in patch.split('diff --git ')[1:]:
        header, _, body = section.partition('\n')
        if not header.endswith('.swift'):
            continue
        for hunk in body.split('@@ ')[1:]:
            if LOG_EXPRESSION.search(hunk):
                return True
    return False


def check(root, staged):
    head = subprocess.run(['git', '-C', str(root), 'rev-parse', '--verify', 'HEAD'],
                          capture_output=True).returncode == 0
    args = ['diff', '--no-ext-diff', '--no-color', '--no-renames', '--unified=5']
    if staged:
        args.append('--cached')
    elif head:
        args.append('HEAD')
    changed = logging_diff(git(root, *args, '--', 'Sources').decode())
    if not staged:
        extra = ['--others'] if head else ['--cached', '--others']
        names = git(root, 'ls-files', *extra, '--exclude-standard', '-z', '--', 'Sources')
        files = [root / name.decode() for name in names.split(b'\0')
                 if name and name.endswith(b'.swift')]
        changed = changed or any(LOG_EXPRESSION.search(path.read_text())
                                 for path in files if path.is_file())
    if not changed:
        return
    previous = read_revision(root, 'HEAD', CATALOG) if head else ''
    current = read_revision(root, '', CATALOG) if staged else (
        (root / CATALOG).read_text() if (root / CATALOG).is_file() else '')
    if not current.strip() or current.split() == previous.split():
        mode = 'staged' if staged else 'working-copy'
        raise ValueError(f'Logging changed: include a nonempty {mode} update to {CATALOG}. '
                         'Review must check its meaning and completeness.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--staged', action='store_true')
    args = parser.parse_args()
    check(args.root.resolve(), args.staged)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'Logging policy failed: {error}', file=sys.stderr)
        sys.exit(1)
