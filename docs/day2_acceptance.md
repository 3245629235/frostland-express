# Day 2 验收记录

项目：Frostland Express Demo
引擎：Godot 4.7.1，GL Compatibility，1280×720
工作区：`C:\Users\Mr Ray\Desktop\frostland-express-clean`
执行方式：Godot AI MCP 真窗口运行验证 + 源码审阅 + `git diff --check`
存档保护：阶段 A 已备份到 `C:\Users\Mr Ray\Desktop\day2_save_backup\`，测试临时状态已恢复。

## 结果摘要

Day 2 核心验收通过。Travel 场景、编组数据同步、物理/燃料/角色 tick、HUD、三类交互点、角色独立控制、场景往返和 click 输入抽象均已实际验证。期间修复了两个状态一致性问题：主界面不会继续沿用旧档的旅行标记；Travel 返回主界面会停止列车并清零控制模式/速度；Travel 启动时会把缺失的默认随车角色补入 GameState，保证画面人数与状态结算人数一致。

## 分项结果

- [x] 2.1 编组保存与出发链路：当前 3 节编组可加载，`GameState.train.carriages=3`，质量统计为 145；无编组/旧档兜底代码已审阅。
- [x] 2.2 Travel 场景：5 层视差每层 2 tile，TrainContainer 有 3 节车厢精灵，4 名角色和 HUD 可见。
- [x] 2.3 行驶系统：临时补燃料后加速模式速度升至约 29.77 m/s；燃料按 tick 从 75 降到 50；刹车模式可降速到 0；无动力边界速度保持 0。
- [x] 2.4 资源与状态：HUD 资源条、4 名角色状态行正常；Travel 启动后 GameState.characters 补齐为 4 人。
- [x] 2.5 交互点：物资箱收集完成并播报“食物 +10，燃料 +8”；锅炉“加煤”按钮通过并恢复机车动力；维修台 HP 70→90、零件 100→90 通过。
- [x] 2.6 场景流转：Main→Travel→Main 通过；返回后 `is_traveling=false`、`train_control_mode=0`、速度为 0；Travel 可再次进入。
- [x] 2.7 输入抽象：`project.godot` 的 `click` 绑定鼠标左键；`scripts/game_config.gd` 启动时补 `InputEventScreenTouch`；Travel 使用 click 动作处理移动/拖拽。
- [x] 角色独立控制：未选中时点击空白自动选择最近角色，只移动一个角色；角色按钮/点击小人可切换控制；拖拽列车时角色随车同步。
- [x] 代码质量：`git diff --check` 通过；清洁运行后的编辑器日志无新增错误。
- [x] 重新进入 Travel：再次进入保持 `speed=0、mode=0`；角色位置使用 `train_content_v2` 相对列车坐标恢复。

## 本轮修复

1. `scripts/main.gd`
   - Main `_ready()` 调用 `GameState.stop_travel()`，避免旧存档 `is_traveling=true` 导致主界面后台消耗资源。

2. `scripts/travel.gd`
   - Travel `_ready()` 使用 `GameState.start_travel()`。
   - Travel 返回使用 `GameState.stop_travel()`。
   - 缺失默认随车角色时，补入 `GameState.characters`，统一画面角色与状态结算人数。
   - 交互动作体力检查改为实际执行交互的角色，不再固定检查列车长。
   - 保留并验证角色独立控制、历史位置去重、角色选择 HUD。

3. `scripts/game_state.gd`
   - `stop_travel()` 同时清零旅行控制模式和列车速度。

4. `tools/travel_smoke.py`
   - 新增可重复的 Travel 入口、HUD 和返回冒烟脚本。

5. `scripts/travel.gd`、`scripts/game_state.gd`
   - 修复 BUG-009：Travel 重新进入默认停车，不再自动加速；角色位置改为相对列车内容坐标保存，并兼容旧屏幕坐标存档。

## 已知边界

- 当前用户存档本身资源很低、部分角色 HP 为 0、抛锚次数为 2；这是原存档状态，不是本轮测试写入。最终已恢复阶段 A 备份。
- 编组页当前人员编队缺少一队队长时，既有“返回”规则会弹窗阻止返回；这是人员编成规则，未在 Day 2 擅自修改用户编队。
- `tools/travel_smoke.py` 需要 Godot 游戏已运行且 Godot AI MCP 在线；它不会自动启动游戏。
- Day 3 随机事件、站点面板、胜负结算和 Day 4 战斗系统不属于本次范围。

## 产物与检查

- 用户存档备份：`C:\Users\Mr Ray\Desktop\day2_save_backup\`
- Travel 回归脚本：`tools/travel_smoke.py`
- 本记录：`docs/day2_acceptance.md`
- Windows 导出：`dist/FrostlandExpress.exe`，导出进程退出码 0，文件约 157.5 MB
- Python 工具语法检查：`python -m py_compile tools/travel_smoke.py tools/game_smoke.py tools/mcp_client.py` 通过
- 存档哈希：`game_state.json` 与阶段 A 备份一致；`train_save.json` 与阶段 A 备份一致
- `git diff --check`：通过
- Git 提交：未执行，按计划保留工作区差异供用户审阅
