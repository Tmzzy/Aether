#!/bin/bash
# aether-hub 构建脚本
#
# 示例:
#   ./build.sh
#   ./build.sh amd64
#   ./build.sh --upload hub-v0.1.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"

# -------------------------------
# Options
# -------------------------------
UPLOAD=false
UPLOAD_TAG=""
BINARY_TARGETS=""

usage() {
    cat <<'EOF'
用法:
  ./build.sh [args]

参数:
  amd64|arm64              仅构建指定架构（可重复）
  --upload <hub-vX.Y.Z>    上传到 GitHub Release（需要 gh CLI）
  -h, --help               显示帮助
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --upload)
            UPLOAD=true
            UPLOAD_TAG="${2:-}"
            shift 2
            ;;
        amd64|arm64)
            BINARY_TARGETS="$BINARY_TARGETS $1"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "❌ 未知参数: $1"
            usage
            exit 1
            ;;
    esac
done

build_binary() {
    if [ -z "$BINARY_TARGETS" ]; then
        BINARY_TARGETS="amd64 arm64"
    fi

    if ! command -v cross >/dev/null 2>&1; then
        echo "❌ 需要安装 cross: cargo install cross --git https://github.com/cross-rs/cross"
        exit 1
    fi

    mkdir -p "$DIST_DIR"

    echo "🔨 开始构建 aether-hub 二进制..."
    echo "   目标平台: $BINARY_TARGETS"
    echo ""

    ARTIFACTS=""
    for arch in $BINARY_TARGETS; do
        case "$arch" in
            amd64) target="x86_64-unknown-linux-gnu" ;;
            arm64) target="aarch64-unknown-linux-gnu" ;;
            *) echo "❌ 未知架构: $arch"; exit 1 ;;
        esac

        echo ">>> 构建 $arch ($target)..."
        cd "$SCRIPT_DIR"
        cross build --release --target "$target" --locked

        BIN="target/$target/release/aether-hub"
        if [ ! -f "$BIN" ]; then
            echo "❌ 未找到二进制文件: $BIN"
            exit 1
        fi

        ARCHIVE="$DIST_DIR/aether-hub-linux-$arch.tar.gz"
        tar czf "$ARCHIVE" -C "target/$target/release" aether-hub
        ARTIFACTS="$ARTIFACTS $ARCHIVE"

        SIZE=$(du -h "$ARCHIVE" | cut -f1)
        echo "✅ $arch 构建完成: $ARCHIVE ($SIZE)"
        echo ""
    done

    cd "$DIST_DIR"
    shasum -a 256 aether-hub-*.tar.gz > SHA256SUMS.txt
    echo "📋 SHA256 校验和:"
    cat SHA256SUMS.txt
    echo ""

    if [ "$UPLOAD" = true ]; then
        if [ -z "$UPLOAD_TAG" ]; then
            echo "❌ --upload 需要指定 tag，例如: ./build.sh --upload hub-v0.1.0"
            exit 1
        fi
        if ! command -v gh >/dev/null 2>&1; then
            echo "❌ 需要安装 GitHub CLI: brew install gh"
            exit 1
        fi

        echo "📦 上传到 GitHub Release: $UPLOAD_TAG"
        cd "$PROJECT_DIR"

        if ! git rev-parse "$UPLOAD_TAG" >/dev/null 2>&1; then
            git tag "$UPLOAD_TAG"
            git push origin "$UPLOAD_TAG"
        fi

        gh release create "$UPLOAD_TAG" \
            --title "aether-hub ${UPLOAD_TAG#hub-}" \
            --generate-notes \
            $ARTIFACTS \
            "$DIST_DIR/SHA256SUMS.txt"

        echo "✅ 上传完成!"
    fi

    echo "🎉 构建完成!"
}

build_binary
