# Bug / 问题日志 — Frostland Express Demo 开发

> 记录方式：发现日期 | 严重度（高/中/低） | 描述 | 状态

## 2026-08-17（Day 1 冒烟）

### BUG-001 【高】编组界面与 GameState 数据不同步
- **现象**：在编组界面（team.tscn）放置车辆后，`train_save.json` 有 `placed_vehicles`（机车+煤水车），但 `game_state.json` 的 `train.carriages` 仍为 `[]`。主界面"出发"检查的是 `GameState.train.carriages`，导致已编组却提示"请先编组"无法出发。
- **影响**：Demo 核心闭环（编组→出发）被阻断。
- **定位**：team.gd 的 `_save_train()` 只写 `user://train_save.json`，未同步写 `GameState.train.carriages`；main.gd `_on_board_button_pressed` 只读 GameState。
- **修复方案**：team.gd 保存时同步构造 `GameState.train.carriages`（type/is_powered/fuel_left/health/flipped）并 `save_state()`；或 main.gd 出发时从 train_save.json 兜底加载。
- **状态**：✅ 已修复（2026-08-17 Day 2.1，双保险落地）
  1. 同步保存：`train_save.gd::save_train` → `GameState.update_train_composition()` + `save_state()`（基线已有，Day 2.1 复核确认在放置/回收/清空/返回四条路径都调用）。
  2. 旧档兜底：`train_save.gd::migrate_legacy_train_save()` 新增——GameState 无编组时从旧版 `train_save.json` 恢复并备份为 `.legacy_bak`；`load_train_save()` 与 `main.gd::_on_board_button_pressed` 均已接入。
  3. 验证（MCP 实测）：标题→主界面→出发链路通；模拟「GameState 空 + 旧档在」场景，点出发后 carriages 0→2（机车+煤水车）、has_powered=true、旧档成功备份、game_state.json 落盘，用户存档已原样恢复。

### BUG-002 【中】survival.tscn 与 survival.gd 不匹配
- **现象**：survival.tscn（2774B，7/21）只有 SpeedLabel/ModeLabel/BtnAccel/BtnBrake/BtnBack，而 survival.gd（16KB，8/4）含角色面板/资源条/收集/维修逻辑；运行无报错（疑似 get_node_or_null 或动态构建），但 UI 展示层明显缺失。
- **影响**：旧生存玩法展示层残缺。
- **处理**：Day 2 以 travel.tscn（车内第一人称）取代 survival 展示层，survival.gd 数值逻辑移植后归档。
- **状态**：✅ 已处理（2026-08-17 Day 2.2~2.6）——travel.tscn 已建成并接线系统/交互/HUD，main 的「出发」已改指 travel.tscn；survival.tscn 保留作旧展示层参考。

### BUG-003 【低】project.godot 与多个 .gd/.tscn 文件残留 BOM 乱码
- **现象**：project.godot 首行 `"ï»¿config_version"=5`（BOM 被存为字面文本）；15 个 .gd/.tscn 文件头有 UTF-8 BOM。
- **处理**：已全部修复（2026-08-17），git 已提交。

### BUG-004 【低】team.tscn ext_resource 无效 UID
- **现象**：`uid://teamscript001` 为手写假 UID，加载时回退文本路径并警告。
- **处理**：已移除 UID 属性（2026-08-17）。

### BUG-005 【低】AcceptDialog 弹窗无法用模拟输入关闭（测试通道限制）
- **现象**：`game_manage input_mouse` 与 `input_key Escape` 对 Window 类型弹窗（AcceptDialog）无效；`editor_manage game_eval` 返回 null。
- **影响**：自动化测试无法关闭模态弹窗（需重启游戏清状态）。
- **处理**：冒烟脚本已绕开（不点会弹窗的按钮）。
- **更新（2026-08-17 Day 2.1）**：`editor_manage(op=game_eval)` 实测可用（服务器端 v3.4.7 已修复）——`{"op":"game_eval","params":{"code":"..."}}` 可执行 GDScript 并返回 JSON。注意两点：① eval 中不要引用 `VehicleTypes`/`TrainSave` 等全局类（会触发 "Cannot call non-static function on the class" 并把游戏挂到 debugger break，需 stop+run 恢复）；用 autoload（GameState）和场景树节点即可。② 新增 `tools/mcp_call.py` 从 JSON 文件读参数，绕开 PowerShell 引号剥除问题。

## 测试通道记录（工具侧）
- `tools/mcp_client.py`：轻量 MCP 客户端（Streamable HTTP，自动 session 初始化），可用。
- `tools/game_smoke.py`：交互冒烟（点击按钮/查场景树/读 UI 元素），可用；--only 限定按钮名。
- Godot AI 插件版本：项目内 addons 为 v3.1.5，MCP server 自报 3.4.7（server 端更新，插件 dock 版本号未同步，无碍）。
