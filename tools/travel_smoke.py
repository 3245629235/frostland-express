#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Travel 场景回归冒烟：读取实时 UI 坐标，验证入口与返回。

前置：Godot 编辑器已打开、Godot AI 插件已连接、游戏正在运行。
用法：python travel_smoke.py
"""
import json
import sys
import time

sys.path.insert(0, __file__.rsplit("\\", 1)[0])
from mcp_client import rpc  # noqa: E402


def call_game(op, params=None):
    out = rpc("tools/call", {"name": "game_manage", "arguments": {
        "op": op, "params": params or {}
    }})
    content = out.get("result", {}).get("content", [])
    if not content:
        return {}
    return json.loads(content[0].get("text", "{}"))


def scene_root():
    return call_game("get_scene_tree", {"depth": 2}).get("root", "")


def ui_elements(root_path=""):
    return call_game("get_ui_elements", {
        "root_path": root_path,
        "include_hidden": False,
        "include_disabled": True,
        "max_depth": 8,
    }).get("elements", [])


def center(element):
    rect = element["global_rect"]
    return (
        rect["position"]["x"] + rect["size"]["x"] / 2,
        rect["position"]["y"] + rect["size"]["y"] / 2,
    )


def click(element):
    x, y = center(element)
    for pressed in (True, False):
        call_game("input_mouse", {
            "event": "button",
            "position": {"x": x, "y": y},
            "button": "left",
            "pressed": pressed,
        })
    time.sleep(2.0)


def find(name):
    for element in ui_elements():
        if element.get("name") == name:
            return element
    raise RuntimeError(f"找不到按钮: {name}")


def main():
    root = scene_root()
    print(f"[Travel 冒烟] 起始场景: {root}")
    if root == "/TitleScreen":
        start = next(e for e in ui_elements() if e.get("name") == "StartButton")
        click(start)
        root = scene_root()
        print(f"[Travel 冒烟] 标题 -> {root}")

    if root != "/Main":
        raise RuntimeError(f"预期 Main，实际为 {root}")

    click(find("BoardButton"))
    root = scene_root()
    print(f"[Travel 冒烟] Main -> {root}")
    if root != "/Travel":
        raise RuntimeError(f"预期 Travel，实际为 {root}")

    required = {"StatusLabel", "CarriageLabel", "AccelButton", "BrakeButton", "BackButton"}
    visible = {e.get("name") for e in ui_elements()}
    missing = required - visible
    if missing:
        raise RuntimeError(f"Travel HUD 缺少: {sorted(missing)}")
    print(f"[Travel 冒烟] HUD 通过，5 个关键控件存在")

    click(find("BackButton"))
    root = scene_root()
    print(f"[Travel 冒烟] Travel -> {root}")
    if root != "/Main":
        raise RuntimeError(f"返回后预期 Main，实际为 {root}")
    print("[Travel 冒烟] 通过")


if __name__ == "__main__":
    main()
