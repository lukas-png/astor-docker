#!/usr/bin/env bash
# =============================================================================
# Generic replication image builder.
#
#   ./build.sh [replication] [version] [--push]
#
# Builds the image(s) for a replication under replications/<replication>/.
# Defaults to the RepairThemAll (Astor) replication. Each replication declares
# its image tag, versions, vendored artefacts and on-demand downloads in its own
# replications/<name>/build.env, so new papers slot in as a new folder.
#
#   ./build.sh                       # build repairthemall, all versions
#   ./build.sh repairthemall 1.4.0   # build one version
#   ./build.sh repairthemall --push  # build and push to the registry
# =============================================================================
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cyan()   { printf '\033[36m%b\033[0m\n' "$*"; }
green()  { printf '\033[32m%b\033[0m\n' "$*"; }
yellow() { printf '\033[33m%b\033[0m\n' "$*"; }
red()    { printf '\033[31m%b\033[0m\n' "$*"; }

# -----------------------------------------------------------------------------
# Arguments: [replication] [version-filter] [--push]
# -----------------------------------------------------------------------------
REPL=""
FILTER=""
PUSH=0
for arg in "$@"; do
    case "$arg" in
        --push) PUSH=1 ;;
        *)      if [[ -z "$REPL" ]]; then REPL="$arg"; else FILTER="$arg"; fi ;;
    esac
done
REPL="${REPL:-repairthemall}"

REPL_DIR="$BASE_DIR/replications/$REPL"
if [[ ! -d "$REPL_DIR" ]]; then
    red "Unknown replication '$REPL' (no $REPL_DIR)"
    yellow "Available replications:"
    ls "$BASE_DIR/replications" 2>/dev/null | sed 's/^/  - /'
    exit 1
fi
if [[ ! -f "$REPL_DIR/build.env" ]]; then
    red "Missing manifest $REPL_DIR/build.env"
    exit 1
fi

# Defaults the manifest may override.
IMAGE="$REPL"
REGISTRY="${REGISTRY:-ghcr.io/lukas-png/docker-astor}"
VERSION_BUILD_ARG="D4J_VERSION"
BUILDS=()
VENDORED=()
RESOURCES=()
declare -A SHA256SUMS=()
# shellcheck disable=SC1090,SC1091
source "$REPL_DIR/build.env"

RES_DIR="$REPL_DIR/resources"

# -----------------------------------------------------------------------------
# Verify the vendored, pinned artefacts are present (committed, never downloaded).
# -----------------------------------------------------------------------------
check_vendored() {
    local file dest want got
    for file in "${VENDORED[@]}"; do
        dest="$RES_DIR/$file"
        if [[ ! -s "$dest" ]]; then
            red "Missing vendored artefact $REPL/resources/$file"
            red "It is committed to the repo on purpose (pinned replication artefact)."
            red "Restore it from version control instead of downloading."
            exit 1
        fi
        want="${SHA256SUMS[$file]:-}"
        if [[ -n "$want" ]]; then
            got="$(sha256sum "$dest" | cut -d' ' -f1)"
            if [[ "$got" != "$want" ]]; then
                red "Checksum mismatch for $REPL/resources/$file"
                red "  expected sha256: $want"
                red "  actual   sha256: $got"
                red "The pinned artefact has drifted -- replication would be unfaithful. Aborting."
                exit 1
            fi
            green "resources/$file present (vendored, sha256 ok)"
        else
            yellow "resources/$file present (vendored, no sha256 recorded)"
        fi
    done
}

# -----------------------------------------------------------------------------
# Fetch any resources/<file> that is absent so a clean checkout can build without
# manual downloads. Existing (non-empty) files are left untouched.
# -----------------------------------------------------------------------------
ensure_resources() {
    local entry file url fallback dest tmp
    for entry in "${RESOURCES[@]}"; do
        IFS='|' read -r file url fallback <<< "$entry"
        dest="$RES_DIR/$file"

        if [[ -s "$dest" ]]; then
            green "resources/$file present"
            continue
        fi

        cyan "Downloading $file from $url"
        tmp="$dest.partial"
        if curl -fL --retry 3 -o "$tmp" "$url"; then
            mv "$tmp" "$dest"
            green "Downloaded resources/$file"
        else
            rm -f "$tmp"
            if [[ -n "$fallback" && -s "$fallback" ]]; then
                yellow "Download failed; using fallback $fallback"
                cp "$fallback" "$dest"
                green "Copied resources/$file from fallback"
            else
                red "Failed to obtain $file"
                exit 1
            fi
        fi
    done
}

cyan "Replication: $REPL  (image: $IMAGE, registry: $REGISTRY)"
check_vendored
ensure_resources

# -----------------------------------------------------------------------------
# Container engine: honour $ENGINE if set, otherwise prefer podman, then docker.
# -----------------------------------------------------------------------------
ENGINE="${ENGINE:-}"
if [[ -z "$ENGINE" ]]; then
    if command -v podman >/dev/null 2>&1; then
        ENGINE="podman"
    elif command -v docker >/dev/null 2>&1; then
        ENGINE="docker"
    else
        red "Neither podman nor docker found on PATH."
        exit 1
    fi
elif ! command -v "$ENGINE" >/dev/null 2>&1; then
    red "Requested engine '$ENGINE' not found on PATH."
    exit 1
fi

built=()
pushed=()
for ver in "${BUILDS[@]}"; do
    [[ -n "$FILTER" && "$ver" != "$FILTER" ]] && continue

    local_tag="$IMAGE:$ver"

    cyan "\nBuilding $local_tag ($REPL $ver) with $ENGINE"
    "$ENGINE" build \
        --build-arg "${VERSION_BUILD_ARG}=$ver" \
        -t "$local_tag" \
        "$REPL_DIR" || { red "Failed to build $local_tag"; exit 1; }
    green "Built $local_tag"
    built+=("$local_tag")

    if [[ "$PUSH" -eq 1 ]]; then
        remote_tag="$REGISTRY:$ver"
        "$ENGINE" tag "$local_tag" "$remote_tag"
        cyan "Pushing $remote_tag"
        "$ENGINE" push "$remote_tag"
        green "Pushed  $remote_tag"
        pushed+=("$remote_tag")
    fi
done

if [[ ${#built[@]} -eq 0 ]]; then
    yellow "No version matched filter '$FILTER'."
    exit 1
fi

if [[ "$PUSH" -eq 1 ]]; then
    green "\nAll images pushed to $REGISTRY:"
    printf '  - %s\n' "${pushed[@]}"
else
    green "\nAll requested images built:"
    printf '  - %s\n' "${built[@]}"
    echo
    echo "Run one with e.g.: $ENGINE run --rm -it ${built[0]} run-astor Math-70"
fi
