#!/bin/bash
# =============================================================================
# LineageOS (Android 17) - Realme 7 Pro (RMX2170)
#
# Examples:
#   Standard Build:
#     crave run --no-patch -- "curl -sLf https://raw.githubusercontent.com/custom-rom-tools/crave_script/aosp-17/lineage_rmx2170.sh | bash"
#   With SourceForge Upload (Devspace Key /tmp/crave_sf):
#     crave run --no-patch -- "export SF_UPLOAD=true; curl -sLf https://raw.githubusercontent.com/custom-rom-tools/crave_script/aosp-17/lineage_rmx2170.sh | bash"
#   With SourceForge Upload (Base64 SF_KEY):
#     crave run --no-patch -- "export SF_KEY='<b64_key>'; curl -sLf https://raw.githubusercontent.com/custom-rom-tools/crave_script/aosp-17/lineage_rmx2170.sh | bash"
# =============================================================================

set -e

# =============================================================================
# CONFIGURATION - MODIFY ONLY THIS SECTION
# =============================================================================

# Device & ROM Settings
DEVICE="RMX2170"
ROM_NAME="LineageOS"
ROM_MANIFEST_URL="https://github.com/LineageOS/android.git"
ROM_MANIFEST_BRANCH="lineage-24.0"
DEVICE_MANIFEST_URL="https://github.com/realme-atoll/RMX2170-manifest"
DEVICE_MANIFEST_BRANCH="${DEVICE_MANIFEST_BRANCH:-aosp-16}"

# Build Settings
BUILD_VARIANT="${1:-${BUILD_VARIANT:-userdebug}}"
BUILD_TARGET="bacon"
LUNCH_TARGET="lineage_${DEVICE}-${BUILD_VARIANT}"
WORK_DIR="/tmp/src/android"

# Cloud Upload Destination
UPLOAD_SUBDIR="${DEVICE}/LineageOS/17"

# Helper Scripts URLs
SCRIPT_BRANCH="${SCRIPT_BRANCH:-aosp-17}"
CLEAN_SCRIPT_URL="https://raw.githubusercontent.com/custom-rom-tools/crave_script/${SCRIPT_BRANCH}/clean.py"
PATCH_SCRIPT_URL="https://raw.githubusercontent.com/custom-rom-tools/crave_script/${SCRIPT_BRANCH}/patch.py"
UPLOAD_SCRIPT_URL="https://raw.githubusercontent.com/custom-rom-tools/crave_script/${SCRIPT_BRANCH}/upload.py"

# =============================================================================
# SCRIPT LOGIC - DO NOT MODIFY BELOW THIS LINE
# =============================================================================

# Workspace Setup
[ -d "$WORK_DIR" ] && cd "$WORK_DIR"
echo "============================================================"
echo " Building $ROM_NAME for $DEVICE ($BUILD_VARIANT)"
echo " Working Directory: $(pwd)"
echo "============================================================"

# 1. Prepare workspace and environment
echo ""
echo "=============================="
echo " [1/7] Preparing workspace & environment..."
echo "=============================="

# Ensure ccache is installed in container if missing
if ! command -v ccache >/dev/null 2>&1; then
    echo "Installing ccache..."
    (sudo apt-get update && sudo apt-get install -y ccache) 2>/dev/null || true
fi

# Clean dead swapfile from previous runs if any to recover 16GB disk space
if [ -f "/swapfile" ]; then
    echo "Removing inactive /swapfile to recover container disk space..."
    sudo swapoff /swapfile 2>/dev/null || true
    sudo rm -f /swapfile 2>/dev/null || true
fi

# Clean stale build intermediates
rm -rf out/soong/.intermediates/system/sepolicy/recovery_sepolicy.* out/soong/.intermediates/system/sepolicy/vendor_sepolicy.* 2>/dev/null || true

# Memory and GC tuning to prevent soong_build OOM kills in container
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
export DONT_INSTALL_DEXPREOPT_TESTS=true
export GOGC=40
export GOMEMLIMIT=14GiB
export MALLOC_ARENA_MAX=2
export SOONG_GOGC=40
export SOONG_INCREMENTAL_ANALYSIS=false

# 2. Initialize ROM repo
echo ""
echo "=============================="
echo " [2/7] Initializing $ROM_NAME ($ROM_MANIFEST_BRANCH)..."
echo "=============================="
repo init -u https://github.com/LineageOS/android.git -b lineage-24.0 --git-lfs

# 3. Setup device manifest
echo ""
echo "=============================="
echo " [3/7] Setting up device manifest..."
echo "=============================="
rm -rf .repo/local_manifests
git clone -b "$DEVICE_MANIFEST_BRANCH" "$DEVICE_MANIFEST_URL" .repo/local_manifests

# 4. Clean and sync source
echo ""
echo "=============================="
echo " [4/7] Syncing source and applying patches..."
echo "=============================="
curl -sLf "$CLEAN_SCRIPT_URL" | python3
/opt/crave/resync.sh
curl -sLf "$PATCH_SCRIPT_URL" | python3

# 5. Setup build environment and lunch
echo ""
echo "=============================="
echo " [5/7] Setting up environment & lunching $LUNCH_TARGET..."
echo "=============================="

source build/envsetup.sh
lunch "$LUNCH_TARGET"

# 6. Compile ROM
echo ""
echo "=============================="
echo " [6/7] Building $ROM_NAME ($BUILD_TARGET)..."
echo "=============================="
m "$BUILD_TARGET"

# 7. Upload build artifacts
echo ""
echo "=============================="
echo " [7/7] Uploading build artifacts..."
echo "=============================="
curl -sLf "$UPLOAD_SCRIPT_URL" | python3 - "${UPLOAD_SUBDIR}" "${DEVICE}" "rom"

echo ""
echo "============================================================"
echo " Build process completed successfully!"
echo "============================================================"
