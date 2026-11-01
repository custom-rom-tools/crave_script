#!/bin/bash
# =============================================================================
# LineageOS (Android 16) - Multi-Device Batch Build
# Devices: Realme 7 Pro (RMX2170), Realme 6 Pro (RMX2061), Realme 8 Pro (RMX3081)
#
# Examples:
#   Standard Build:
#     crave run --no-patch -- "curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/lineage_all.sh | bash"
#   With SourceForge Upload (Devspace Key /tmp/crave_sf):
#     crave run --no-patch -- "export SF_UPLOAD=true; curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/lineage_all.sh | bash"
#   With SourceForge Upload (Base64 SF_KEY):
#     crave run --no-patch -- "export SF_KEY='<b64_key>'; curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/lineage_all.sh | bash"
# =============================================================================

# Note: set -e is deliberately omitted so a failure on one device does not abort remaining devices

# =============================================================================
# CONFIGURATION - MODIFY ONLY THIS SECTION
# =============================================================================

# ROM Source Repository
ROM_NAME="LineageOS"
ROM_MANIFEST_URL="https://github.com/LineageOS/android.git"
ROM_MANIFEST_BRANCH="lineage-23.2"

# Device Local Manifests (Configured independently per device)
RMX2170_MANIFEST_URL="https://github.com/realme-atoll/RMX2170-manifest"
RMX2170_MANIFEST_BRANCH="aosp-16"

RMX2061_MANIFEST_URL="https://github.com/realme-atoll/RMX2061-manifest"
RMX2061_MANIFEST_BRANCH="aosp-16"

RMX3081_MANIFEST_URL="https://github.com/realme-atoll/RMX3081-manifest"
RMX3081_MANIFEST_BRANCH="aosp-16"

# Build Settings
BUILD_VARIANT="${1:-${BUILD_VARIANT:-userdebug}}"
BUILD_TARGET="bacon"
WORK_DIR="/tmp/src/android"

# Cloud Upload Destination (Destination path: <DEVICE>/<UPLOAD_SUBDIR_SUFFIX>)
UPLOAD_SUBDIR_SUFFIX="LineageOS/16"

# Helper Scripts URLs
SCRIPT_BRANCH="${SCRIPT_BRANCH:-aosp-16}"
CLEAN_SCRIPT_URL="https://raw.githubusercontent.com/realme-atoll/crave_script/${SCRIPT_BRANCH}/clean.py"
PATCH_SCRIPT_URL="https://raw.githubusercontent.com/realme-atoll/crave_script/${SCRIPT_BRANCH}/patch.py"
UPLOAD_SCRIPT_URL="https://raw.githubusercontent.com/realme-atoll/crave_script/${SCRIPT_BRANCH}/upload.py"

# =============================================================================
# SCRIPT LOGIC - DO NOT MODIFY BELOW THIS LINE
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
echo " Starting $ROM_NAME Batch Build ($BUILD_VARIANT)"
echo " Workspace: $WORK_DIR"
echo "============================================================"

# 1. Initialize ROM repo (shared base)
echo ""
echo "=============================="
echo " [1/6] Initializing $ROM_NAME ($ROM_MANIFEST_BRANCH)..."
echo "=============================="
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs

# Helper: Build single device
build_device() {
    local DEVICE="$1"
    local manifest_url="$2"
    local manifest_branch="$3"
    local UPLOAD_SUBDIR="${DEVICE}/${UPLOAD_SUBDIR_SUFFIX}"

    echo ""
    echo "============================================================"
    echo ">>> Starting Build for $DEVICE ($BUILD_VARIANT)..."
    echo "============================================================"

    cd "$WORK_DIR"
    
    # 2. Setup device manifest
    echo ""
    echo "=============================="
    echo " [2/6] [$DEVICE] Setting up device manifest..."
    echo "=============================="
    rm -rf .repo/local_manifests
    if git clone -b "$manifest_branch" "$manifest_url" .repo/local_manifests; then
        
        # 3. Clean and sync source
        echo ""
        echo "=============================="
        echo " [3/6] [$DEVICE] Syncing source and applying patches..."
        echo "=============================="
        curl -sLf "$CLEAN_SCRIPT_URL" | python3
        /opt/crave/resync.sh
        curl -sLf "$PATCH_SCRIPT_URL" | python3

        # 4. Setup build environment and lunch
        echo ""
        echo "=============================="
        echo " [4/6] [$DEVICE] Setting up environment & lunching lineage_${DEVICE}-bp4a-${BUILD_VARIANT}..."
        echo "=============================="

        source build/envsetup.sh

        if lunch "lineage_${DEVICE}-bp4a-${BUILD_VARIANT}"; then
            # 5. Compile ROM
            echo ""
            echo "=============================="
            echo " [5/6] [$DEVICE] Building $ROM_NAME ($BUILD_TARGET)..."
            echo "=============================="
            if m "$BUILD_TARGET"; then
                echo " [$DEVICE] Build succeeded!"
                SUCCESS_BUILDS+=("$DEVICE")

                # 6. Upload build artifacts
                echo ""
                echo "=============================="
                echo " [6/6] [$DEVICE] Uploading build artifacts..."
                echo "=============================="
                curl -sLf "$UPLOAD_SCRIPT_URL" | python3 - "${UPLOAD_SUBDIR}" "${DEVICE}" "rom"
            else
                echo " [ERROR] Build failed for $DEVICE!"
                FAILED_BUILDS+=("$DEVICE")
            fi
        else
            echo " [ERROR] Lunch failed for $DEVICE!"
            FAILED_BUILDS+=("$DEVICE [lunch failed]")
        fi
    else
        echo " [ERROR] Failed to clone device manifest for $DEVICE!"
        FAILED_BUILDS+=("$DEVICE")
    fi
}

# Run sequential builds for each device
build_device "RMX2170" "$RMX2170_MANIFEST_URL" "$RMX2170_MANIFEST_BRANCH"
build_device "RMX2061" "$RMX2061_MANIFEST_URL" "$RMX2061_MANIFEST_BRANCH"
build_device "RMX3081" "$RMX3081_MANIFEST_URL" "$RMX3081_MANIFEST_BRANCH"

# Summary
echo ""
echo "============================================================"
echo " Batch Build Summary"
echo "============================================================"
echo "Successful Builds (${#SUCCESS_BUILDS[@]}): ${SUCCESS_BUILDS[*]:-None}"
echo "Failed Builds     (${#FAILED_BUILDS[@]}): ${FAILED_BUILDS[*]:-None}"
echo "============================================================"

# Exit with error only if all builds failed or any failed
if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
    echo "Notice: Some builds encountered failures."
    exit 1
fi

echo "All builds completed successfully!"
