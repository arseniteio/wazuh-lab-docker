#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

[ -f "$PLUGIN_SRC/opensearch_dashboards.json" ] \
  || die "PLUGIN_SRC does not point to the plugin: $PLUGIN_SRC"
docker image inspect "$OSD_BUILDER_IMAGE" >/dev/null 2>&1 \
  || die "missing image $OSD_BUILDER_IMAGE (built from ci/osd-builder.Dockerfile in the plugin)"

ZIP="$LAB_DIR/build/power-ens-$POWER_ENS_VERSION-osd-2.19.5.zip"
mkdir -p "$LAB_DIR/build"

step "Building Power ENS $POWER_ENS_VERSION from $PLUGIN_SRC"
docker run --rm \
  -v "$PLUGIN_SRC:/src:ro" \
  -v "$LAB_DIR/build:/out" \
  "$OSD_BUILDER_IMAGE" \
  bash -c 'bash /src/config/build-plugin.sh /osd && cp /osd/plugins/powerEns/build/powerEns-2.19.5.zip /out/zip.tmp'
mv "$LAB_DIR/build/zip.tmp" "$ZIP"
ok "zip ready: $ZIP"
