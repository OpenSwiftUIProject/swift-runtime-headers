#!/bin/bash

# Syncs headers from the upstream swiftlang/swift repo into this mirror repo.
# Usage: ./sync.sh --branch release/6.3

set -e

BRANCH=""
UPSTREAM_URL="git@github.com:swiftlang/swift.git"

while [[ $# -gt 0 ]]; do
    case $1 in
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 --branch <branch>"
            echo "Example: $0 --branch release/6.3"
            exit 1
            ;;
    esac
done

if [ -z "$BRANCH" ]; then
    echo "Error: --branch is required"
    exit 1
fi

SWIFT_VERSION=$(echo "$BRANCH" | grep -oE '[0-9]+\.[0-9]+')
SWIFT_VERSION_MAJOR=$(echo "$SWIFT_VERSION" | cut -d. -f1)
SWIFT_VERSION_MINOR=$(echo "$SWIFT_VERSION" | cut -d. -f2)

if [ -z "$SWIFT_VERSION_MAJOR" ] || [ -z "$SWIFT_VERSION_MINOR" ]; then
    echo "Error: Could not extract version from branch '$BRANCH'"
    exit 1
fi

HEADERS_DIR=$(cd "$(dirname "$0")" && pwd)
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "Cloning upstream $BRANCH..."
git clone --filter=blob:none --no-checkout --depth 1 \
    --branch "$BRANCH" "$UPSTREAM_URL" "$TMPDIR/swift"

cd "$TMPDIR/swift"
git sparse-checkout set --no-cone \
    /include/swift \
    /stdlib/include \
    /stdlib/public/SwiftShims \
    /stdlib/public/runtime/MetadataAllocatorTags.def
git checkout

cd "$HEADERS_DIR"

# Replace headers with upstream content
rm -rf include include
rm -rf include stdlib
cp -R "$TMPDIR/swift/include" .
cp -R "$TMPDIR/swift/stdlib" .

# Write CMakeConfig.h
cat > include/swift/Runtime/CMakeConfig.h << EOF
#ifndef SWIFT_RUNTIME_CMAKECONFIG_H
#define SWIFT_RUNTIME_CMAKECONFIG_H
#define SWIFT_VERSION_MAJOR "$SWIFT_VERSION_MAJOR"
#define SWIFT_VERSION_MINOR "$SWIFT_VERSION_MINOR"
#endif
EOF

echo "Headers synced from $BRANCH (Swift $SWIFT_VERSION_MAJOR.$SWIFT_VERSION_MINOR)"
