#!/usr/bin/env bash
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

install -m 644 "$CORE_SRC/agent/oscompliance.cron" "$LAB_DIR/build/oscompliance/oscompliance.cron"
