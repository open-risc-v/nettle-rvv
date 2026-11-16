#!/usr/bin/env bash
# nettle 真实包用例：哈希 + 确定性流。
#
# nettle 是 autotools 工程，不走 CMake。两侧（src / baseline）各做一次
# autoreconf + configure + make，产物在 <侧目录>/tools/ 下，由 RVV_A / RVV_B
# 通过 run_ab.sh 的 DEVICE_MODE 指进来。
#
# 输入用 awk 生成，确保两侧拿到逐字节相同的语料（不依赖任何随机源）。
set -euo pipefail

: "${STAGE:=run}" "${SIDE:=A}" "${BIN:=build/native}" "${DATA:=build/ab-data}" "${OUT:=build/ab-data/out}"
mkdir -p "$DATA" "$OUT"

case "$STAGE" in
  gen)
    # 1024 字节，内容 A..Z 循环；确定性，任何机器上都一样
    awk 'BEGIN{for(i=0;i<1024;i++) printf "%c", 65+(i%26)}' > "$DATA/input.bin"
    ;;

  run)
    H="$BIN/tools/nettle-hash"
    if [ ! -x "$H" ]; then
      echo "缺少 $H（nettle 未在该侧构建）" >&2
      exit 1
    fi

    # 覆盖不同内部结构：MD 风格(64B 块)、SHA512 风格(128B 块)、SHA3(海绵)、
    # 以及俄罗斯/国密标准，任何一个在 RVV 上算错都会在这里露出来
    : > "$OUT/hashes.txt"
    for a in md5 sha1 sha224 sha256 sha384 sha512 sha3_256 sha3_512 sm3 gosthash94 streebog256; do
      printf '%s ' "$a" >> "$OUT/hashes.txt"
      ${RUNNER:-} "$H" -a "$a" "$DATA/input.bin" >> "$OUT/hashes.txt"
    done

    # 确定性 LCG 流：验证纯算术路径不受向量化影响。
    # 注意：nettle-lfib-stream 不带出口，会一直写下去（本轮曾因此写出 17GB 文件、
    # 把宿主机磁盘写满），必须用 head 截断，并吞掉 SIGPIPE 造成的非零退出。
    ${RUNNER:-} "$BIN/tools/nettle-lfib-stream" 1000 2>/dev/null | head -c 2048 > "$OUT/lfib.txt" || true
    ;;
  *)
    echo "未知 STAGE=$STAGE" >&2; exit 2 ;;
esac
