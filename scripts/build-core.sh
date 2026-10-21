#!/usr/bin/env bash
###############################################################################
# build-core.sh · builds oscompliance-agent and oscompliance-engine from
# $CORE_SRC for the lab containers (linux, same CPU architecture as the Docker
# host).
#
# Output: build/oscompliance/, mounted read-only into agent-01 and engine.
###############################################################################
set -euo pipefail
. "$(dirname "$0")/lib.sh"

command -v go >/dev/null || die "go is not installed"

arch="$(docker version --format '{{.Server.Arch}}')"
version="$(git -C "$CORE_SRC" describe --always --dirty 2>/dev/null || echo dev)"
mkdir -p "$LAB_DIR/build/oscompliance"

for part in agent engine; do
  step "oscompliance-$part from $CORE_SRC/$part"
  [ -f "$CORE_SRC/$part/go.mod" ] || die "no Go module in $CORE_SRC/$part"
  ( cd "$CORE_SRC/$part" \
    && CGO_ENABLED=0 GOOS=linux GOARCH="$arch" \
       go build -trimpath -ldflags "-X main.version=$version" \
         -o "$LAB_DIR/build/oscompliance/oscompliance-$part" "./cmd/oscompliance-$part" )
  ok "linux/$arch, version $version"
done
