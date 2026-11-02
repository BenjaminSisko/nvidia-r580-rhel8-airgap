#!/usr/bin/env python3
"""Download or verify pinned, unmodified NVIDIA development artifacts.

This stages files only. It never installs packages, extracts archives, changes
the driver, or touches MATLAB's supplied libraries. Python 3.9+; standard library.
"""

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import urllib.parse
import urllib.request


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = ROOT / "docs" / "MATLAB-NVIDIA-ASSETS.json"
DEFAULT_OUTPUT = ROOT / "dist" / "matlab-nvidia-addons-20261102"
RESERVE_BYTES = 2 * 1024**3
CHUNK_BYTES = 8 * 1024**2


def load_manifest(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema_version") != 1 or not data.get("assets"):
        raise ValueError("unsupported or empty asset manifest")
    names = set()
    for asset in data["assets"]:
        name = asset["filename"]
        url = urllib.parse.urlsplit(asset["url"])
        if (not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.+-]*", name)
                or name in names):
            raise ValueError("unsafe or duplicate asset filename: " + name)
        names.add(name)
        if (url.scheme != "https" or url.netloc != "developer.download.nvidia.com"
                or url.query or url.fragment
                or Path(url.path).name != name
                or ".." in url.path.split("/")):
            raise ValueError("asset URL is not an approved NVIDIA HTTPS path")
        if (type(asset["size_bytes"]) is not int or asset["size_bytes"] <= 0
                or not re.fullmatch(r"[0-9a-f]{64}", asset["sha256"])):
            raise ValueError("invalid pinned size or SHA-256: " + name)
    return data


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(CHUNK_BYTES), b""):
            result.update(chunk)
    return result.hexdigest()


def verified(path, asset):
    if path.is_symlink():
        raise ValueError("refusing a symlink at " + str(path))
    if not path.exists():
        return False
    if not path.is_file():
        raise ValueError("asset destination is not a regular file: " + str(path))
    if path.stat().st_size != asset["size_bytes"] or digest(path) != asset["sha256"]:
        raise ValueError("existing file differs from vendor pin; preserved: " + str(path))
    return True


def safe_directory(path):
    # Reject symlinks even in existing parents, so output cannot silently escape
    # to an unrelated mounted or linked directory.
    absolute = path.absolute()
    for candidate in (absolute, *absolute.parents):
        if candidate.is_symlink():
            raise ValueError("output directory has a symlink component: " + str(candidate))
    absolute.mkdir(parents=True, exist_ok=True)
    return absolute


def fetch_asset(asset, directory):
    destination = directory / asset["filename"]
    if verified(destination, asset):
        print("Verified existing: " + asset["filename"], flush=True)
        return
    partial = destination.with_name(destination.name + ".part")
    if partial.exists() or partial.is_symlink():
        raise ValueError("partial file exists; inspect/remove it before retrying: " + str(partial))
    request = urllib.request.Request(asset["url"], headers={"User-Agent": "matlab-offline-stager/1.0"})
    total = 0
    hasher = hashlib.sha256()
    print("Downloading: " + asset["filename"], flush=True)
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            target = urllib.parse.urlsplit(response.geturl())
            if target.scheme != "https" or target.netloc != "developer.download.nvidia.com":
                raise ValueError("download redirected outside the approved NVIDIA HTTPS host")
            declared = response.headers.get("Content-Length")
            if declared is not None and int(declared) != asset["size_bytes"]:
                raise ValueError("server Content-Length differs from vendor manifest")
            with partial.open("xb") as stream:
                while True:
                    chunk = response.read(CHUNK_BYTES)
                    if not chunk:
                        break
                    total += len(chunk)
                    if total > asset["size_bytes"]:
                        raise ValueError("download exceeded pinned size")
                    if shutil.disk_usage(directory).free < RESERVE_BYTES + len(chunk):
                        raise ValueError("download stopped to preserve the 2 GiB free-space reserve")
                    stream.write(chunk)
                    hasher.update(chunk)
        if total != asset["size_bytes"] or hasher.hexdigest() != asset["sha256"]:
            raise ValueError("download did not match vendor size/SHA-256")
        # Never replace an existing final file, including one created while the
        # download was in progress. A hard link is atomic and fails on collision.
        os.link(partial, destination)
        partial.unlink()
        print("Verified download: " + asset["filename"], flush=True)
    except Exception:
        # Retain the incomplete bytes for diagnosis; never mark them complete.
        raise


def write_json(path, data):
    if path.is_symlink():
        raise ValueError("refusing a symlink receipt: " + str(path))
    temporary = path.with_name(path.name + ".tmp")
    with temporary.open("x", encoding="utf-8") as stream:
        json.dump(data, stream, indent=2)
        stream.write("\n")
    temporary.replace(path)


def run(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--profile", action="append", help="stage only this profile; may repeat")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--fetch", action="store_true", help="download and verify artifacts")
    mode.add_argument("--verify", action="store_true", help="verify offline without network access")
    args = parser.parse_args(argv)
    data = load_manifest(args.manifest)
    manifest_sha256 = digest(args.manifest)
    assets = data["assets"]
    if args.profile:
        known = {a["profile"] for a in assets}
        if not set(args.profile) <= known:
            raise ValueError("unknown profile; choose from: " + ", ".join(sorted(known)))
        assets = [a for a in assets if a["profile"] in args.profile]
    total = sum(a["size_bytes"] for a in assets)
    print("Pinned artifacts: {:,}; bytes: {:,}; profiles: {}".format(
        len(assets), total, ", ".join(sorted({a["profile"] for a in assets}))), flush=True)
    if not args.fetch and not args.verify:
        for asset in assets:
            print("{}  {:,}  {}".format(asset["filename"], asset["size_bytes"], asset["sha256"]))
        print("Plan only. Use --fetch or --verify; no installation is performed.")
        return 0
    output = safe_directory(args.output)
    directory = safe_directory(output / "payload")
    missing = [a for a in assets if not verified(directory / a["filename"], a)]
    if args.verify and missing:
        raise ValueError("missing artifacts: " + ", ".join(a["filename"] for a in missing))
    if args.fetch:
        needed = sum(a["size_bytes"] for a in missing)
        free = shutil.disk_usage(output).free
        if free < needed + RESERVE_BYTES:
            raise ValueError("need {:,} download bytes plus 2 GiB reserve; available {:,}".format(needed, free))
        for asset in assets:
            if shutil.disk_usage(output).free < asset["size_bytes"] + RESERVE_BYTES and asset in missing:
                raise ValueError("free space fell below the 2 GiB reserve")
            fetch_asset(asset, directory)
    for asset in assets:
        if not verified(directory / asset["filename"], asset):
            raise ValueError("verification failed: " + asset["filename"])
    stamp = datetime.datetime.now(datetime.timezone.utc).isoformat()
    receipt = {
        "verified_utc": stamp, "operation": "fetch" if args.fetch else "offline_verify",
        "status": "all_selected_vendor_artifacts_verified",
        "profiles": sorted({a["profile"] for a in assets}),
        "asset_count": len(assets), "total_bytes": total, "assets": assets,
        "manifest_sha256": manifest_sha256, "installed_on_target": False,
        "rhel_dependency_closure_verified": False, "matlab_execution_verified": False,
        "limitations": data.get("limitations", []),
    }
    write_json(output / "FETCH-RECEIPT.json", receipt)
    write_json(output / "ASSET-MANIFEST.json", data)
    checksums = output / "SHA256SUMS"
    if checksums.is_symlink():
        raise ValueError("refusing a symlink checksum file")
    checksums.write_text("".join(a["sha256"] + "  payload/" + a["filename"] + "\n" for a in assets))
    print("PASS: all selected artifacts match the pinned NVIDIA sizes and SHA-256 checksums.")
    print("Staged at: " + str(output))
    print("Target install, host dependencies and MATLAB workload acceptance remain unverified.")
    return 0


def main():
    try:
        return run()
    except (ValueError, OSError, KeyError) as exc:
        print("ERROR: " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
