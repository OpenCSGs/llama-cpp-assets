#!/bin/sh
set -eu

REPO_ROOT="$(CDPATH='' cd "$(dirname "$0")/.." && pwd)"
ASSETS_GO="${REPO_ROOT}/assets.go"
TARGET_CONVERTER="${REPO_ROOT}/data/convert_hf_to_gguf.py"
TARGET_GGUF_DIR="${REPO_ROOT}/data/gguf-py"
MODE="sync"
TAG=""

info() { printf "\033[0;32m[INFO]\033[0m %s\n" "$1"; }
die() { printf "\033[0;31m[ERROR]\033[0m %s\n" "$1" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage: scripts/sync-llama-cpp.sh [--check] [--tag TAG]

Synchronize convert_hf_to_gguf.py and gguf-py from one llama.cpp release.

Options:
  --check       Verify checked-in assets against their pinned upstream release
  --tag TAG     llama.cpp release tag; defaults to assets.LlamaCppRef
EOF
}

current_tag() {
    sed -n 's/^[[:space:]]*LlamaCppRef = "\(.*\)"$/\1/p' "${ASSETS_GO}"
}

current_revision() {
    sed -n 's/^[[:space:]]*Revision = \([0-9][0-9]*\)$/\1/p' "${ASSETS_GO}"
}

apply_local_converter_patches() {
    python3 - "$1" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
patched_hash = "a77756c3cc91392f442c5b99e414be8020d53ae31460de90754b4fcf5cc84a2d"
if patched_hash in text:
    raise SystemExit(0)

anchor = """        if chkhsh == "f4f37b6c8eb9ea29b3eac6bb8c8487c5ab7885f8d8022e67edc1c68ce8403e95":
            # ref: https://huggingface.co/MiniMaxAI/MiniMax-M2
            res = "minimax-m2"
"""
replacement = anchor + """        if chkhsh == "a77756c3cc91392f442c5b99e414be8020d53ae31460de90754b4fcf5cc84a2d":
            # ref: https://huggingface.co/MiniMaxAI/MiniMax-M2.5
            res = "minimax-m2"
"""
if anchor not in text:
    raise SystemExit("failed to apply local MiniMax tokenizer hash patch")
path.write_text(text.replace(anchor, replacement, 1), encoding="utf-8")
PY
}

same_tree() {
    python3 - "$1" "$2" <<'PY'
from pathlib import Path
import hashlib
import sys

def tree(root):
    root = Path(root)
    if not root.is_dir():
        return None
    return {
        path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).digest()
        for path in root.rglob("*")
        if path.is_file()
    }

raise SystemExit(0 if tree(sys.argv[1]) == tree(sys.argv[2]) else 1)
PY
}

while [ $# -gt 0 ]; do
    case "$1" in
        --check) MODE="check"; shift ;;
        --tag) TAG="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
done

command -v curl >/dev/null 2>&1 || die "curl not found on PATH"
command -v python3 >/dev/null 2>&1 || die "python3 not found on PATH"
[ -f "${ASSETS_GO}" ] || die "assets.go not found"

CURRENT_TAG="$(current_tag)"
CURRENT_REVISION="$(current_revision)"
[ -n "${CURRENT_TAG}" ] || die "failed to parse LlamaCppRef"
[ -n "${CURRENT_REVISION}" ] || die "failed to parse Revision"
[ -n "${TAG}" ] || TAG="${CURRENT_TAG}"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/llama-cpp-assets.XXXXXX")"
TMP_CONVERTER="${TMP_ROOT}/convert_hf_to_gguf.py"
TMP_ARCHIVE="${TMP_ROOT}/llama.cpp.tar.gz"
TMP_GGUF_DIR="${TMP_ROOT}/gguf-py"
trap 'rm -rf "${TMP_ROOT}"' EXIT INT TERM

RAW_URL="https://raw.githubusercontent.com/ggml-org/llama.cpp/${TAG}/convert_hf_to_gguf.py"
ARCHIVE_URL="https://github.com/ggml-org/llama.cpp/archive/refs/tags/${TAG}.tar.gz"

info "Fetching ${RAW_URL}"
curl -fsSL -o "${TMP_CONVERTER}" "${RAW_URL}"
apply_local_converter_patches "${TMP_CONVERTER}"

info "Fetching ${ARCHIVE_URL}"
curl -fsSL -o "${TMP_ARCHIVE}" "${ARCHIVE_URL}"
python3 - "${TMP_ARCHIVE}" "${TMP_GGUF_DIR}" <<'PY'
from pathlib import Path
import shutil
import sys
import tarfile

archive = Path(sys.argv[1])
dst = Path(sys.argv[2])
dst.mkdir(parents=True)

with tarfile.open(archive, "r:gz") as tf:
    found = False
    for member in tf:
        marker = "/gguf-py/"
        name = member.name.lstrip("./")
        if marker not in name:
            continue
        rel = name.split(marker, 1)[1]
        if not rel:
            continue
        target = dst / rel
        if not target.resolve().is_relative_to(dst.resolve()):
            raise SystemExit(f"unsafe gguf-py archive path: {member.name}")
        if member.isdir():
            target.mkdir(parents=True, exist_ok=True)
            found = True
        elif member.isfile():
            target.parent.mkdir(parents=True, exist_ok=True)
            source = tf.extractfile(member)
            if source is None:
                raise SystemExit(f"failed to read {member.name}")
            with source, target.open("wb") as output:
                shutil.copyfileobj(source, output)
            found = True

if not found or not (dst / "gguf" / "__init__.py").is_file():
    raise SystemExit("llama.cpp archive did not contain a complete gguf-py package")
PY

SAME_CONVERTER=0
SAME_GGUF=0
cmp -s "${TMP_CONVERTER}" "${TARGET_CONVERTER}" && SAME_CONVERTER=1
same_tree "${TARGET_GGUF_DIR}" "${TMP_GGUF_DIR}" && SAME_GGUF=1

if [ "${MODE}" = "check" ]; then
    if [ "${CURRENT_TAG}" = "${TAG}" ] &&
       [ "${SAME_CONVERTER}" -eq 1 ] &&
       [ "${SAME_GGUF}" -eq 1 ]; then
        info "Bundled assets match llama.cpp ${TAG}"
        exit 0
    fi
    die "bundled assets do not match llama.cpp ${TAG}"
fi

NEW_REVISION="${CURRENT_REVISION}"
if [ "${CURRENT_TAG}" != "${TAG}" ] ||
   [ "${SAME_CONVERTER}" -eq 0 ] ||
   [ "${SAME_GGUF}" -eq 0 ]; then
    NEW_REVISION=$((CURRENT_REVISION + 1))
fi

mkdir -p "${REPO_ROOT}/data"
cp "${TMP_CONVERTER}" "${TARGET_CONVERTER}"
rm -rf "${TARGET_GGUF_DIR}"
mv "${TMP_GGUF_DIR}" "${TARGET_GGUF_DIR}"

python3 - "${ASSETS_GO}" "${TAG}" "${NEW_REVISION}" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
tag = sys.argv[2]
revision = sys.argv[3]
text = path.read_text(encoding="utf-8")
text, tag_count = re.subn(
    r'LlamaCppRef = "[^"]+"',
    f'LlamaCppRef = "{tag}"',
    text,
    count=1,
)
text, revision_count = re.subn(
    r"Revision = \d+",
    f"Revision = {revision}",
    text,
    count=1,
)
if tag_count != 1 or revision_count != 1:
    raise SystemExit("failed to update assets.go")
path.write_text(text, encoding="utf-8")
PY

gofmt -w "${ASSETS_GO}"
info "Synced llama.cpp ${TAG} assets (revision ${NEW_REVISION})"
