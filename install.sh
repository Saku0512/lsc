#!/bin/sh
set -eu

PROG="lsc"
DEFAULT_PREFIX="/usr/local"
SOURCE_URL="https://raw.githubusercontent.com/Saku0512/lsc/main/main.c"

usage() {
    cat <<EOF
Usage: sh install.sh [--prefix DIR] [--help]

Installs ${PROG} into DIR/bin.
If /usr/local/bin is not writable, defaults to ~/.local/bin.

Options:
  --prefix DIR   install into DIR/bin
  --help         show this help message
EOF
}

PREFIX="${PREFIX:-${DEFAULT_PREFIX}}"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --prefix)
            if [ $# -lt 2 ]; then
                echo "Error: --prefix requires a directory argument." >&2
                usage
                exit 1
            fi
            PREFIX="$2"
            shift 2
            ;;
        --prefix=*)
            PREFIX="${1#*=}"
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Error: unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if [ ! -f "main.c" ]; then
    echo "Downloading source file..."
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${SOURCE_URL}" -o main.c
    elif command -v wget >/dev/null 2>&1; then
        wget -qO main.c "${SOURCE_URL}"
    else
        echo "Error: curl or wget is required to download source." >&2
        exit 1
    fi
fi

if ! command -v gcc >/dev/null 2>&1; then
    echo "Error: gcc is required to build ${PROG}." >&2
    exit 1
fi

if [ ! -w "${PREFIX}/bin" ] && [ "$(id -u)" -ne 0 ]; then
    PREFIX="${HOME}/.local"
fi

BUILD_DIR=".build"
mkdir -p "${BUILD_DIR}"
gcc -Wall -Wextra -O2 -o "${BUILD_DIR}/${PROG}" main.c

install_dir="${PREFIX}/bin"
mkdir -p "${install_dir}"
install -m 755 "${BUILD_DIR}/${PROG}" "${install_dir}/${PROG}"

echo "${PROG} installed to ${install_dir}/${PROG}"
if [ "${install_dir}" != "/usr/local/bin" ] && [ "${install_dir}" != "/usr/bin" ]; then
    echo "Add ${install_dir} to PATH if it is not already available."
fi
