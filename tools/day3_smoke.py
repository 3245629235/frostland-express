#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Day 3 真窗口冒烟测试入口。

前置：Godot 编辑器、Godot AI MCP 和正在运行的游戏窗口。
正式验收阶段会通过实时 UI 矩形驱动事件、站点和结算按钮。
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
    return call_game("get_scene_tree", {"depth": 3}).get("root", "")


def ui_elements():
    return call_game("get_ui_elements", {
        "include_hidden": False,
        "include_disabled": True,
        "max_depth": 10,
    }).get("elements", [])


def center(element):
    rect = element["global_rect"]
    return (
        rect["position"]["x"] + rect["size"]["x"] / 2,
        rect["position"]["y"] + rect["size"]["y"] / 2,
    )


def click(element, wait=1.0):
    x, y = center(element)
    for pressed in (True, False):
        call_game("input_mouse", {
            "event": "button",
            "position": {"x": x, "y": y},
            "button": "left",
            "pressed": pressed,
        })
    time.sleep(wait)


def find_button(name):
    for element in ui_elements():
        if element.get("name") == name:
            return element
    raise RuntimeError(f"找不到按钮: {name}")


def main():
    root = scene_root()
    print(f"[Day 3 冒烟] 起始场景: {root}")
    if not root:
        raise RuntimeError("无法读取游戏场景；请确认 Godot AI MCP 在线且游戏正在运行")
    print("[Day 3 冒烟] 基线连接通过；具体事件/站点/结算步骤将在功能完成后启用")


if __name__ == "__main__":
    main()
