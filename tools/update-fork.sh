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
auto=0

usage() {
    echo "usage: $0 [--build] [--release] [--auto] [--force] [--dry-run]"
    echo "  --build    rebuild the PGO binary after a merge"
    echo "  --release  publish it as the next build-N release (implies --build)"
    echo "  --auto     with --release, publish at most once per day (used by the timer)"
    echo "  --force    build and publish even when the code is already published"
    echo "  --dry-run  print what would happen"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --build) build=1; shift ;;
        --release) release=1; build=1; shift ;;
        --auto) auto=1; shift ;;
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

if [ "$build" != 1 ]; then
    exit 0
fi

sha=$(git rev-parse HEAD)

if [ "$release" = 1 ]; then
    # The timer publishes at most one build per day; a manual --release is an explicit request to
    # build now, so it skips this check.
    if [ "$auto" = 1 ] && [ "$force" != 1 ]; then
        published=$(gh release list -R "$repo_slug" --limit 1 --json publishedAt --jq '.[0].publishedAt // ""')
        if [ "${published:0:10}" = "$(date -u +%F)" ]; then
            echo "A release was already published today ($published); leaving the source updated only."
            exit 0
        fi
    fi

    # A merge can land without a release: a timer run stopped by the daily guard, or an earlier
    # run that only pushed the source. Publish whatever HEAD is now, not just what merged this run.
    latest_tag=$(gh release list -R "$repo_slug" --limit 1 --json tagName --jq '.[0].tagName // ""')
    if [ "$changed" != 1 ] && [ -n "$latest_tag" ] && [ "$force" != 1 ]; then
        latest_sha=$(gh release view "$latest_tag" -R "$repo_slug" \
            --json targetCommitish --jq '.targetCommitish // ""')
        if [ "$latest_sha" = "$sha" ]; then
            echo "HEAD ${sha:0:7} is already published as $latest_tag."
            exit 0
        fi
        # A commit that only touches docs or this tooling does not change the binary.
        if git cat-file -e "$latest_sha^{commit}" 2>/dev/null &&
            git diff --quiet "$latest_sha" "$sha" -- . \
                ':(exclude)README.md' ':(exclude)AGENTS.md' ':(exclude)docs' \
                ':(exclude)tools' ':(exclude).github'; then
            echo "Only docs/tools changed since $latest_tag; nothing to rebuild."
            exit 0
        fi
        echo "No new upstream commits, but HEAD ${sha:0:7} is not published yet; building it."
    fi
elif [ "$changed" != 1 ] && [ "$force" != 1 ]; then
    exit 0
fi

# Continue the build numbering from whichever is higher, this fork or upstream, so the number
# never looks older than upstream's releases.
here=$(latest_build_number "$repo_slug")
there=$(latest_build_number "zortos293/Lichii")
next=$(( (here > there ? here : there) + 1 ))
tag="build-$next"

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
