#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""godot-ai MCP 轻量客户端（Streamable HTTP）。
用法：
  python mcp_client.py list                          # 列出工具
  python mcp_client.py call <tool_name> '<json args>'  # 调用工具
环境变量 GODOT_MCP_URL 可覆盖端点（默认 http://127.0.0.1:8000/mcp）
"""
import json
import os
import sys
import urllib.request

URL = os.environ.get("GODOT_MCP_URL", "http://127.0.0.1:8000/mcp")
_SESSION_ID = None


def _post(payload, timeout=120):
    global _SESSION_ID
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    }
    if _SESSION_ID:
        headers["Mcp-Session-Id"] = _SESSION_ID
    req = urllib.request.Request(
        URL, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST"
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        sid = resp.headers.get("Mcp-Session-Id") or resp.headers.get("mcp-session-id")
        if sid:
            _SESSION_ID = sid
        return resp.read().decode("utf-8")


def _parse_sse(body):
    """解析 SSE 响应，返回最后一个 data: 的 JSON。"""
    data_lines = []
    for line in body.splitlines():
        if line.startswith("data:"):
            data_lines.append(line[5:].strip())
    if not data_lines:
        return json.loads(body) if body.strip() else None
    return json.loads(data_lines[-1])


_INIT_DONE = False


def rpc(method, params, _id=1):
    global _INIT_DONE
    if not _INIT_DONE:
        ensure_initialized()
        _INIT_DONE = True
    body = _post({"jsonrpc": "2.0", "id": _id, "method": method, "params": params})
    return _parse_sse(body)


def ensure_initialized():
    init = _post({
        "jsonrpc": "2.0", "id": 1, "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "hermes-frostland", "version": "1.0"},
        },
    })
    parsed = _parse_sse(init)
    if "result" not in parsed:
        print("initialize 失败:", json.dumps(parsed, ensure_ascii=False)[:500])
        sys.exit(1)
    try:
        _post({"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}})
    except Exception:
        pass


def main():
    ensure_initialized()
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        out = rpc("tools/list", {}, _id=2)
        tools = out.get("result", {}).get("tools", [])
        for t in tools:
            print(f"{t['name']}  —  {(t.get('description') or '').splitlines()[0][:80]}")
        print(f"\n共 {len(tools)} 个工具")
    elif cmd == "call":
        name = sys.argv[2]
        args = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
        out = rpc("tools/call", {"name": name, "arguments": args}, _id=3)
        result = out.get("result", out)
        if isinstance(result, dict) and "content" in result:
            for c in result["content"]:
                print(c.get("text", json.dumps(c, ensure_ascii=False)))
        else:
            print(json.dumps(result, ensure_ascii=False, indent=2)[:4000])
    else:
        print("未知命令:", cmd)


if __name__ == "__main__":
    main()
