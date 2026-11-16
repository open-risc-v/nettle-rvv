#!/usr/bin/env bash
# nettle 的 A/B：两侧各自用 autotools 构建，再用 run_ab.sh 的 DEVICE_MODE 比对。
#
# 为什么不用 CMake：nettle 是纯 autotools 工程，硬塞进 CMake 只会多一层转译。
# 骨架的 run_ab.sh 支持 RVV_A / RVV_B 直接给二进制目录（原本是给板子用的），
# 这里借同一个通道。
#
# 用法（在 Linux 容器或真机里）：
#   ./scripts/nettle-ab.sh
# 需要：autoconf/automake/libtool、交叉工具链、qemu（容器内跑时）
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD

SIDE_A=${SIDE_A:-src}
SIDE_B=${SIDE_B:-baseline}
OUT_A=${OUT_A:-build/ab-src}
OUT_B=${OUT_B:-build/ab-base}

CFG_HOST="${CFG_HOST:---host=riscv64-linux-gnu}"
CFLAGS_EXTRA="${CFLAGS_EXTRA:--O2}"
RUNNER="${RUNNER:-}"

build_side() {
  local srcdir=$1 outdir=$2
  if [ -x "$outdir/tools/nettle-hash" ]; then
    echo "== $outdir 已构建，跳过"
    return
  fi
  echo "== 构建 $srcdir -> $outdir"
  rm -rf "$outdir"
  mkdir -p "$outdir"
  # autotools 会往源码树写一堆生成文件，所以在副本里做，别碰 baseline
  cp -a "$srcdir/." "$outdir/"
  (
    cd "$outdir"
    if [ ! -x ./configure ]; then autoreconf -fi >/tmp/ar-$(basename "$outdir").log 2>&1; fi
    ./configure $CFG_HOST --build=x86_64-linux-gnu --disable-shared --enable-static \
        --enable-mini-gmp --disable-documentation \
        CFLAGS="$CFLAGS_EXTRA" > /tmp/cfg-$(basename "$outdir").log 2>&1 \
      || { echo "CONFIGURE FAIL ($srcdir)"; tail -20 /tmp/cfg-$(basename "$outdir").log; exit 1; }
    make -j"$(nproc)" > /tmp/mk-$(basename "$outdir").log 2>&1 \
      || { echo "MAKE FAIL ($srcdir)"; tail -20 /tmp/mk-$(basename "$outdir").log; exit 1; }
  )
}

build_side "$SIDE_A" "$OUT_A"
build_side "$SIDE_B" "$OUT_B"

echo "== A/B（DEVICE_MODE）"
RVV_A="$ROOT/$OUT_A" RVV_B="$ROOT/$OUT_B" RUNNER="$RUNNER" bash test/run_ab.sh
