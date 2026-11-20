#!/usr/bin/env bash
set -euo pipefail
SRC=$1
OUT=$2
MARCH=${3:-rv64gcv}
KERN=${4:-0}
if [ "$KERN" = "1" ]; then export CFLAGS="${CFLAGS:-} -march=${MARCH} -DRVV_KERNELS=1"; fi
mkdir -p "$OUT/pkg"
rm -rf "$OUT/pkg/src"
cp -R "$SRC" "$OUT/pkg/src"
cd "$OUT/pkg/src"
if [ ! -f configure ]; then
  sh .bootstrap > "$OUT/pkg/bootstrap.log" 2>&1 || { tail -25 "$OUT/pkg/bootstrap.log"; exit 1; }
fi
./configure --prefix="$OUT/pkg/prefix" \
  --disable-shared --enable-static --disable-documentation --disable-openssl \
  > "$OUT/pkg/configure.log" 2>&1 || { tail -25 "$OUT/pkg/configure.log"; exit 1; }
make -j"$(nproc)" > "$OUT/pkg/build.log" 2>&1 || { tail -25 "$OUT/pkg/build.log"; exit 1; }
make install > "$OUT/pkg/install.log" 2>&1 || { tail -10 "$OUT/pkg/install.log"; exit 1; }
mkdir -p "$OUT/tools"
cp tools/nettle-hash tools/nettle-lfib-stream "$OUT/tools/"
