#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""交互式冒烟测试：驱动真实游戏窗口，验证场景流转。
用法：python game_smoke.py [--all | --scene name]
"""
import json
import sys
import time
import urllib.request

sys.path.insert(0, __file__.rsplit("\\", 1)[0])
from mcp_client import rpc  # noqa: E402

URL = "http://127.0.0.1:8000/mcp"


def click(x, y, wait=2.5):
    """在游戏窗口中模拟点击 (x,y)。"""
    for pressed in (True, False):
        rpc("tools/call", {
            "name": "game_manage",
            "arguments": {"op": "input_mouse", "params": {
                "event": "button", "position": {"x": x, "y": y},
                "button": "left", "pressed": pressed}},
        })
    time.sleep(wait)


def ui_elements():
    out = rpc("tools/call", {"name": "game_manage",
                             "arguments": {"op": "get_ui_elements", "params": {}}})
    els = out.get("result", {}).get("content", [{}])
    text = json.loads(els[0].get("text", "{}")) if els else {}
    return text.get("elements", [])


def center(el):
    r = el["global_rect"]
    return (r["position"]["x"] + r["size"]["x"] / 2,
            r["position"]["y"] + r["size"]["y"] / 2)


def scene_root():
    out = rpc("tools/call", {"name": "game_manage",
                             "arguments": {"op": "get_scene_tree", "params": {}}})
    els = out.get("result", {}).get("content", [{}])
    text = json.loads(els[0].get("text", "{}")) if els else {}
    return text.get("root"), text.get("total_count", 0)


def run(only=None):
    print(f"[冒烟] 当前场景: {scene_root()}")
    els = ui_elements()
    buttons = [e for e in els if "Button" in e.get("type", "")]
    if only:
        buttons = [b for b in buttons if b["name"] in only]
    print(f"[冒烟] 找到按钮 {len(buttons)} 个:")
    for b in buttons:
        c = center(b)
        print(f"    {b['name']}  type={b['type']}  center=({c[0]:.0f},{c[1]:.0f})")

    for b in buttons:
        c = center(b)
        before = scene_root()[0]
        print(f"\n[冒烟] 点击 [{b['name']}] @ ({c[0]:.0f},{c[1]:.0f})")
        click(c[0], c[1], wait=3.0)
        after, n = scene_root()
        print(f"    {before} -> {after} (节点数 {n})")
        # 若是子界面且有返回按钮，点返回
        if after != "/Main" and after != before:
            els2 = ui_elements()
            back = [e for e in els2
                    if e.get("name") == "BackButton"
                    or e.get("name") == "BackBtn"
                    or ("返回" in e.get("name", "") and "Background" not in e.get("name", ""))
                    or e.get("name") in ("HomeButton", "MenuButton")]
            if back:
                c2 = center(back[0])
                print(f"    找到返回按钮 [{back[0]['name']}]，点击返回")
                click(c2[0], c2[1], wait=2.5)
                print(f"    返回后: {scene_root()[0]}")
            else:
                print("    (无返回按钮，列出可见按钮名)")
                for e in els2:
                    if "Button" in e.get("type", ""):
                        print(f"      {e['name']}")

    print("\n[冒烟] 完成")


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="逗号分隔的按钮名，只测这些按钮")
    args = ap.parse_args()
    only = args.only.split(",") if args.only else None
    run(only)
