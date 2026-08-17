#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""通用 MCP 工具调用器：参数从 JSON 文件读入，绕开 shell 引号转义问题。
用法：
  python mcp_call.py <tool_name> [args.json]
  args.json 缺省时传空参数 {}
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mcp_client import rpc  # noqa: E402


def main() -> None:
    if len(sys.argv) < 2:
        print("用法: python mcp_call.py <tool_name> [args.json]")
        sys.exit(2)
    tool = sys.argv[1]
    if len(sys.argv) > 2:
        with open(sys.argv[2], encoding="utf-8") as f:
            args = json.load(f)
    else:
        args = {}

    out = rpc("tools/call", {"name": tool, "arguments": args})
    result = out.get("result", out)
    if isinstance(result, dict) and "content" in result:
        for c in result["content"]:
            if c.get("type") == "text":
                print(c.get("text", ""))
            else:
                print(json.dumps(c, ensure_ascii=False))
    else:
        print(json.dumps(result, ensure_ascii=False, indent=2)[:8000])


if __name__ == "__main__":
    main()
