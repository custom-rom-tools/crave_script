#!/bin/bash
# =============================================================================
# Multi-Recovery Batch Build - Realme Atoll (sm7125)
# Recoveries: OrangeFox Recovery Project & TeamWin Recovery Project (TWRP)
#
# Examples:
#   Standard Build:
#     crave run --no-patch -- "curl -sLf https://raw.githubusercontent.com/custom-rom-tools/crave_script/<branch>/recovery_all.sh | bash"
#   With SourceForge Upload (Devspace Key):
#     crave run --no-patch -- "export SF_UPLOAD=true; curl -sLf https://raw.githubusercontent.com/custom-rom-tools/crave_script/<branch>/recovery_all.sh | bash"
#   With SourceForge Upload (Base64 SF_KEY):
#     crave run --no-patch -- "export SF_KEY='<b64_key>'; curl -sLf https://raw.githubusercontent.com/custom-rom-tools/crave_script/<branch>/recovery_all.sh | bash"
# =============================================================================

# Note: set -e is deliberately omitted so a failure on one recovery does not abort the other

# =============================================================================
# CONFIGURATION
# =============================================================================

DEVICE="${1:-${DEVICE:-sm7125}}"
BUILD_TARGET="recoveryimage"
BUILD_VARIANT="${BUILD_VARIANT:-eng}"
LUNCH_TARGET="twrp_${DEVICE}-${BUILD_VARIANT}"

# Base Manifests
OFRP_BASE_MANIFEST_URL="https://gitlab.com/OrangeFox/Manifest.git"
OFRP_BASE_MANIFEST_BRANCH="fox_16.0"

TWRP_BASE_MANIFEST_URL="https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git"
TWRP_BASE_MANIFEST_BRANCH="twrp-12.1"

# Shared Recovery Manifest (local_manifests containing device trees)
RECOVERY_MANIFEST_URL="https://github.com/realme-atoll/recovery-manifest"
OFRP_DEVICE_BRANCH="ofrp"
TWRP_DEVICE_BRANCH="twrp"

# Workspace & Cloud Upload
WORK_DIR="/tmp/src/android"
UPLOAD_SUBDIR_BASE="Recovery/${DEVICE}"

# Helper Scripts URLs
SCRIPT_BRANCH="${SCRIPT_BRANCH:-recovery}"
UPLOAD_SCRIPT_URL="https://raw.githubusercontent.com/custom-rom-tools/crave_script/${SCRIPT_BRANCH}/upload.py"

# =============================================================================
# SCRIPT LOGIC
# =============================================================================

SUCCESS_BUILDS=()
FAILED_BUILDS=()

# Setup workspace
if [ -d "$WORK_DIR" ]; then
    cd "$WORK_DIR"
else
    WORK_DIR="$(pwd)"
fi

echo "============================================================"
echo " Starting Multi-Recovery Batch Build for Realme Atoll ($DEVICE)"
echo " Recoveries: OrangeFox & TWRP"
echo " Workspace: $WORK_DIR"
echo "============================================================"

# Helper: Ensure Qualcomm recovery dependencies are present
ensure_qcom_dependencies() {
    echo ">> Checking Qualcomm common recovery dependencies..."
    if [ ! -d "device/qcom/common" ]; then
        echo ">> Cloning device/qcom/common (android-12.1)..."
        git clone --depth=1 https://github.com/TeamWin/android_device_qcom_common.git -b android-12.1 device/qcom/common
    fi
    if [ ! -d "device/qcom/twrp-common" ]; then
        echo ">> Cloning device/qcom/twrp-common (android-12.1)..."
        git clone --depth=1 https://github.com/TeamWin/android_device_qcom_twrp-common.git -b android-12.1 device/qcom/twrp-common
    fi
}

# -----------------------------------------------------------------------------
# 1. OrangeFox Recovery Build (Step 1/2)
# -----------------------------------------------------------------------------
build_orangefox() {
    echo ""
    echo "============================================================"
    echo " [Step 1/2] [Recovery 1/2: OrangeFox] Starting Build (${DEVICE})..."
    echo "============================================================"
    cd "$WORK_DIR"

    # Clean intermediate files to conserve disk space
    rm -rf out/target/product/* out/soong
    rm -rf .repo/local_manifests device/realme/sm7125 device/realme/"${DEVICE}" .repo/projects/device/realme/sm7125.git .repo/projects/device/realme/"${DEVICE}".git

    # Substep 1/5: Initialize official OrangeFox manifest
    echo ""
    echo "------------------------------------------------------------"
    echo " [OrangeFox] Step 1/5: Initializing OrangeFox manifest ($OFRP_BASE_MANIFEST_BRANCH)..."
    echo "------------------------------------------------------------"
    repo init -u "$OFRP_BASE_MANIFEST_URL" -b "$OFRP_BASE_MANIFEST_BRANCH"

    # Substep 2/5: Setup device manifest and sync source
    echo ""
    echo "------------------------------------------------------------"
    echo " [OrangeFox] Step 2/5: Setting up device manifest & syncing source..."
    echo "------------------------------------------------------------"
    if ! git clone -b "$OFRP_DEVICE_BRANCH" "$RECOVERY_MANIFEST_URL" .repo/local_manifests; then
        echo ">>> [FAILED] OrangeFox local manifest clone failed!"
        FAILED_BUILDS+=("OrangeFox [manifest clone failed]")
        return 1
    fi

    /opt/crave/resync.sh
    ensure_qcom_dependencies

    # Substep 3/5: Setup environment & lunch
    echo ""
    echo "------------------------------------------------------------"
    echo " [OrangeFox] Step 3/5: Setting up environment & lunching $LUNCH_TARGET..."
    echo "------------------------------------------------------------"
    export ALLOW_MISSING_DEPENDENCIES=true
    export FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1
    export LC_ALL="C.UTF-8"

    source build/envsetup.sh
    if [ -f "device/realme/${DEVICE}/vendorsetup.sh" ]; then
        source "device/realme/${DEVICE}/vendorsetup.sh"
    elif [ -f "device/realme/sm7125/vendorsetup.sh" ]; then
        source "device/realme/sm7125/vendorsetup.sh"
    fi

    if lunch "$LUNCH_TARGET"; then
        # Substep 4/5: Compile recovery
        echo ""
        echo "------------------------------------------------------------"
        echo " [OrangeFox] Step 4/5: Compiling recovery image ($BUILD_TARGET)..."
        echo "------------------------------------------------------------"
        if m "$BUILD_TARGET"; then
            echo ">>> [SUCCESS] OrangeFox Recovery build succeeded!"
            SUCCESS_BUILDS+=("OrangeFox")

            # Substep 5/5: Upload official artifacts (check for existing branded names first)
            echo ""
            echo "------------------------------------------------------------"
            echo " [OrangeFox] Step 5/5: Uploading recovery artifacts..."
            echo "------------------------------------------------------------"
            local out_dir="${WORK_DIR}/out/target/product/${DEVICE}"
            local BUILD_DATE=$(date +%Y%m%d)

            # Only rename generic recovery.img if build didn't already produce a branded image
            if [ -f "$out_dir/recovery.img" ]; then
                local existing_img=$(find "$out_dir" -maxdepth 1 -name "OrangeFox*.img" | head -n 1)
                if [ -z "$existing_img" ]; then
                    mv -v "$out_dir/recovery.img" "$out_dir/OrangeFox-R12.0-${BUILD_DATE}-Unofficial-${DEVICE}.img"
                fi
            fi

            # Only rename generic recovery.zip if build didn't already produce an OrangeFox zip
            if [ -f "$out_dir/recovery.zip" ]; then
                local existing_zip=$(find "$out_dir" -maxdepth 1 -name "OrangeFox*.zip" | head -n 1)
                if [ -z "$existing_zip" ]; then
                    mv -v "$out_dir/recovery.zip" "$out_dir/OrangeFox-R12.0-${BUILD_DATE}-Unofficial-${DEVICE}.zip"
                fi
            fi

            local UPLOAD_SUBDIR="${UPLOAD_SUBDIR_BASE}/OrangeFox"
            curl -sLf "$UPLOAD_SCRIPT_URL" | python3 - "${UPLOAD_SUBDIR}" "${DEVICE}" "recovery"
        else
            echo ">>> [FAILED] OrangeFox Recovery compilation failed!"
            FAILED_BUILDS+=("OrangeFox [compilation failed]")
        fi
    else
        echo ">>> [FAILED] OrangeFox lunch failed!"
        FAILED_BUILDS+=("OrangeFox [lunch failed]")
    fi
}

# -----------------------------------------------------------------------------
# 2. TWRP Recovery Build (Step 2/2)
# -----------------------------------------------------------------------------
build_twrp() {
    echo ""
    echo "============================================================"
    echo " [Step 2/2] [Recovery 2/2: TWRP] Starting Build (${DEVICE})..."
    echo "============================================================"
    cd "$WORK_DIR"

    # Clean intermediate files
    rm -rf out/target/product/* out/soong
    rm -rf .repo/local_manifests device/realme/sm7125 device/realme/"${DEVICE}" .repo/projects/device/realme/sm7125.git .repo/projects/device/realme/"${DEVICE}".git

    # Substep 1/5: Initialize TWRP minimal manifest
    echo ""
    echo "------------------------------------------------------------"
    echo " [TWRP] Step 1/5: Initializing TWRP base repo ($TWRP_BASE_MANIFEST_BRANCH)..."
    echo "------------------------------------------------------------"
    repo init -u "$TWRP_BASE_MANIFEST_URL" -b "$TWRP_BASE_MANIFEST_BRANCH"

    # Substep 2/5: Setup device manifest and sync source
    echo ""
    echo "------------------------------------------------------------"
    echo " [TWRP] Step 2/5: Setting up device manifest & syncing source..."
    echo "------------------------------------------------------------"
    if ! git clone -b "$TWRP_DEVICE_BRANCH" "$RECOVERY_MANIFEST_URL" .repo/local_manifests; then
        echo ">>> [FAILED] TWRP local manifest clone failed!"
        FAILED_BUILDS+=("TWRP [manifest clone failed]")
        return 1
    fi

    /opt/crave/resync.sh
    ensure_qcom_dependencies

    # Substep 3/5: Setup environment & lunch
    echo ""
    echo "------------------------------------------------------------"
    echo " [TWRP] Step 3/5: Setting up environment & lunching $LUNCH_TARGET..."
    echo "------------------------------------------------------------"
    export ALLOW_MISSING_DEPENDENCIES=true
    export TW_DEVICE_VERSION="12.1"
    export LC_ALL="C.UTF-8"

    source build/envsetup.sh
    if [ -f "device/realme/${DEVICE}/vendorsetup.sh" ]; then
        source "device/realme/${DEVICE}/vendorsetup.sh"
    elif [ -f "device/realme/sm7125/vendorsetup.sh" ]; then
        source "device/realme/sm7125/vendorsetup.sh"
    fi

    if lunch "$LUNCH_TARGET"; then
        # Substep 4/5: Compile recovery
        echo ""
        echo "------------------------------------------------------------"
        echo " [TWRP] Step 4/5: Compiling recovery image ($BUILD_TARGET)..."
        echo "------------------------------------------------------------"
        if m "$BUILD_TARGET"; then
            echo ">>> [SUCCESS] TWRP Recovery build succeeded!"
            SUCCESS_BUILDS+=("TWRP")

            # Substep 5/5: Upload official artifacts (check for existing branded names first)
            echo ""
            echo "------------------------------------------------------------"
            echo " [TWRP] Step 5/5: Uploading recovery artifacts..."
            echo "------------------------------------------------------------"
            local out_dir="${WORK_DIR}/out/target/product/${DEVICE}"
            local BUILD_DATE=$(date +%Y%m%d)

            # Only rename generic recovery.img if build didn't already produce a branded image
            if [ -f "$out_dir/recovery.img" ]; then
                local existing_img=$(find "$out_dir" -maxdepth 1 -name "TWRP*.img" | head -n 1)
                if [ -z "$existing_img" ]; then
                    mv -v "$out_dir/recovery.img" "$out_dir/TWRP-3.7.1_${BUILD_DATE}-Unofficial-${DEVICE}.img"
                fi
            fi

            # Only rename generic recovery.zip if build didn't already produce a TWRP installer zip
            if [ -f "$out_dir/recovery.zip" ]; then
                local existing_zip=$(find "$out_dir" -maxdepth 1 -name "TWRP*.zip" | head -n 1)
                if [ -z "$existing_zip" ]; then
                    mv -v "$out_dir/recovery.zip" "$out_dir/TWRP-3.7.1_${BUILD_DATE}-Unofficial-${DEVICE}.zip"
                fi
            fi

            local UPLOAD_SUBDIR="${UPLOAD_SUBDIR_BASE}/TWRP"
            curl -sLf "$UPLOAD_SCRIPT_URL" | python3 - "${UPLOAD_SUBDIR}" "${DEVICE}" "recovery"
        else
            echo ">>> [FAILED] TWRP Recovery compilation failed!"
            FAILED_BUILDS+=("TWRP [compilation failed]")
        fi
    else
        echo ">>> [FAILED] TWRP lunch failed!"
        FAILED_BUILDS+=("TWRP [lunch failed]")
    fi
}

# Execute both recovery builds sequentially (Step 1/2 and Step 2/2)
build_orangefox
build_twrp

# Final Summary Report
echo ""
echo "============================================================"
echo "              RECOVERY BUILD SUMMARY REPORT                 "
echo "============================================================"
[ ${#SUCCESS_BUILDS[@]} -gt 0 ] && echo " Successful Builds: ${SUCCESS_BUILDS[*]}"
[ ${#FAILED_BUILDS[@]} -gt 0 ] && echo " Failed Builds:     ${FAILED_BUILDS[*]}"
echo "============================================================"

if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
    exit 1
fi
exit 0
