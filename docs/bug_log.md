# Bug / 问题日志 — Frostland Express Demo 开发

> 记录方式：发现日期 | 严重度（高/中/低） | 描述 | 状态

## 2026-08-22（Day 6 数值平衡）

### BUG-012 【中】站点收集数值硬编码，未跟随 GameConfig 平衡表
- **现象**：Day 7 真窗口验证白桦林站「停留收集」只给食物 +9、燃料 +9，而 Day 6 平衡表为食物 30~60、燃料 30~60。
- **定位**：`station_system.gd::collect_reward` 硬编码 `5 + seed % 11` / `3 + (seed/11) % 8`（旧 5~15/3~10），未引用 GameConfig.COLLECT_FOOD_MIN/MAX；Day 6 只改了 travel.gd 车内交互点收集，漏掉站点收集。
- **修复**：collect_reward 改为按 GameConfig 区间 lerp 映射（seed 保持确定性）。
- **验证**：真窗口白桦林站收集 +38/+51；Day 7 测试新增区间断言。
- **状态**：✅ 已修复。

### BUG-011 【中】体温低扣血嵌套在饥饿判断内，体温低而饥饿正常时不扣血
- **现象**：`game_state.gd::_apply_character_ticks` 中体温阈值扣血的 `if` 缩进在饥饿扣血的 `if` 内部，导致只有「饥饿 < 20 且体温 < 30」同时成立时才扣两次血；单独体温跌破 30 不扣血，与 DEMO_DESIGN §2.3 不符。
- **定位**：Day 3 引入的缩进错误（原意两个条件独立判断）。
- **修复**：体温判断提升到与饥饿同层，独立扣血。
- **验证**：Day 6 平衡测试覆盖体温阈值曲线；真窗口角色 HP 随行驶下降正常。
- **状态**：✅ 已修复。

### 平衡修正记录（Day 6）
- 原数值（Day 2~5）与 DEMO_DESIGN §6「单程 30~60 分钟」目标严重不匹配：消耗 2s/tick × 900 tick 下体温 90 点约 2 分钟打穿、食物/燃料 500~1000 只够数分钟；战斗火力 ~210/发秒杀 30 HP 雪狼、Boss 200 HP 约 1 秒击杀。
- 修正：时间压缩 ×3（里程折算）、消耗降为 ~1/5（体温 -0.25/tick 等）、战斗敌人 HP 提升 20~60 倍、射速 1 发/秒。全部集中在 game_config.gd / battle_data.gd，便于后续调参。

## 2026-08-17（Day 2 用户验收）

### BUG-006 【高】travel 场景视觉回归：雪原视差被车库内饰覆盖、列车消失、速度被 120km/h 上限压慢
- **现象**（用户验收反馈）：
  1. 登车页面精心制作的雪原视差场景消失，被编组界面式车库内饰（wall/ceiling_floor 全屏铺满）取代；
  2. 原车速计算公式被 120 km/h 上限限制，感觉明显变慢；
  3. 登车页面火车车厢消失，只有 4 个角色；拖拽也无法浏览列车全貌。
- **定位**：Day 2 以 train_walk 原型重建 travel.tscn 时，未移植 survival.tscn 的 5 层雪原视差（含 y_off/z 序）与 TrainContainer 车厢渲染/拖拽逻辑，并新增了全屏内饰 overlay；Day 2.3 又给 TrainPhysics 加了 MAX_SPEED_MS 钳制。
- **修复**（2026-08-17）：
  1. travel.tscn 恢复 survival 原版结构：Layer0Sky~Layer4FrontTree（速度 0/0.15/0.35/0.6/1.6，y_off 0/0/0/215/5）+ TrainContainer（clip_contents）；
  2. travel.gd 移植 survival 的列车渲染/拖拽/惯性/夹取逻辑（TRAIN_GROUND_SPEED=0.6、3px 拖拽阈值、0.95 惯性衰减），小队随列车拖拽同步移动；
  3. 删除 TrainPhysics 的 120 km/h 上限与 GameConfig.MAX_SPEED_MS，恢复原始 f_tract/f_aero 公式（实测已重新加速至 100+ m/s 并继续增长）。
- **验证（MCP 实测）**：5 个视差层各 2 tile 存在、Ground y_off=215；TrainContainer 内 2 节车厢精灵（总宽 1849px>1280px）；注入拖拽 press(640)→motion(300)→release 后车厢 x 从 -284 滑至夹取边界 -1209，惯性生效；角色跟随列车位移，点击 (640,520) 可走回。Day 2 的系统/HUD/交互点全部保留。
- **状态**：✅ 已修复，待用户复测确认。
- **追加修复（用户复测反馈 2026-08-17）**：
  1. **车厢图片仍不显示**：TrainContainer（Control）挂在 Node2D 下时锚点不拉伸，宽度算成 0，加上 clip_contents=true 把所有车厢精灵裁掉。修复：_render_train 显式设置 offset_left/right/top/bottom（0~1280）。MCP 验证：容器全局宽 1280，屏幕采样点与车厢贴图像素一致。
  2. **刹车太慢**：原 BRAKE_DECEL=15 m/s²，且登车界面没有独立刹车按钮（加速按钮只切加速/滑行）。修复：BRAKE_DECEL 提升为 60 m/s²（高速约 2 秒刹停），TopBar 加回「刹车/松开刹车」按钮（mode 2）。MCP 实测：103.8 m/s 点击刹车后 1.2 秒内降至 0。
  3. **锅炉/物资箱/维修台浮空、小人能走出列车**：交互点原来是固定屏幕坐标，不与列车一起滚动；行走只钳制 y 不钳制 x。修复：交互点改为 TrainContainer 子节点，坐标绑定列车内容坐标（train_x/local_y），每帧同步 _train_scroll，随拖拽移动并被容器裁剪；点击行走目标钳制到「列车内容 ∩ 屏幕可见」范围。MCP 实测：拖拽后锅炉 -829/cargo 240/repair 470 随车移动；点 (1240,200) 目标被夹到 (580,426)。期间修复一个连带 bug：_apply_train_positions 清空子节点时误删 InteractionRoot（改为只清 TextureRect）。
  4. **图层错误/看不到点不到交互点**（用户复测）：交互点被车厢精灵和前景树层盖住，且维修台在车尾需拖拽才可见。修复：InteractionRoot 移出 TrainContainer 到最上层（z=10，与小人同层），随列车内容坐标移动、滑出屏幕自动隐藏；新增地板/天花板装饰带（CeilingStrip/FloorStrip，z=7，随车滚动）；角色脚线与地板条上沿对齐（脚线=band.bottom-26，精灵中心=脚线-90）。
  5. **小人垂直乱走**：行走目标改为固定地板线（当前无梯子，禁止垂直移动）；目标 y 修正为精灵中心（脚线-半身高90），避免角色陷入地板。MCP 实测：点 (400,300) → 目标 (400,549.4)；拖到车尾点维修台 (470,639) → 小人走到 (470,549.4) 且弹窗出现。

## 2026-08-17（Day 1 冒烟）

## 2026-08-18（Day 2 收口）

### BUG-009 【高】重新进入登车页自动加速且角色位置偏移
- **现象**：从 Travel 返回主界面后再次进入 Travel，列车从 0 速度自动重新加速；角色位置与退出前不一致，尤其在列车滚动浏览后偏移明显。
- **定位**：`travel.gd::_ready()` 在有动力机车时强制设置 `train_control_mode=1`；`crew_positions` 原来保存带列车滚动偏移的屏幕坐标，重新进入时列车滚动基准重置，导致坐标被错解释。
- **修复**：Travel 每次进入都明确从 `mode=0/speed=0` 开始；角色位置新增 `crew_positions_space=train_content_v2` 标记，保存为相对列车内容的 x，加载时叠加当前 `_train_scroll`；旧版屏幕坐标档首次兼容读取并在退出时自动升级。
- **验证**：首次与第二次进入 Travel 均 `speed=0、mode=0`；角色移动后返回再进入，小王位置保持 `x≈1056.63`；用户原存档已恢复。
- **状态**：✅ 已修复。

### BUG-007 【中】主界面沿用旧档旅行标记导致后台继续结算
- **现象**：Travel 运行后停止游戏或返回主界面时，`game_state.json` 可能保留 `is_traveling=true`；主界面仍每帧调用 `GameState.tick_world()`，会继续推进世界时间并消耗资源。
- **修复**：`scripts/main.gd::_ready()` 进入主界面时调用 `GameState.stop_travel()`；`scripts/travel.gd` 进入 Travel 使用 `start_travel()`，返回使用 `stop_travel()`；`stop_travel()` 同时清零控制模式和列车速度。
- **验证**：运行时 Main 为 `is_traveling=false`；Travel 为 `true`；Travel 返回 Main 后 `is_traveling=false`、`train_control_mode=0`、速度为 0。
- **状态**：✅ 已修复。

### BUG-008 【中】Travel 画面补出默认角色但 GameState.characters 未同步
- **现象**：人员编成存档只有 3 名角色时，Travel 画面仍通过默认列表显示 4 名角色，但食物消耗和角色状态结算只按 GameState 中的 3 人处理，HUD 与实际结算人数不一致。
- **修复**：`scripts/travel.gd::_ensure_crew_state()` 改为按角色 ID 补齐缺失的默认随车角色，最多 4 人；交互体力检查改为实际执行交互的角色，不再固定检查列车长。
- **验证**：Travel 启动后 `GameState.characters.size()=4`，ID 与画面随车角色一致；物资箱、锅炉、维修台交互均通过。
- **状态**：✅ 已修复。

### BUG-001 【高】编组界面与 GameState 数据不同步
- **现象**：在编组界面（team.tscn）放置车辆后，`train_save.json` 有 `placed_vehicles`（机车+煤水车），但 `game_state.json` 的 `train.carriages` 仍为 `[]`。主界面"出发"检查的是 `GameState.train.carriages`，导致已编组却提示"请先编组"无法出发。
- **影响**：Demo 核心闭环（编组→出发）被阻断。
- **定位**：team.gd 的 `_save_train()` 只写 `user://train_save.json`，未同步写 `GameState.train.carriages`；main.gd `_on_board_button_pressed` 只读 GameState。
- **修复方案**：team.gd 保存时同步构造 `GameState.train.carriages`（type/is_powered/fuel_left/health/flipped）并 `save_state()`；或 main.gd 出发时从 train_save.json 兜底加载。
- **状态**：✅ 已修复（2026-08-17 Day 2.1，双保险落地）
  1. 同步保存：`train_save.gd::save_train` → `GameState.update_train_composition()` + `save_state()`（基线已有，Day 2.1 复核确认在放置/回收/清空/返回四条路径都调用）。
  2. 旧档兜底：`train_save.gd::migrate_legacy_train_save()` 新增——GameState 无编组时从旧版 `train_save.json` 恢复并备份为 `.legacy_bak`；`load_train_save()` 与 `main.gd::_on_board_button_pressed` 均已接入。
  3. 验证（MCP 实测）：标题→主界面→出发链路通；模拟「GameState 空 + 旧档在」场景，点出发后 carriages 0→2（机车+煤水车）、has_powered=true、旧档成功备份、game_state.json 落盘，用户存档已原样恢复。

### BUG-010 【中】Day 3 中间站离站后路线里程被错误归零
- **现象**：从白桦林站等中间站点继续行驶时，`route_distance_km` 被清零，下一站冻湖站会要求重新行驶完整 180 km，站点门槛语义错误。
- **定位**：`StationSystem.continue_from_station()` 对所有站点都返回 `route_distance_km=0`；路线里程应表示本圈累计里程，只有极光城折返时归零。
- **修复**：中间站离站返回当前站点门槛里程；极光城返回 0 并递增 `route_lap`。
- **验证**：headless 规则测试新增白桦林站→冻湖站断言；MCP 真窗口验证极光城→白桦林站折返。
- **状态**：✅ 已修复（Day 3 收口）。

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
