#!/usr/bin/env bash
###############################################################################
# build-plugin.sh · builds the ENSFácil zip from the plugin source.
#
#   scripts/build-plugin.sh
#
# Uses the ensfacil-osd-builder:2.19.5 image (an OSD 2.19.5 tree already
# prepared with `yarn osd bootstrap`, see ci/osd-builder.Dockerfile in the
# plugin). The source is mounted read-only: the build never writes to your repo.
# Leaves the zip at build/ensfacil-<version>-osd-2.19.5.zip.
###############################################################################
set -euo pipefail
. "$(dirname "$0")/lib.sh"

[ -f "$PLUGIN_SRC/opensearch_dashboards.json" ] \
  || die "PLUGIN_SRC does not point to the plugin: $PLUGIN_SRC"
docker image inspect "$OSD_BUILDER_IMAGE" >/dev/null 2>&1 \
  || die "missing image $OSD_BUILDER_IMAGE (built from ci/osd-builder.Dockerfile in the plugin)"

ZIP="$LAB_DIR/build/ensfacil-$ENSFACIL_VERSION-osd-2.19.5.zip"
mkdir -p "$LAB_DIR/build"

step "Building ensfacil $ENSFACIL_VERSION from $PLUGIN_SRC"
docker run --rm \
  -v "$PLUGIN_SRC:/src:ro" \
  -v "$LAB_DIR/build:/out" \
  "$OSD_BUILDER_IMAGE" \
  bash -c 'bash /src/config/build-plugin.sh /osd && cp /osd/plugins/ensfacil/build/ensfacil-2.19.5.zip /out/zip.tmp'
mv "$LAB_DIR/build/zip.tmp" "$ZIP"
ok "zip ready: $ZIP"
