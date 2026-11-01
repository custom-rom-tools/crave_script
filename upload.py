#!/usr/bin/env python3
"""
Crave Artifact Uploader (upload.py)
Uploads cooked ROM/recovery builds and companions (.md5sum, .sha256sum, .json, .txt)
to SourceForge, with temp.sh fallback when SourceForge upload is skipped or fails.

Usage:
  upload.py <remote_subdir> <device_or_path> [build_type] [extra_files...]
"""

import os
import sys
import re
import base64
import subprocess
from pathlib import Path

# SourceForge configuration
SF_PROJECT = "realme-atoll"
SF_USER = "nikhilpal2705"
SF_HOST = "frs.sourceforge.net"


def get_sf_key() -> Path | None:
    """
    Resolve SourceForge SSH private key:
    1. If SF_KEY is provided: decode base64 key and use it (takes precedence).
    2. Else if SF_UPLOAD is truthy: look for /tmp/crave_sf in devspace.
    3. Otherwise: skip SourceForge upload.
    """
    sf_key_b64 = os.environ.get("SF_KEY", "").strip()
    sf_upload = os.environ.get("SF_UPLOAD", "").strip().lower()

    # 1. User provided base64 SF_KEY -> decode and use it
    if sf_key_b64:
        key_file = Path("/tmp/sf_key")
        try:
            key_file.write_bytes(base64.b64decode(sf_key_b64))
            key_file.chmod(0o600)
            print(">>> [SF KEY] Using SF_KEY from environment")
            return key_file
        except Exception as e:
            print(f">>> [WARN] Failed to decode base64 SF_KEY: {e}")
            return None

    # 2. User passed SF_UPLOAD=true/1 -> check single folder location: /tmp/crave_sf
    if sf_upload in ("1", "true", "yes", "on"):
        devspace_key = Path("/tmp/crave_sf")
        if devspace_key.is_file() and devspace_key.stat().st_size > 0:
            try:
                devspace_key.chmod(0o600)
            except Exception:
                pass
            print(f">>> [SF KEY] Using devspace key: {devspace_key}")
            return devspace_key

        print(">>> [WARN] SF_UPLOAD is enabled, but crave_sf key was not found in devspace (/tmp/crave_sf). Skipping SourceForge.")
        return None

    # Neither provided
    return None


def get_build_sort_key(file_path: Path) -> tuple:
    """Sort key: 8-digit date (YYYYMMDD) then file modification time."""
    date_match = re.search(r'(20\d{6})', file_path.name)
    date_str = date_match.group(1) if date_match else "00000000"
    return (date_str, file_path.stat().st_mtime)


def find_companions(artifact: Path) -> list[Path]:
    """Find companion checksum/manifest/changelog files (.sha256sum, .md5sum, .json, .txt)."""
    companions: list[Path] = []
    parent, stem = artifact.parent, artifact.stem

    for cand in sorted(parent.iterdir()):
        if not cand.is_file() or cand.stat().st_size == 0 or cand == artifact:
            continue
        if not (cand.name.startswith(stem) or "changelog" in cand.name.lower()):
            continue

        match cand.suffix.lower():
            case ".sha256sum" | ".sha256" | ".md5sum" | ".md5" | ".json":
                if cand not in companions:
                    companions.append(cand)
            case ".txt" if "changelog" in cand.name.lower() or cand.stem == stem:
                if cand not in companions:
                    companions.append(cand)
            case _:
                pass

    return companions


def resolve_target_path(item: str) -> Path:
    """Resolves an input item to a Path, checking direct path or out/target/product."""
    p = Path(item)
    if p.exists():
        return p

    base = Path("out/target/product")
    for cand in [base / item, base / item.lower(), base / item.upper()]:
        if cand.is_dir():
            return cand

    return p


def is_rom_zip(p: Path) -> bool:
    """Validate whether a zip file is a cooked ROM installer (and not an OTA or intermediate package)."""
    name = p.name.lower()
    stem = p.stem.lower()
    # Exclude intermediate packaging / symbols / recovery packages
    if any(ign in name for ign in ["target_files", "target-files", "symbols", "orangefox", "twrp"]):
        return False
    # Exclude OTA update packages (e.g. *-ota.zip, *_ota.zip, ota_update.zip, ota.zip)
    if any(ota in stem for ota in ["-ota", "_ota", ".ota"]) or stem.endswith("ota") or stem.startswith("ota"):
        return False
    return True


def discover_candidates(search_dir: Path, build_type: str, remote_subdir: str = "") -> list[Path]:
    """Discovers target artifacts in product directory based on build type and optional flavor from remote_subdir."""
    candidates: list[Path] = []
    sub_lower = remote_subdir.lower()

    match build_type.lower():
        case "recovery":
            # 1. Recovery installer ZIPs if present (check immediate dir or device subdirs)
            all_zips = list(search_dir.glob("*.zip"))
            if not all_zips and search_dir.name == "product":
                all_zips = list(search_dir.glob("*/*.zip"))

            # Detect recovery flavor if specified in remote_subdir (e.g. OrangeFox vs TWRP)
            rec_flavor = ""
            if any(k in sub_lower for k in ["orangefox", "ofrp"]):
                rec_flavor = "orangefox"
            elif any(k in sub_lower for k in ["twrp"]):
                rec_flavor = "twrp"

            zips = [
                z for z in all_zips
                if any(k in z.name.lower() for k in ["orangefox", "twrp", "recovery"])
                and not any(ign in z.name.lower() for ign in ["target_files", "target-files", "symbols", "ota_update"])
            ]
            if rec_flavor:
                flavored_zips = [z for z in zips if rec_flavor in z.name.lower()]
                if flavored_zips:
                    zips = flavored_zips

            if zips:
                zips.sort(key=get_build_sort_key, reverse=True)
                candidates.append(zips[0])

            # 2. Recovery images
            all_imgs = list(search_dir.glob("*.img"))
            if not all_imgs and search_dir.name == "product":
                all_imgs = list(search_dir.glob("*/*.img"))
            imgs = [
                i for i in all_imgs
                if any(k in i.name.lower() for k in ["orangefox", "twrp", "recovery"])
            ]
            if rec_flavor:
                flavored_imgs = [i for i in imgs if rec_flavor in i.name.lower()]
                if flavored_imgs:
                    imgs = flavored_imgs

            if imgs:
                branded = [i for i in imgs if any(k in i.name.lower() for k in ["orangefox", "twrp"])]
                chosen_imgs = branded if branded else imgs
                chosen_imgs.sort(key=lambda x: x.stat().st_mtime, reverse=True)
                candidates.append(chosen_imgs[0])

        case "rom" | _:
            # Latest cooked ROM ZIP (exclude standalone recovery zips, OTA updates, and target_files)
            all_zips = list(search_dir.glob("*.zip"))
            if not all_zips and search_dir.name == "product":
                all_zips = list(search_dir.glob("*/*.zip"))
            zips = [
                z for z in all_zips
                if is_rom_zip(z)
            ]

            # Detect ROM distribution if specified in remote_subdir (e.g. EvolutionX, LineageOS, Lunaris)
            rom_flavor = ""
            for r in ["evolution", "lineage", "lunaris"]:
                if r in sub_lower:
                    rom_flavor = r
                    break
            if rom_flavor:
                flavored_zips = [z for z in zips if rom_flavor in z.name.lower()]
                if flavored_zips:
                    zips = flavored_zips

            if zips:
                # Sort by 8-digit date in filename and filesystem modification time (newest first)
                zips.sort(key=get_build_sort_key, reverse=True)
                candidates.append(zips[0])

    return candidates


def resolve_artifacts(raw_inputs: list[str], build_type: str = "rom", remote_subdir: str = "") -> list[Path]:
    """Resolves cooked artifacts and companions from device names, directories, or direct file paths."""
    targets: list[Path] = []

    for item in raw_inputs:
        if not item:
            continue

        p = resolve_target_path(item)

        if p.is_dir():
            for cand in discover_candidates(p, build_type, remote_subdir=remote_subdir):
                if cand not in targets:
                    targets.append(cand)
                    for comp in find_companions(cand):
                        if comp not in targets:
                            targets.append(comp)
            continue

        if not p.is_file() or p.stat().st_size == 0 or p in targets:
            continue

        targets.append(p)
        for comp in find_companions(p):
            if comp not in targets:
                targets.append(comp)

    return targets


def upload_sf(files: list[Path], remote_subdir: str, key_file: Path | None) -> bool:
    """Uploads artifacts to SourceForge via rsync over SSH. Returns True if successful, False if skipped or failed."""
    if not key_file:
        print(">>> [INFO] SourceForge SSH key not available. Skipping SourceForge upload.")
        return False

    dest = f"/home/frs/project/{SF_PROJECT}/{remote_subdir.strip('/')}/"
    print(f">>> [SF UPLOAD] Uploading to {dest}...")

    try:
        # Ensure remote directory exists on SourceForge via SFTP
        dirs = remote_subdir.strip("/").split("/")
        curr = f"/home/frs/project/{SF_PROJECT}"
        sftp_cmds = "\n".join([f"mkdir {curr}/{'/'.join(dirs[:i+1])}" for i in range(len(dirs))]) + "\n"
        subprocess.run(
            ["sftp", "-i", str(key_file), "-o", "StrictHostKeyChecking=no", f"{SF_USER}@{SF_HOST}"],
            input=sftp_cmds,
            text=True,
            capture_output=True,
            timeout=30,
        )

        # Cache host key
        subprocess.run(["ssh-keyscan", "-H", SF_HOST], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)

        # Rsync transfer
        cmd = [
            "rsync", "-avP",
            "-e", f"ssh -i {key_file} -o StrictHostKeyChecking=no",
            *[str(f) for f in files],
            f"{SF_USER}@{SF_HOST}:{dest}",
        ]
        res = subprocess.run(cmd)
        if res.returncode == 0:
            print(">>> [SF UPLOAD] Upload to SourceForge completed successfully!")
            return True
        else:
            print(f">>> [WARN] SourceForge rsync failed with exit code {res.returncode}.")
            return False
    except Exception as e:
        print(f">>> [WARN] SourceForge upload encountered an error: {e}")
        return False


def upload_temp(files: list[Path]):
    """Uploads artifacts for instant direct download link via temp.sh."""
    print("\nGenerating direct download links via temp.sh...")
    for f in files:
        size_mb = f.stat().st_size / (1024 * 1024)
        print(f">>> [TEMP.SH] Uploading {f.name} ({size_mb:.2f} MB) to temp.sh...")
        link = None

        # Attempt upload up to 2 times
        for attempt in range(1, 3):
            try:
                res = subprocess.run(
                    ["curl", "-s", "-w", "\n%{http_code}", "-F", f"file=@{f}", "https://temp.sh/upload"],
                    capture_output=True,
                    text=True,
                    timeout=900,
                )
                parts = res.stdout.strip().split("\n")
                body = parts[0].strip() if parts else ""
                status = parts[-1].strip() if len(parts) > 1 else ""
                if status == "200" and body.startswith("http") and "<html" not in body.lower():
                    link = body
                    print(f"Direct link ({f.name}) [temp.sh]: {link}")
                    break
            except Exception as e:
                if attempt == 2:
                    print(f">>> [WARN] temp.sh upload exception for {f.name}: {e}")

        if not link:
            print(f">>> [WARN] Direct download link generation failed for {f.name} (temp.sh upload failed).")


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <remote_subdir> <device_or_path> [build_type] [extra_files...]")
        sys.exit(1)

    remote_subdir = sys.argv[1].strip("/")
    target_arg = sys.argv[2]

    # Optional explicit build_type ('rom' or 'recovery')
    explicit_type = ""
    extra_start = 3
    if len(sys.argv) > 3 and sys.argv[3].lower() in ["rom", "recovery"]:
        explicit_type = sys.argv[3].lower()
        extra_start = 4

    build_type = explicit_type or ("recovery" if any(k in remote_subdir.lower() for k in ["recovery", "twrp", "orangefox", "ofrp"]) else "rom")
    raw_inputs = [target_arg] + sys.argv[extra_start:]

    files = resolve_artifacts(raw_inputs, build_type=build_type, remote_subdir=remote_subdir)
    if not files:
        print(f">>> [ERROR] No valid build artifacts found for target '{target_arg}' (build_type: {build_type}).")
        sys.exit(1)

    print(f"\nArtifacts to upload ({len(files)}):")
    for f in files:
        print(f" - {f.name} ({f.stat().st_size / (1024 * 1024):.2f} MB)")

    key_file = get_sf_key()
    sf_success = upload_sf(files, remote_subdir, key_file)
    if not sf_success:
        print("\n>>> SourceForge upload skipped or failed. Falling back to temp.sh...")
        upload_temp(files)

    print("\nUpload complete.")


if __name__ == "__main__":
    main()
