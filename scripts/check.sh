#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -gt 1 || (${1:-} != '' && ${1:-} != '--quick') ]]; then
    echo 'Usage: ./scripts/check.sh [--quick]' >&2
    exit 2
fi
python3 scripts/tooling.py verify
python3 scripts/repository.py documents
scanner=$(python3 scripts/tooling.py path gitleaks)
if [[ ${1:-} == '--quick' ]]; then
    python3 scripts/repository.py paths --staged
    python3 scripts/repository.py fixtures --staged
    python3 scripts/repository.py secrets --staged --scanner "$scanner"
else
    python3 scripts/repository.py paths
    python3 scripts/repository.py secrets --scanner "$scanner"
fi
python3 scripts/tooling.py swift-check
if [[ ${1:-} == '--quick' ]]; then
    echo 'Quick checks passed; full tests are still required before review.'
    exit 0
fi
python3 scripts/repository.py fixtures
python3 scripts/repository.py source-status
python3 -m unittest discover -s scripts/tests -v
shellcheck=$(python3 scripts/tooling.py path shellcheck)
"$shellcheck" scripts/*.sh .githooks/pre-commit
for script in scripts/*.sh .githooks/pre-commit; do
    bash -n "$script"
done
actionlint=$(python3 scripts/tooling.py path actionlint)
"$actionlint" -shellcheck "$shellcheck"
if [[ -f Package.swift ]]; then
    swift build -Xswiftc -warnings-as-errors
    swift test -Xswiftc -warnings-as-errors
    if [[ ! -x scripts/build-app.sh ]]; then
        echo 'Package.swift requires an executable scripts/build-app.sh packaging check.' >&2
        exit 1
    fi
    ./scripts/build-app.sh
fi
echo 'Foundation checks passed. See explicit application-check status above.'
