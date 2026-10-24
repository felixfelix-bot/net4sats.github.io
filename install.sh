#!/bin/sh
# net4sats installer wrapper — served from this repo's GitHub Pages so the documented
#   curl -fsSL https://net4sats.github.io/install.sh | sh
# (and net4sats.com/install.sh once the domain points here) resolves.
#
# The canonical script lives in net4sats/installer@main. This wrapper fetches and runs it
# so exactly ONE copy of the install logic exists.
#
# The slug is what the canonical script's piped path needs: piped, it has no clone to read
# brand/active from, so it requires N4S_REPO_SLUG (or N4S_REPO_URL). It MUST be exported to
# the `sh` on the right-hand side of the pipe — the shell that runs the piped script is what
# reads it, not curl. (An earlier revision set it on curl, so the wrapper never worked.)
set -eu
CANONICAL="https://raw.githubusercontent.com/net4sats/installer/main/install.sh"

# Respect a caller-provided slug/URL; otherwise use the canonical repo.
if [ -n "${N4S_REPO_SLUG:-}" ] || [ -n "${N4S_REPO_URL:-}" ]; then
    export N4S_REPO_SLUG N4S_REPO_URL
else
    N4S_REPO_SLUG="net4sats/installer"
    export N4S_REPO_SLUG
fi

if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$CANONICAL" | sh -s -- "$@"
elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$CANONICAL" | sh -s -- "$@"
else
    echo "ERROR: need curl or wget to fetch $CANONICAL" >&2
    exit 1
fi
