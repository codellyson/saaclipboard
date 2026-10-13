#!/bin/sh
# Bumps the version, tags it, and pushes; the Release workflow builds and publishes the dmg.
#   pnpm release            patch bump (0.1.0 -> 0.1.1)
#   pnpm release minor      minor bump (0.1.0 -> 0.2.0)
#   pnpm release major      major bump (0.1.0 -> 1.0.0)
#   pnpm release 1.2.3      exact version
set -eu
cd "$(dirname "$0")/.."

PLIST=Support/Info.plist
CURRENT=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $PLIST)
BUMP=${1:-patch}

case $BUMP in
    major|minor|patch)
        IFS=. read -r MA MI PA <<EOV
$CURRENT
EOV
        case $BUMP in
            major) VERSION="$((MA + 1)).0.0" ;;
            minor) VERSION="$MA.$((MI + 1)).0" ;;
            patch) VERSION="$MA.$MI.$((PA + 1))" ;;
        esac ;;
    [0-9]*.[0-9]*.[0-9]*) VERSION=$BUMP ;;
    *) echo "usage: pnpm release [patch|minor|major|x.y.z]" >&2; exit 1 ;;
esac

[ "$(git branch --show-current)" = main ] || { echo "Release from main." >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Commit or stash your changes first." >&2; exit 1; }
git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null && { echo "v$VERSION already exists." >&2; exit 1; }

/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $VERSION" $PLIST
git commit -qm "Release v$VERSION" $PLIST
git tag "v$VERSION"
git push -q origin main "v$VERSION"
echo "Pushed v$VERSION ($CURRENT -> $VERSION). Watch it: gh run watch"
