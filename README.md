# Crave Build Scripts for Realme Atoll (SM7125)

Collection of automated Crave.io build scripts for compiling custom ROMs and recoveries for Realme Atoll devices (Realme 6 Pro, 7 Pro, and 8 Pro).

Every script includes built-in post-build automation:
- **SourceForge Direct Upload**: Uploads build artifacts directly to SourceForge via `rsync` over SSH using devspace SSH key (`export SF_UPLOAD=true`) or Base64 key (`export SF_KEY='...'`).
- **Direct Download Link (Gofile Fallback)**: When SourceForge upload is skipped or fails, artifacts are automatically uploaded to `Gofile.io` for high-speed direct download links printed in the build console (with Filebin secondary fallback).
- **Stock Workspace Integration**: All scripts run within Crave's stock cached workspace (`/tmp/src/android`), fully utilizing Crave's fast resync and prebuilt dependencies without redundant downloads.
- **Centralized Configuration**: Every script has a dedicated top-level `CONFIGURATION` block for URLs, branches, lunch targets, and upload paths. The script body is 100% parameter-driven.

---

## 🔑 SourceForge Direct Upload Setup (Optional)

If you wish to upload compiled builds directly to SourceForge upon completion:

### 1. Add your SSH Public Key to SourceForge
- Go to [SourceForge SSH Settings](https://sourceforge.net/account/user-permissions).
- Paste your SSH public key (`~/.ssh/crave_sf.pub`, `~/.ssh/id_ed25519.pub`, or `~/.ssh/id_rsa.pub`) on a new line and click **Save**.

### 2. Choose Authentication Method

#### Method A: Devspace SSH Key (Recommended - Safe, zero credentials in logs)
Push your local SourceForge SSH key (`~/.ssh/crave_sf`) to devspace persistent storage (`/tmp/crave_sf`) once:
```bash
# Push key to persistent android storage on devspace (or use Crave Web Control Center / crave_menu.sh):
crave push -d /tmp/src/android/ ~/.ssh/crave_sf
```
Then trigger your build with `export SF_UPLOAD=true`:
```bash
crave run --no-patch -- "export SF_UPLOAD=true; curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/<script>.sh | bash"
```
During build, the upload script checks `/tmp/crave_sf` directly. The key remains preserved before, during, and after builds.

#### Method B: Base64 Key via CLI (Legacy / Alternative)
Encode your private key to Base64:
- **Linux**: `SF_KEY=$(base64 -w0 ~/.ssh/crave_sf)`
- **macOS**: `SF_KEY=$(base64 -i ~/.ssh/crave_sf | tr -d '\n')`

Then pass `export SF_KEY='...'`:
```bash
crave run --no-patch -- "export SF_KEY='<base64_encoded_key>'; curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/<script>.sh | bash"
```

> **Note:** If neither `SF_UPLOAD=true` nor `SF_KEY` is provided, or if SourceForge upload fails, the script automatically falls back to `Gofile.io` for high-speed download links.

---

## 1. Multi-Target Batch Scripts

### Build All Evolution X ROMs (`evolution_all.sh`)
Sequentially builds Evolution X for Realme 7 Pro (`RMX2170`), Realme 6 Pro (`RMX2061`), and Realme 8 Pro (`RMX3081`) in a single Crave run. The script continues building subsequent devices even if one fails and provides a consolidated summary report at the end. Each device artifact is uploaded immediately upon completion:

```bash
# Standard Build:
crave run --no-patch -- "curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/evolution_all.sh | bash"

# With SourceForge Upload (Devspace Key):
crave run --no-patch -- "export SF_UPLOAD=true; curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/evolution_all.sh | bash"

# With SourceForge Upload (Base64 Key):
crave run --no-patch -- "export SF_KEY='<base64_key>'; curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/evolution_all.sh | bash"
```

### Build All LineageOS ROMs (`lineage_all.sh`)
Sequentially builds LineageOS for Realme 7 Pro (`RMX2170`), Realme 6 Pro (`RMX2061`), and Realme 8 Pro (`RMX3081`):

```bash
# Standard Build:
crave run --no-patch -- "curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/lineage_all.sh | bash"

# With SourceForge Upload:
crave run --no-patch -- "export SF_UPLOAD=true; curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/lineage_all.sh | bash"
```

### Build All Lunaris ROMs (`lunaris_all.sh`)
Sequentially builds Lunaris for Realme 7 Pro (`RMX2170`), Realme 6 Pro (`RMX2061`), and Realme 8 Pro (`RMX3081`):

```bash
# Standard Build:
crave run --no-patch -- "curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/lunaris_all.sh | bash"

# With SourceForge Upload:
crave run --no-patch -- "export SF_UPLOAD=true; curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/lunaris_all.sh | bash"
```

### Build All Recoveries (`recovery_all.sh`)
Sequentially builds both OrangeFox and TWRP recoveries for unified `sm7125` directly in `/tmp/src/android` in a single Crave run with failure resilience and instant artifact upload:

```bash
# Standard Build:
crave run --no-patch -- "curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/recovery_all.sh | bash"

# With SourceForge Upload:
crave run --no-patch -- "export SF_UPLOAD=true; curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/recovery_all.sh | bash"
```

---

## 2. Standalone ROM Scripts

Each ROM has dedicated standalone scripts for each device:
- **Evolution X**: `evolution_rmx2170.sh`, `evolution_rmx2061.sh`, `evolution_rmx3081.sh`
- **LineageOS**: `lineage_rmx2170.sh`, `lineage_rmx2061.sh`, `lineage_rmx3081.sh`
- **Lunaris**: `lunaris_rmx2170.sh`, `lunaris_rmx2061.sh`, `lunaris_rmx3081.sh`

### Examples

#### Realme 7 Pro (`RMX2170`)
```bash
# LineageOS:
crave run --no-patch -- "curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/lineage_rmx2170.sh | bash"

# Lunaris:
crave run --no-patch -- "curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/lunaris_rmx2170.sh | bash"

# Evolution X with SourceForge Upload:
crave run --no-patch -- "export SF_UPLOAD=true; curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/evolution_rmx2170.sh | bash"
```

#### Realme 6 Pro (`RMX2061`)
```bash
# Standard Build:
crave run --no-patch -- "curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/evolution_rmx2061.sh | bash"

# With SourceForge Upload:
crave run --no-patch -- "export SF_UPLOAD=true; curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/evolution_rmx2061.sh | bash"
```

#### Realme 8 Pro (`RMX3081`)
```bash
# Standard Build:
crave run --no-patch -- "curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/evolution_rmx3081.sh | bash"

# With SourceForge Upload:
crave run --no-patch -- "export SF_UPLOAD=true; curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/evolution_rmx3081.sh | bash"
```

#### Custom Build Variant (Optional):
To compile a variant other than the default `userdebug` (e.g. `user` or `eng`), pass `BUILD_VARIANT`:
```bash
crave run --no-patch -- "export BUILD_VARIANT=user; curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/evolution_rmx2170.sh | bash"
```

---

## 3. Standalone Recovery Scripts

### OrangeFox Recovery (Unified `sm7125`)
```bash
# Standard Build:
crave run --no-patch -- "curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/ofrp_sm7125.sh | bash"

# With SourceForge Upload:
crave run --no-patch -- "export SF_UPLOAD=true; curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/ofrp_sm7125.sh | bash"
```

### TeamWin Recovery Project - TWRP (Unified `sm7125`)
```bash
# Standard Build:
crave run --no-patch -- "curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/twrp_sm7125.sh | bash"

# With SourceForge Upload:
crave run --no-patch -- "export SF_UPLOAD=true; curl -sLf https://raw.githubusercontent.com/realme-atoll/crave_script/<branch>/twrp_sm7125.sh | bash"
```

---

## 4. Maintenance & Modular Cloud Helpers

- `upload.py`: Modular Python artifact uploader supporting SourceForge direct upload with automatic `Gofile.io` fallback when SourceForge upload is skipped or fails. Auto-detects and uploads artifacts (`.zip`, `.img`) and build-generated companion files (MD5 `.md5sum`/`.md5`, SHA256 `.sha256sum`/`.sha256`, `.json` OTA metadata, and changelog `.txt` files), skipping any that were not generated.
- `clean.py`: Resets modified repositories and removes dirty build patches before repo sync.
- `patch.py`: Applies upstream bugfixes and local manifest patches after repo sync.
