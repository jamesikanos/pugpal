#!/bin/bash
# PugPal build entrypoint. Runs inside the Containerfile RUN step with the
# build context mounted at /ctx. Each numbered stage owns one area of the
# image; add a package to the stage it belongs to, not here.

set -euxo pipefail

# Overlay our files onto / first, so stages can rely on them.
cp -avf /ctx/system_files/. /

for stage in /ctx/[0-9][0-9]-*.sh; do
    echo "::group:: ===== $(basename "$stage") ====="
    bash "$stage"
    echo "::endgroup::"
done
