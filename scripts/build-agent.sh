#!/usr/bin/env bash
###############################################################################
# build-agent.sh · builds oscompliance-agent from $CORE_SRC/agent for the lab
# agent container (linux, same CPU architecture as the Docker host).
#
# Output: build/oscompliance/oscompliance-agent, mounted read-only into agent-01.
###############################################################################
set -euo pipefail
. "$(dirname "$0")/lib.sh"

step "oscompliance-agent from $CORE_SRC/agent"
command -v go >/dev/null || die "go is not installed"
[ -f "$CORE_SRC/agent/go.mod" ] || die "no agent module in $CORE_SRC/agent"

arch="$(docker version --format '{{.Server.Arch}}')"
version="$(git -C "$CORE_SRC" describe --always --dirty 2>/dev/null || echo dev)"
mkdir -p "$LAB_DIR/build/oscompliance"
( cd "$CORE_SRC/agent" \
  && CGO_ENABLED=0 GOOS=linux GOARCH="$arch" \
     go build -trimpath -ldflags "-X main.version=$version" \
       -o "$LAB_DIR/build/oscompliance/oscompliance-agent" ./cmd/oscompliance-agent )
ok "linux/$arch, version $version"
