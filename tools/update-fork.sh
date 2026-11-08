#!/usr/bin/env bash
# Merge zortos293/Lichii's nx2 branch into this fork and push it.
#
# GitHub disables Actions on this fork, so the merge runs on the machine that owns the fork
# instead of in a workflow. Run it by hand, from cron, or from the lichii-sync systemd timer.
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
branch="nx2-amd-framegen"
upstream_url="https://github.com/zortos293/Lichii.git"
build=0

while [ $# -gt 0 ]; do
    case "$1" in
        --build) build=1; shift ;;
        -h|--help) echo "usage: $0 [--build]"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

cd "$repo"

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Working tree has uncommitted changes; commit or stash them first." >&2
    exit 1
fi

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$upstream_url"
git fetch --no-tags upstream nx2

if git merge-base --is-ancestor upstream/nx2 HEAD; then
    echo "Already up to date with upstream/nx2."
else
    if ! git merge --no-edit upstream/nx2; then
        git merge --abort || true
        echo "Merge conflict in $repo. Resolve it, commit, then run this script again." >&2
        exit 1
    fi
fi

git push origin "HEAD:$branch"

if [ "$build" = 1 ]; then
    cmake --build build-pgo --parallel "${LICHII_BUILD_JOBS:-16}"
fi
