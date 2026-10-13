#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Frostland Express 一键发布导出（Day 7）。

流程：复制项目到临时副本 → 剔除 addons/godot_ai 与调试 autoload/插件 →
Godot headless 导出 release 包 → 产物复制回项目 dist/。

用法：
  python export_release.py            # 导出 APK + exe
  python export_release.py --apk      # 只导出 Android APK
  python export_release.py --exe      # 只导出 Windows exe
环境变量：
  GODOT_EXE    Godot 可执行文件路径（默认桌面 Godot_v4.7.1-stable_win64.exe）
  JAVA_HOME    Android 导出用 JDK（默认 Android Studio JBR）
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
DIST = PROJECT / "dist"
EXCLUDES = (".git", ".godot", "tests", "tools", "docs", "_archive", "generated")
EXCLUDE_FILES = ("venus-plan-spec.json", "day6-plan-spec.json", "day7-plan-spec.json",
                 "godot-ai-LICENSE.txt")
GODOT = os.environ.get("GODOT_EXE", r"C:/Users/Mr Ray/Desktop/Godot_v4.7.1-stable_win64.exe")
JAVA_HOME = os.environ.get("JAVA_HOME", r"C:/Program Files/Android/Android Studio/jbr")

AUTOLOAD_STRIP = re.compile(r'(?m)^_mcp_game_helper=".*\n')
PLUGINS_STRIP = re.compile(r'(?ms)^\[editor_plugins\]\n\nenabled=PackedStringArray\(.*?\)\n')


def make_clean_copy() -> Path:
    tmp = Path(tempfile.gettempdir()) / "frostland_export"
    if tmp.exists():
        shutil.rmtree(tmp)
    tmp.mkdir(parents=True)
    for item in PROJECT.iterdir():
        if item.name in EXCLUDES or item.name.endswith((".bak", ".backup")):
            continue
        if item.name in EXCLUDE_FILES:
            continue
        dst = tmp / item.name
        if item.is_dir():
            shutil.copytree(item, dst)
        else:
            shutil.copy2(item, dst)
    # 剔除调试插件
    plugin_dir = tmp / "addons" / "godot_ai"
    if plugin_dir.exists():
        shutil.rmtree(plugin_dir)
    # 清理 project.godot 的调试 autoload 与插件段
    pg = tmp / "project.godot"
    text = pg.read_text(encoding="utf-8")
    text = AUTOLOAD_STRIP.sub("", text)
    text = PLUGINS_STRIP.sub("", text)
    pg.write_text(text, encoding="utf-8")
    print(f"[1/3] 副本就绪: {tmp}（{len(list(tmp.rglob('*')))} 项）")
    return tmp


def export(project_dir: Path, preset: str, out_name: str) -> Path:
    env = dict(os.environ)
    env["JAVA_HOME"] = JAVA_HOME
    dist = project_dir / "dist"
    dist.mkdir(exist_ok=True)
    cmd = [GODOT, "--headless", "--path", str(project_dir),
           "--export-release", preset, f"dist/{out_name}"]
    print(f"[2/3] 导出 {preset} ...")
    r = subprocess.run(cmd, capture_output=True, text=True, env=env, timeout=900)
    out = (r.stdout or "") + (r.stderr or "")
    if "Signed" not in out and "[ DONE ]" not in out:
        tail = "\n".join(out.strip().splitlines()[-8:])
        print(f"导出失败（{preset}）:\n{tail}")
        sys.exit(1)
    apk = dist / out_name
    if not apk.exists():
        print(f"导出失败（{preset}）：未找到产物")
        sys.exit(1)
    print(f"    产物: {apk} ({apk.stat().st_size / 1024 / 1024:.1f} MB)")
    return apk


def main() -> None:
    parser = argparse.ArgumentParser(description="Frostland Express 一键发布导出")
    parser.add_argument("--apk", action="store_true", help="只导出 Android APK")
    parser.add_argument("--exe", action="store_true", help="只导出 Windows exe")
    args = parser.parse_args()
    do_apk = args.apk or not args.exe
    do_exe = args.exe or not args.apk

    project_dir = make_clean_copy()
    DIST.mkdir(exist_ok=True)
    if do_apk:
        apk = export(project_dir, "Android", "FrostlandExpress.apk")
        shutil.copy2(apk, DIST / apk.name)
        print(f"[3/3] APK → {DIST / apk.name}")
    if do_exe:
        exe = export(project_dir, "Windows Desktop", "FrostlandExpress.exe")
        shutil.copy2(exe, DIST / exe.name)
        print(f"[3/3] EXE → {DIST / exe.name}")
    print("发布导出完成 ✅")


if __name__ == "__main__":
    main()
