#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ComfyUI 低显存方案 · 模型下载器（只用 Python 标准库）

用法：
    python download-models.py --list
    python download-models.py --profile minimal  --dest "D:\\ComfyUI\\ComfyUI\\models"
    python download-models.py --profile standard --dest "D:\\ComfyUI\\ComfyUI\\models"
    python download-models.py --only realvisxl --only animagine --dest "..."
    python download-models.py --profile standard --source modelscope --dest "..."
    python download-models.py --profile minimal --dry-run

特性：
- 多源自动降级：ModelScope → HF 镜像 → HF 官方 → CNB
- 断点续传（.part）
- 已存在且大小合理则跳过
- 不下载任何 .exe / 安装器
- 失败只影响单个文件，不中断整批

退出码：0 全部成功；1 有失败；2 参数/清单错误。
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

UA = "comfyui-low-vram-downloader/1.0 (+https://github.com/)"
CHUNK = 1024 * 256
TIMEOUT = (20, 60)
GB = 1024 ** 3


def human(n: float) -> str:
    if n >= GB:
        return f"{n / GB:.2f} GB"
    if n >= 1024 ** 2:
        return f"{n / 1024 ** 2:.1f} MB"
    if n >= 1024:
        return f"{n / 1024:.0f} KB"
    return f"{n:.0f} B"


def log(msg: str) -> None:
    print(msg, flush=True)


def load_manifest(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def http_get(url: str, headers: dict[str, str] | None = None):
    req = urllib.request.Request(url, headers={"User-Agent": UA, **(headers or {})})
    return urllib.request.urlopen(req, timeout=TIMEOUT)


def resolve_cnb(repo: str, path: str) -> str:
    """把 CNB 的 Git LFS 指针解析成真实下载地址。"""
    for branch in ("main", "master"):
        raw = f"{repo}/-/git/raw/{branch}/{path}"
        try:
            with http_get(raw) as r:
                text = r.read().decode("utf-8", "replace")
        except Exception:
            continue
        if "oid sha256:" not in text:
            continue
        oid = re.search(r"oid sha256:([0-9a-f]{64})", text)
        size = re.search(r"size (\d+)", text)
        if not oid:
            continue
        body = json.dumps({
            "operation": "download",
            "transfers": ["basic"],
            "objects": [{
                "oid": oid.group(1),
                "size": int(size.group(1)) if size else 0,
            }],
        }).encode("utf-8")
        req = urllib.request.Request(
            f"{repo}.git/info/lfs/objects/batch",
            data=body,
            headers={
                "User-Agent": UA,
                "Accept": "application/vnd.git-lfs+json",
                "Content-Type": "application/vnd.git-lfs+json",
            },
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            data = json.loads(r.read().decode("utf-8"))
        return data["objects"][0]["actions"]["download"]["href"]
    raise RuntimeError("CNB 指针解析失败（分支不对或文件不存在）")


def candidate_urls(src: dict[str, str], allow: set[str] | None) -> list[tuple[str, str]]:
    """返回 [(类型, 地址), ...]，按优先级。"""
    t = src.get("type", "")
    if allow and t not in allow:
        return []
    if t == "ms":
        return [("modelscope", f"https://modelscope.cn/models/{src['repo']}/resolve/master/{src['path']}")]
    if t == "hf":
        repo, file = src["repo"], src["file"]
        return [
            ("hf-mirror", f"https://hf-mirror.com/{repo}/resolve/main/{file}?download=true"),
            ("huggingface", f"https://huggingface.co/{repo}/resolve/main/{file}?download=true"),
        ]
    if t == "cnb":
        try:
            return [("cnb", resolve_cnb(src["repo"], src["path"]))]
        except Exception as e:
            log(f"     [CNB] 解析失败：{e}")
            return []
    if t == "url":
        return [("direct", src["url"])]
    return []


def download_one(url: str, dest: Path, expected: int) -> bool:
    dest.parent.mkdir(parents=True, exist_ok=True)
    part = dest.with_suffix(dest.suffix + ".part")

    for attempt in range(1, 5):
        have = part.stat().st_size if part.exists() else 0
        headers = {"Range": f"bytes={have}-"} if have else {}
        try:
            with http_get(url, headers) as r:
                status = getattr(r, "status", 200)
                if status == 416 and have:
                    # 已经下完
                    part.replace(dest)
                    log(f"     OK（已完整）{dest.name}")
                    return True
                mode = "ab" if status == 206 and have else "wb"
                if status == 200:
                    have = 0
                total = int(r.headers.get("Content-Length") or 0) + have
                last = time.time()
                with part.open(mode) as f:
                    while True:
                        block = r.read(CHUNK)
                        if not block:
                            break
                        f.write(block)
                        have += len(block)
                        now = time.time()
                        if now - last > 5:
                            pct = f" ({have / total * 100:.1f}%)" if total else ""
                            log(f"     … {dest.name}  {human(have)} / {human(total) if total else '?'}{pct}")
                            last = now
            if expected and have < expected * 0.85:
                log(f"     WARN 文件偏小：{human(have)}，参考 {human(expected)}，可能没下完")
            part.replace(dest)
            log(f"     OK {dest.name}  {human(dest.stat().st_size)}")
            return True
        except urllib.error.HTTPError as e:
            if e.code == 416 and have:
                part.replace(dest)
                log(f"     OK（已完整）{dest.name}")
                return True
            log(f"     RETRY {attempt}/4  HTTP {e.code}")
        except Exception as e:
            log(f"     RETRY {attempt}/4  {type(e).__name__}: {e}")
        time.sleep(3)
    log(f"     FAIL {dest.name}")
    return False


def already_ok(dest: Path, expected: int) -> bool:
    if not dest.exists():
        return False
    size = dest.stat().st_size
    if size < 1024 * 1024:
        return False
    if expected and size < expected * 0.85:
        return False
    return True


def main() -> int:
    here = Path(__file__).resolve().parent
    ap = argparse.ArgumentParser(description="ComfyUI 低显存模型下载器")
    ap.add_argument("--manifest", default=str(here / "models.json"), help="清单文件")
    ap.add_argument("--dest", default=os.environ.get("COMFYUI_MODELS", r"D:\ComfyUI\ComfyUI\models"),
                    help="ComfyUI 的 models 目录")
    ap.add_argument("--profile", choices=["minimal", "standard", "video", "post"], help="按档位下载")
    ap.add_argument("--only", action="append", default=[], help="只下指定 id，可重复")
    ap.add_argument("--source", choices=["modelscope", "hf-mirror", "huggingface", "cnb", "direct"],
                    help="只走指定来源")
    ap.add_argument("--list", action="store_true", help="列出清单")
    ap.add_argument("--dry-run", action="store_true", help="只显示将要下载什么")
    ap.add_argument("--force", action="store_true", help="已存在也重下")
    args = ap.parse_args()

    try:
        data = load_manifest(Path(args.manifest))
    except Exception as e:
        log(f"读取清单失败：{e}")
        return 2

    models = {m["id"]: m for m in data["models"]}
    profiles = data.get("profiles", {})

    if args.list:
        log(f"{'ID':<20} {'大小':>9}  说明")
        log("-" * 78)
        for m in data["models"]:
            log(f"{m['id']:<20} {m.get('size_gb', 0):>7.2f}GB  {m.get('name', '')}")
        log("\n档位：")
        for name, ids in profiles.items():
            total = sum(models[i].get("size_gb", 0) for i in ids if i in models)
            log(f"  {name:<10} {len(ids):>2} 个文件 约 {total:.1f} GB")
        return 0

    if args.only:
        missing = [x for x in args.only if x not in models]
        if missing:
            log(f"未知 id：{', '.join(missing)}")
            return 2
        selected = [models[x] for x in args.only]
    elif args.profile:
        selected = [models[x] for x in profiles.get(args.profile, []) if x in models]
    else:
        log("请指定 --profile 或 --only；用 --list 查看清单。")
        return 2

    allow = {args.source} if args.source else None
    dest_root = Path(args.dest)
    total_gb = sum(m.get("size_gb", 0) for m in selected)
    log(f"目标目录：{dest_root}")
    log(f"计划下载：{len(selected)} 个文件，约 {total_gb:.1f} GB")

    if not args.dry_run:
        dest_root.mkdir(parents=True, exist_ok=True)
        free = shutil.disk_usage(dest_root).free
        log(f"磁盘剩余：{human(free)}")
        if free < total_gb * GB * 0.9:
            log("WARN 剩余空间可能不够。建议清理磁盘，或改用 --profile minimal。")

    todo = []
    for m in selected:
        dest = dest_root / m["dest"]
        expected = int(m.get("size_gb", 0) * GB)
        if not args.force and already_ok(dest, expected):
            log(f"[跳过] {m['id']}  {dest.name}")
            continue
        todo.append((m, dest, expected))

    if args.dry_run:
        for m, dest, expected in todo:
            urls = []
            for src in m.get("sources", []):
                urls += candidate_urls(src, allow)
            log(f"[计划] {m['id']:<18} → {dest}")
            for kind, url in urls:
                log(f"        {kind:<12} {url}")
        return 0

    ok = fail = 0
    for idx, (m, dest, expected) in enumerate(todo, 1):
        log(f"\n[{idx}/{len(todo)}] {m['name']}  ({m.get('size_gb', 0):.2f} GB)")
        urls = []
        for src in m.get("sources", []):
            urls += candidate_urls(src, allow)
        if not urls:
            log("     FAIL 没有可用来源（检查 --source 或网络）")
            fail += 1
            continue
        done = False
        for kind, url in urls:
            log(f"     源：{kind}")
            if download_one(url, dest, expected):
                done = True
                break
            log("     换下一个源…")
        if done:
            ok += 1
        else:
            fail += 1

    log(f"\n=== 结束：成功 {ok}，失败 {fail}，跳过 {len(selected) - len(todo)} ===")
    if fail:
        log("提示：失败的模型可以稍后重跑同一命令；也可以用 --only <id> 单独重试。")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())