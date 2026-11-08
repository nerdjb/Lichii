#!/usr/bin/env bash
# Merge zortos293/Lichii's nx2 branch into this fork, push it, and optionally rebuild and publish
# the PGO binary as a new release.
#
# GitHub disables Actions on this fork, so this runs on the machine that owns the fork instead of
# in a workflow: by hand, from cron, or from the lichii-sync systemd timer.
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
branch="nx2-amd-framegen"
upstream_url="https://github.com/zortos293/Lichii.git"
build=0
release=0
dry_run=0
force=0

usage() {
    echo "usage: $0 [--build] [--release] [--force] [--dry-run]"
    echo "  --build    rebuild the PGO binary after a merge"
    echo "  --release  also publish it as the next build-N release (implies --build)"
    echo "  --force    build and publish even when upstream has not moved"
    echo "  --dry-run  print what would happen"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --build) build=1; shift ;;
        --release) release=1; build=1; shift ;;
        --force) force=1; shift ;;
        --dry-run) dry_run=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

cd "$repo"

run() {
    if [ "$dry_run" = 1 ]; then
        echo "+ $*"
    else
        "$@"
    fi
}

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Working tree has uncommitted changes; commit or stash them first." >&2
    exit 1
fi

# One run at a time, so the timer and a manual run cannot build over each other.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/lichii-sync.lock"
flock -n 9 || { echo "Another sync is already running." >&2; exit 0; }

repo_slug=$(git remote get-url origin | sed -E 's#.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$#\1#')

latest_build_number() {
    local slug=$1
    gh release list -R "$slug" --limit 100 --json tagName --jq '
        [.[].tagName | select(test("^build-[0-9]+$")) | sub("^build-"; "") | tonumber] | max // 0'
}

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$upstream_url"
git fetch --no-tags upstream nx2

changed=0
if git merge-base --is-ancestor upstream/nx2 HEAD; then
    echo "Already up to date with upstream/nx2."
else
    if ! git merge --no-edit upstream/nx2; then
        git merge --abort || true
        echo "Merge conflict in $repo. Resolve it, commit, then run this script again." >&2
        exit 1
    fi
    changed=1
fi

run git push origin "HEAD:$branch"

if [ "$build" != 1 ] || { [ "$changed" != 1 ] && [ "$force" != 1 ]; }; then
    exit 0
fi

# Continue the build numbering from whichever is higher, this fork or upstream, so the number
# never looks older than upstream's releases.
here=$(latest_build_number "$repo_slug")
there=$(latest_build_number "zortos293/Lichii")
next=$(( (here > there ? here : there) + 1 ))
tag="build-$next"
sha=$(git rev-parse HEAD)

echo "Building $tag from $sha"
run cmake -S . -B build-pgo "-DLICHII_BUILD_TAG=$tag"
run cmake --build build-pgo --parallel "${LICHII_BUILD_JOBS:-12}"

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/bin"
cp build-pgo/bin/lichii build-pgo/bin/eden-cli build-pgo/bin/nx2_switches.txt "$stage/bin/"
strip "$stage/bin/lichii" "$stage/bin/eden-cli"
run tar -czf "$stage/lichii-linux-x86_64-pgo.tar.gz" -C "$stage/bin" \
    lichii eden-cli nx2_switches.txt

if [ "$release" != 1 ]; then
    echo "Built $tag; leaving it unpublished (no --release)."
    exit 0
fi

run gh release create "$tag" "$stage/lichii-linux-x86_64-pgo.tar.gz" -R "$repo_slug" \
    --target "$sha" \
    --title "Lichii nx2 build $next (${sha:0:7})" \
    --notes "Lichii \`nx2\` with AMD frame generation, built from \`$sha\` (upstream \`$(git rev-parse --short upstream/nx2)\`).

- Large-motion optical flow in the built-in generator, paced generated frames, frame-gen status logging
- Linux x86_64 PGO build (clang + \`eglantine.profdata\`); extract and run \`lichii\`
- Enable in Graphics → Enable Frame Generation, type Optical Flow Interpolation (built-in)"
