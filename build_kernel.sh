#!/bin/bash

export ARCH=arm64

# ---- User Config ----
PROJECT_VERSION="0.1-exp"
DEVICE="a52sxq"
VARIENT="vanilla"
# ---------------------

# ---- Domyślne katalogi (jeśli nie ustawione w środowisku) ----
if [ -z "$EXPORT_DIR" ]; then
    EXPORT_DIR="$(pwd)/export"
fi
if [ -z "$ANYKERNEL_DIR" ]; then
    ANYKERNEL_DIR=""
fi
# -------------------------------------------------------------

DATE="$(date +"%Y-%m-%d_%H-%M-%S")"
IMAGE_SOURCE="./arch/arm64/boot/Image"
FINAL_IMAGE="$EXPORT_DIR/Image"
ZIP_NAME="WonderfulKernel-${DEVICE}-${PROJECT_VERSION}-${DATE}.zip"

# ---- Environment ----
export LC_ALL=C
export BUILD_CROSS_COMPILE=$(pwd)/toolchain/google/bin/aarch64-linux-android-
export KERNEL_LLVM_BIN=$(pwd)/toolchain/clang-12.0.7/bin/clang
export CLANG_TRIPLE=aarch64-linux-gnu-
export KERNEL_MAKE_ENV="DTC_EXT=$(pwd)/tools/dtc CONFIG_BUILD_ARM64_DT_OVERLAY=y WERROR=0 CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=y CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y"
export OUT_DIR=$(pwd)/out
export CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=y

export LOCALVERSION="-Wonderful-${PROJECT_VERSION}-${VARIENT}"
export KBUILD_BUILD_USER="$(whoami)"
export KBUILD_BUILD_HOST="angel"
export DEVICE="a52sxq"

echo ""
echo "===== Building Wonderful Kernel ====="
echo "Version: Wonderful-${PROJECT_VERSION}-${VARIENT}"
echo "======================================"
echo ""

# ---- Czyszczenie katalogu out/ (jeśli nie podano "noclean") ----
if [ "$1" == "clean" ]; then
    if [ -d "$OUT_DIR" ]; then
        make -C $(pwd) O=$OUT_DIR ARCH=arm64 clean
    fi
    echo "Cleaning is done."
    exit 0
fi

if [ "$1" != "noclean" ] && [ -d "$OUT_DIR" ]; then
    echo "Czyszczenie katalogu $OUT_DIR ..."
    rm -rf "$OUT_DIR"
fi

# ---- Menuconfig ----
if [ "$1" == "menuconfig" ]; then
    mkdir -p $OUT_DIR

    if [ ! -f "$OUT_DIR/.config" ]; then
        make -C $(pwd) O=$OUT_DIR $KERNEL_MAKE_ENV ARCH=arm64 CROSS_COMPILE=$BUILD_CROSS_COMPILE REAL_CC=$KERNEL_LLVM_BIN CLANG_TRIPLE=$CLANG_TRIPLE vendor/a52sxq_eur_open_defconfig
    fi

    make -C $(pwd) O=$OUT_DIR ARCH=arm64 menuconfig
    exit 0
fi

# ---- Właściwa kompilacja ----
make -j64 -C $(pwd) O=$OUT_DIR $KERNEL_MAKE_ENV ARCH=arm64 CROSS_COMPILE=$BUILD_CROSS_COMPILE REAL_CC=$KERNEL_LLVM_BIN CLANG_TRIPLE=$CLANG_TRIPLE LOCALVERSION="$LOCALVERSION" CONFIG_SECTION_MISMATCH_WARN_ONLY=y vendor/a52sxq_eur_open_defconfig 2>&1 | tee build.log
make -j64 -C $(pwd) O=$OUT_DIR $KERNEL_MAKE_ENV ARCH=arm64 CROSS_COMPILE=$BUILD_CROSS_COMPILE REAL_CC=$KERNEL_LLVM_BIN CLANG_TRIPLE=$CLANG_TRIPLE LOCALVERSION="$LOCALVERSION" CONFIG_SECTION_MISMATCH_WARN_ONLY=y 2>&1 | tee -a build.log

# ---- Skopiowanie obrazu do standardowej lokalizacji ----
cp out/arch/arm64/boot/Image arch/arm64/boot/Image 2>/dev/null

# ---- Sprawdzenie, czy obraz istnieje ----
if [[ ! -f "$IMAGE_SOURCE" ]]; then
    echo "Image not found. Build failed."
    exit 1
fi

# ---- Eksport do katalogu EXPORT_DIR ----
mkdir -p "$EXPORT_DIR"
cp "$IMAGE_SOURCE" "$FINAL_IMAGE"

# ---- Pakowanie AnyKernel3 (jeśli ścieżka istnieje) ----
if [[ -n "$ANYKERNEL_DIR" && -d "$ANYKERNEL_DIR" ]]; then
    cp "$IMAGE_SOURCE" "$ANYKERNEL_DIR/Image"
    cd "$ANYKERNEL_DIR"
    zip -r9 "$EXPORT_DIR/$ZIP_NAME" * -x "*.git*" "*.zip" > /dev/null
    cd - > /dev/null
fi

echo ""
echo "Build successful!"
echo "Exported to:"
echo "$FINAL_IMAGE"
if [[ -f "$EXPORT_DIR/$ZIP_NAME" ]]; then
    echo "Flashable zip:"
    echo "$EXPORT_DIR/$ZIP_NAME"
fi
echo ""
echo "Done."