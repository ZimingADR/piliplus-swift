#!/usr/bin/env python3
"""生成 / 更新 SideStore、AltStore 使用的 altstore.json 订阅源。

用法（在仓库根目录）：

    python3 scripts/update_altstore_source.py \
        --ipa build/PiliPlus-0.1.0-unsigned.ipa \
        --download-url https://github.com/ZimingADR/piliplus-swift/releases/download/v0.1.0/PiliPlus-0.1.0-unsigned.ipa \
        --version 0.1.0 \
        --build-version 1 \
        --repo ZimingADR/piliplus-swift

- 版本信息优先从 `--app-bundle` 指向的 .app/Info.plist 读取；
  本地没有归档产物时可直接用 `--version/--build-version` 指定。
- 新版本会插到 `versions` 头部并按 `--max-versions` 截断；
  同一 version + build 的旧记录会被替换。
- 输出为 UTF-8、LF、2 空格缩进，便于在 CI 中直接提交。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DEFAULT_REPO = "ZimingADR/piliplus-swift"
DEFAULT_BUNDLE_ID = "com.zimingadr.piliplus"
DEFAULT_APP_NAME = "PiliPlus"
DEFAULT_MIN_OS = "18.0"
ICON_PATH = "PiliPlus/Supporting/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"


def compute_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fp:
        for chunk in iter(lambda: fp.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().lower()


def load_info_plist(app_bundle: Path | None) -> dict[str, Any]:
    if app_bundle is None:
        return {}
    info_plist_path = app_bundle / "Info.plist"
    if not info_plist_path.is_file():
        raise FileNotFoundError(f"Info.plist not found at {info_plist_path}")
    with info_plist_path.open("rb") as fp:
        data = plistlib.load(fp)
    if not isinstance(data, dict):
        raise ValueError("Parsed Info.plist is not a dictionary")
    return data


def extract_privacy_permissions(info: dict[str, Any]) -> dict[str, str]:
    privacy: dict[str, str] = {}
    for key in sorted(info.keys()):
        if key.startswith("NS") and key.endswith("UsageDescription"):
            value = info.get(key)
            if isinstance(value, str) and value.strip():
                privacy[key] = value
    return privacy


def extract_entitlements(app_bundle: Path | None) -> list[str]:
    """读取代码签名里的权限；未签名产物返回空列表。"""
    if app_bundle is None or not app_bundle.is_dir():
        return []

    targets = [app_bundle]
    plug_ins = app_bundle / "PlugIns"
    if plug_ins.is_dir():
        targets.extend(sorted(plug_ins.glob("*.appex")))

    ignored_keys = {
        "application-identifier",
        "com.apple.developer.team-identifier",
        "get-task-allow",
        "keychain-access-groups",
    }

    entitlements: set[str] = set()
    for target in targets:
        try:
            proc = subprocess.run(
                ["codesign", "-d", "--entitlements", ":-", str(target)],
                capture_output=True,
                check=False,
            )
        except FileNotFoundError:
            break

        stdout = proc.stdout.strip()
        if proc.returncode != 0 or not stdout:
            continue
        xml_start = stdout.find(b"<?xml")
        if xml_start == -1:
            continue
        try:
            parsed = plistlib.loads(stdout[xml_start:])
        except Exception:
            continue
        if isinstance(parsed, dict):
            entitlements.update(
                str(key) for key in parsed.keys() if key not in ignored_keys
            )

    return sorted(entitlements)


def build_default_manifest(repo: str, bundle_id: str, app_name: str) -> dict[str, Any]:
    owner = repo.split("/")[0] if "/" in repo else "ZimingADR"
    owner_lower = owner.lower()
    raw_base = f"https://raw.githubusercontent.com/{repo}/main"
    icon_url = f"{raw_base}/{ICON_PATH}"

    return {
        "name": app_name,
        "subtitle": "纯 Swift 原生 B 站客户端 · Group 1",
        "description": (
            "PiliPlus 的 SwiftUI 原生重写版。Group 1 提供无需登录的推荐流、"
            "DASH 高清播放、BewlyCat 智能音量平衡、CoreAnimation 弹幕、"
            "搜索、画中画与断点续播。"
        ),
        "identifier": f"io.github.{owner_lower}.piliplus.source",
        "sourceURL": f"{raw_base}/altstore.json",
        "website": f"https://github.com/{repo}",
        "iconURL": icon_url,
        "tintColor": "#FB7299",
        "featuredApps": [bundle_id],
        "apps": [
            {
                "name": app_name,
                "bundleIdentifier": bundle_id,
                "developerName": owner,
                "subtitle": "纯 Swift 原生 B 站客户端",
                "localizedDescription": (
                    "使用 SwiftUI + Swift 6 + MPVKit 编写的第三方 BiliBili 客户端，"
                    "融合 BewlyCat 智能音量平衡（跨视频响度对齐 + 视频内动态平滑 + "
                    "-1.0 dBFS 峰值防爆音），支持推荐流、搜索、弹幕、后台播放、"
                    "画中画与断点续播。"
                ),
                "iconURL": icon_url,
                "tintColor": "#FB7299",
                "category": "entertainment",
                "appPermissions": {"entitlements": [], "privacy": {}},
                "versions": [],
            }
        ],
        "news": [],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-json", type=Path, default=Path("altstore.json"))
    parser.add_argument("--app-bundle", type=Path, default=None)
    parser.add_argument("--ipa", required=True, type=Path)
    parser.add_argument("--download-url", required=True)
    parser.add_argument("--repo", default=DEFAULT_REPO)
    parser.add_argument("--version", default="")
    parser.add_argument("--build-version", default="")
    parser.add_argument("--description", default="")
    parser.add_argument("--date", default="")
    parser.add_argument("--min-os", default="")
    parser.add_argument("--max-versions", type=int, default=20)
    args = parser.parse_args()

    if not args.ipa.is_file():
        raise FileNotFoundError(f"IPA file not found at {args.ipa}")

    info = load_info_plist(args.app_bundle)
    bundle_id = str(info.get("CFBundleIdentifier") or DEFAULT_BUNDLE_ID)
    app_name = str(
        info.get("CFBundleDisplayName") or info.get("CFBundleName") or DEFAULT_APP_NAME
    )
    short_version = str(args.version or info.get("CFBundleShortVersionString") or "0.1.0")
    build_version = str(args.build_version or info.get("CFBundleVersion") or "1")
    min_os_version = str(args.min_os or info.get("MinimumOSVersion") or DEFAULT_MIN_OS)

    ipa_size = args.ipa.stat().st_size
    ipa_sha256 = compute_sha256(args.ipa)
    release_date = args.date or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    version_desc = args.description.strip() or (
        f"PiliPlus iOS {short_version} (Build {build_version})"
    )

    if args.source_json.is_file():
        manifest = json.loads(args.source_json.read_text(encoding="utf-8"))
    else:
        manifest = build_default_manifest(args.repo, bundle_id, app_name)

    owner = args.repo.split("/")[0] if "/" in args.repo else "ZimingADR"
    raw_base = f"https://raw.githubusercontent.com/{args.repo}/main"
    icon_url = f"{raw_base}/{ICON_PATH}"

    manifest["sourceURL"] = f"{raw_base}/altstore.json"
    manifest["website"] = f"https://github.com/{args.repo}"
    manifest["iconURL"] = icon_url
    manifest["featuredApps"] = [bundle_id]

    apps = manifest.setdefault("apps", [])
    if not apps:
        apps.append(build_default_manifest(args.repo, bundle_id, app_name)["apps"][0])

    app_entry = apps[0]
    app_entry["name"] = app_name
    app_entry["bundleIdentifier"] = bundle_id
    app_entry["developerName"] = owner
    app_entry["iconURL"] = icon_url
    app_entry["appPermissions"] = {
        "entitlements": extract_entitlements(args.app_bundle),
        "privacy": extract_privacy_permissions(info),
    }

    new_version = {
        "version": short_version,
        "buildVersion": build_version,
        "buildNumber": build_version,
        "date": release_date,
        "localizedDescription": version_desc,
        "downloadURL": args.download_url,
        "size": ipa_size,
        "sha256": ipa_sha256,
        "minOSVersion": min_os_version,
    }

    existing_versions = [
        item
        for item in app_entry.get("versions", [])
        if isinstance(item, dict)
        and not (
            str(item.get("version")) == short_version
            and str(item.get("buildVersion", item.get("buildNumber", ""))) == build_version
        )
    ]
    app_entry["versions"] = [new_version, *existing_versions][: max(1, args.max_versions)]

    # AltStore v1 兼容字段：部分旧版 sideload 客户端只读取这些顶层字段。
    app_entry["version"] = short_version
    app_entry["versionDate"] = release_date
    app_entry["versionDescription"] = version_desc
    app_entry["downloadURL"] = args.download_url
    app_entry["size"] = ipa_size

    args.source_json.parent.mkdir(parents=True, exist_ok=True)
    with args.source_json.open("w", encoding="utf-8", newline="\n") as fp:
        json.dump(manifest, fp, ensure_ascii=False, indent=2)
        fp.write("\n")

    print(
        f"Updated {args.source_json}: {app_name} ({bundle_id}) "
        f"v{short_version} ({build_version}), size={ipa_size}, sha256={ipa_sha256}"
    )


if __name__ == "__main__":
    main()
