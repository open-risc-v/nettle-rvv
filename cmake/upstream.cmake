# 上游接入：nettle（autotools）。两侧各从自己的 SRC_DIR 编一份上游，
# CLI 工具落到 <build>/tools/，用例按 $BIN/tools/nettle-hash 调用。
if(NOT DEFINED PKG_PREFIX)
  add_custom_target(pkg ALL
    COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/cmake/pkg-build.sh" "${SRC_DIR}" "${CMAKE_BINARY_DIR}"
    COMMENT "构建上游 nettle（${SRC_DIR}）"
    VERBATIM)
  set(HAVE_PKG_TARGET TRUE)
endif()
