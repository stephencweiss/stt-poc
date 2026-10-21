"""Resolve fresh PR revisions for an explicitly requested CI check."""

import json
import os
import re
import subprocess
from pathlib import Path


def revisions(data, repository):
    if data.get('state') != 'open':
        raise ValueError('CI requires an open PR')
    for side in ('head', 'base'):
        if (data.get(side, {}).get('repo') or {}).get('full_name') != repository:
            raise ValueError('Manual checks support branches in this repository only')
    result = {'merge': data.get('merge_commit_sha'), 'head': data['head'].get('sha'), 'base': data['base'].get('sha')}
    if any(not isinstance(sha, str) or not re.fullmatch('[0-9a-f]{40}', sha) for sha in result.values()):
        raise ValueError('Current merge revision is unavailable; resolve conflicts or retry after GitHub computes it')
    return result


def main():
    number = os.environ['PR_NUMBER']
    if not number.isdecimal() or int(number) < 1:
        raise ValueError('A positive PR number is required')
    repository = os.environ['GITHUB_REPOSITORY']
    data = json.loads(subprocess.check_output(['gh', 'api', f'repos/{repository}/pulls/{number}']))
    result = revisions(data, repository)
    with Path(os.environ['GITHUB_OUTPUT']).open('a') as output:
        for key, sha in result.items():
            output.write(f'{key}={sha}\n')
    with Path(os.environ['GITHUB_STEP_SUMMARY']).open('a') as summary:
        summary.write(f'Checking PR #{number}\n\n')
        for key, sha in result.items():
            summary.write(f'- {key}: `{sha}`\n')


if __name__ == '__main__':
    main()
