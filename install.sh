#!/bin/sh
# net4sats installer wrapper — served from this repo's GitHub Pages so the
# documented `curl -fsSL https://net4sats.github.io/install.sh | sh` (and
# net4sats.com/install.sh once the domain points here) resolves.
#
# The canonical script lives in net4sats/installer@main. This wrapper fetches and
# execs it so there is exactly ONE copy of the install logic. If this fetch fails,
# fall back to telling the user the canonical location.
set -eu
CANONICAL="https://raw.githubusercontent.com/net4sats/installer/main/install.sh"
if command -v curl >/dev/null 2>&1; then
    exec sh -c "N4S_REPO_SLUG=net4sats/installer exec curl -fsSL '$CANONICAL' | sh -s -- $*"
elif command -v wget >/dev/null 2>&1; then
    exec sh -c "N4S_REPO_SLUG=net4sats/installer exec wget -qO- '$CANONICAL' | sh -s -- $*"
fi
echo "ERROR: need curl or wget to fetch $CANONICAL" >&2
exit 1
