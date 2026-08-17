# Frostland Express Clean — Code Wiki

> **极寒末日列车生存游戏**  
> Godot 4.x 项目 | GDScript | 2D 视差滚动 | 1280×720 | GL Compatibility

---

## 目录

1. [项目概览](#1-项目概览)
2. [项目结构](#2-项目结构)
3. [场景流转图](#3-场景流转图)
4. [核心模块详解](#4-核心模块详解)
   - [4.1 GameState — 全局游戏状态（Autoload 单例）](#41-gamestate--全局游戏状态autoload-单例)
   - [4.2 title_screen — 标题界面](#42-title_screen--标题界面)
   - [4.3 main — 主界面（中枢 Hub）](#43-main--主界面中枢-hub)
   - [4.4 survival — 生存模式（核心玩法）](#44-survival--生存模式核心玩法)
   - [4.5 team — 列车编组（拖拽拼装）](#45-team--列车编组拖拽拼装)
   - [4.6 team_select — 人员编成](#46-team_select--人员编成)
   - [4.7 character_select_dialog — 角色选择对话框](#47-character_select_dialog--角色选择对话框)
   - [4.8 CharacterData — 角色数据源](#48-characterdata--角色数据源)
   - [4.9 VehicleTypes — 车辆类型配置](#49-vehicletypes--车辆类型配置)
   - [4.10 character_card — 角色卡片控件](#410-character_card--角色卡片控件)
   - [4.11 depot_card — 角色选择卡片控件](#411-depot_card--角色选择卡片控件)
   - [4.12 empty_slot — 空位插槽控件](#412-empty_slot--空位插槽控件)
5. [数据流与依赖关系](#5-数据流与依赖关系)
6. [保存/加载机制](#6-保存加载机制)
7. [资源清单](#7-资源清单)
8. [导出配置](#8-导出配置)
9. [项目运行方式](#9-项目运行方式)

---

## 1. 项目概览

| 属性 | 值 |
|------|-----|
| 项目名称 | Frostland Express Clean |
| 游戏类型 | 极寒末日 · 列车生存管理 |
| 引擎 | Godot 4.7 (GL Compatibility) |
| 语言 | GDScript |
| 分辨率 | 1280 × 720 |
| 目标平台 | Android / Web |
| 主入口场景 | `scenes/title_screen.tscn` |

**游戏核心概念：** 在极寒末日世界中，玩家作为列车长管理一列蒸汽火车，编组车厢、调度人员、管理资源（食物/燃料/药品/零件/弹药），在冰原上行驶并生存下去。

---

## 2. 项目结构

```
frostland-express-clean/
├── project.godot                  # Godot 项目配置（Autoload、渲染、窗口）
├── export_presets.cfg             # 导出预设（Android + Web）
├── CODE_WIKI.md                   # 本文档
│
├── assets/                        # 静态资源
│   ├── fonts/
│   │   └── simsun.ttc             # 宋体字体
│   ├── sprites/
│   │   ├── characters/            # 角色立绘
│   │   │   ├── 101/               #   列车长（列车长常服新.png）
│   │   │   ├── 小刘/              #   小刘（医疗）
│   │   │   ├── 王刚/              #   小王（警卫）
│   │   │   └── 老葛/              #   老葛（司机）
│   │   ├── vehicles/              # 车辆素材（每个子目录包含 card + vehicle 两张图）
│   │   │   ├── locomotive/        #   机车
│   │   │   ├── coal_tender/       #   煤水车
│   │   │   ├── passenger/         #   客车
│   │   │   ├── open_car/          #   敞车
│   │   │   ├── tank_car/          #   罐车
│   │   │   ├── service_car/       #   勤务车厢
│   │   │   └── combat_car/        #   战斗车厢
│   │   ├── game_background.jpg    # 游戏背景
│   │   ├── menu_background.png    # 菜单背景
│   │   ├── wall.png               # 远景墙壁（视差滚动层1）
│   │   ├── ceiling_floor.png      # 天花板/地板（视差滚动层2）
│   │   ├── conductor.png          # 列车长立绘
│   │   ├── wanggang.png           # 王刚立绘
│   │   ├── start_button.png       # 开始按钮
│   │   └── start_button_new.png   # 开始按钮（新版）
│   └── themes/
│       └── default_theme.tres     # 全局 UI 主题
│
├── scenes/                        # 场景文件 (.tscn)
│   ├── title_screen.tscn          # 标题场景
│   ├── main.tscn                  # 主界面 Hub
│   ├── survival.tscn              # 生存模式界面
│   ├── team.tscn                  # 列车编组界面
│   ├── team_select.tscn           # 人员编成界面
│   ├── character_card.tscn        # 角色卡片组件
│   ├── character_select_dialog.tscn # 角色选择弹窗组件
│   ├── depot_card.tscn            # 角色库卡片组件
│   └── empty_slot.tscn            # 空位插槽组件
│
├── scripts/                       # 脚本文件 (.gd)
│   ├── game_state.gd              # Autoload 全局单例
│   ├── title_screen.gd            # 标题界面逻辑
│   ├── main.gd                    # 主界面逻辑
│   ├── survival.gd                # 生存模式逻辑
│   ├── team.gd                    # 列车编组逻辑
│   ├── team_select.gd             # 人员编成逻辑
│   ├── character_select_dialog.gd # 角色选择弹窗逻辑
│   ├── character_data.gd          # 角色数据源
│   ├── vehicle_types.gd           # 车辆类型配置
│   ├── character_card.gd          # 角色卡片控件
│   ├── depot_card.gd              # 角色库卡片控件
│   └── empty_slot.gd              # 空位插槽控件
│
└── .godot/                        # Godot 编辑器缓存（忽略）
```

---

## 3. 场景流转图

```
title_screen (标题界面)
     │ 点击"开始游戏"
     ▼
main (主界面 Hub)
     │
     ├── [编组] ──────────▶ team (列车编组)
     │                           │ 返回
     │                           ▼
     │                       main ◀── 保存编组数据
     │
     ├── [出发] ──────────▶ survival (生存模式)
     │                           │ 返回/首页
     │                           ▼
     │                       main / team
     │
     └── [人员编成] ──────▶ team_select (人员编成)
                                 │ 确认/返回
                                 ▼
                             main
```

所有场景切换都会自动触发 `GameState.save_state()` 保存进度。

---

## 4. 核心模块详解

### 4.1 GameState — 全局游戏状态（Autoload 单例）

**文件：** `scripts/game_state.gd`  
**类型：** Autoload（在 `project.godot` 中注册为 `GameState`）  
**全局访问：** `GameState.xxx`

#### 枚举

```gdscript
enum ResourceType { FOOD, FUEL, MEDICINE, PARTS, AMMO_SMALL, AMMO_LARGE }
```

#### 核心变量

| 变量 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `resources` | `Dictionary` | 各 1000 | 六种资源的数量字典 |
| `characters` | `Array` | `[]` | 已编入队伍的角色列表 |
| `train` | `Dictionary` | 见下方 | 列车状态（health/max_health/speed/carriages） |
| `morale` | `float` | 50.0 | 全局士气 |
| `is_traveling` | `bool` | false | 是否在行驶中 |
| `travel_time` | `float` | 0.0 | 累计行驶时间 |
| `current_node` | `String` | "station_start" | 当前所在节点 |

#### 资源操作

| 方法 | 签名 | 说明 |
|------|------|------|
| `get_resource` | `(type_str: String) -> int` | 获取资源数量 |
| `add_resource` | `(type_str: String, amount: int) -> void` | 增加资源 |
| `consume_resource` | `(type_str: String, amount: int) -> bool` | 消耗资源，不足返回 false |
| `reset_resources` | `() -> void` | 全部重置为 1000 |

#### 列车状态操作

| 方法 | 说明 |
|------|------|
| `set_train_health(health)` | 设置血量（自动 clamp） |
| `damage_train(amount)` | 扣血 |
| `repair_train(amount)` | 修复 |
| `get_train_efficiency()` | 返回健康百分比（0~1） |

#### 旅行消耗

| 方法 | 说明 |
|------|------|
| `calculate_travel_consumption(duration)` | 计算旅行消耗（食物 = duration×2，燃料 = duration×3） |
| `apply_travel_consumption(consumption)` | 执行消耗，不足返回 false |

#### 持久化

| 方法 | 说明 |
|------|------|
| `save_state()` | 保存到 `user://game_state.json` |
| `load_state()` | 从 `user://game_state.json` 加载，返回是否成功 |
| `full_reset()` | 完全重置所有状态 |

> **重要：** GameState 在 `_exit_tree()` 时自动调用 `save_state()`。

---

### 4.2 title_screen — 标题界面

**文件：** `scripts/title_screen.gd`  
**场景：** `scenes/title_screen.tscn`  
**职责：** 显示游戏标题，点击"开始游戏"按钮跳转到主界面。

| 方法 | 说明 |
|------|------|
| `_on_start_button_pressed()` | 切换到 `main.tscn` |

---

### 4.3 main — 主界面（中枢 Hub）

**文件：** `scripts/main.gd`  
**场景：** `scenes/main.tscn`  

**职责：** 游戏的中心导航界面，展示列车长立绘（支持滑动切换）、实时资源消耗、各子系统入口。

#### UI 组件

- **Conductor（TextureRect）：** 列车长立绘，支持左右拖动/键盘切换
- **ResourcePanel：** 顶部资源栏（食物/燃料/药品/零件，含消耗速率）
- **DebugPanel：** 调试面板（添加资源/重置按钮）
- **三个导航按钮：** 编组 / 出发 / 人员编成

#### 核心机制

| 常量 | 值 | 说明 |
|------|-----|------|
| `CONSUME_INTERVAL` | 2.0 秒 | 资源消耗间隔 |

**资源消耗公式（每 2 秒）：**
- 食物消耗 = `角色数量 × 1`
- 燃料消耗 = `3`

#### 立绘浏览

- 支持 4 张立绘轮播（列车长、王刚、老葛、小刘）
- 交互方式：鼠标左右拖动 / 键盘 ← → 键

#### 关键方法

| 方法 | 说明 |
|------|------|
| `_consume_resources()` | 周期性消耗资源 |
| `_update_resource_ui()` | 刷新资源显示（含速率） |
| `_load_portraits()` | 加载立绘纹理 |
| `_on_team_button_pressed()` | 跳转编组场景 |
| `_on_board_button_pressed()` | 跳转生存模式 |
| `_on_team_select_button_pressed()` | 跳转人员编成 |

---

### 4.4 survival — 生存模式（核心玩法）

**文件：** `scripts/survival.gd`  
**场景：** `scenes/survival.tscn`  

**职责：** 核心玩法循环。管理列车行驶/停靠状态、资源消耗、物资收集、列车维修、角色状态（饥饿/体温/体力）。

#### 状态变量

| 变量 | 说明 |
|------|------|
| `is_traveling` | 是否正在行驶 |
| `is_stopped` | 是否手动停靠 |
| `travel_timer` | 行驶计时器（累计） |
| `is_collecting` | 是否正在收集物资 |
| `collect_timer` | 收集计时器 |

#### 常量

| 常量 | 值 | 说明 |
|------|-----|------|
| `CONSUME_INTERVAL` | 2.0 秒 | 消耗间隔 |
| `TRAVEL_DURATION` | 30.0 秒 | 单程行驶时长 |

#### 行驶机制

1. **出发：** 点击"出发"按钮，开始消耗资源，持续 30 秒
2. **行驶中：** 资源持续消耗、角色体力下降、体温下降
3. **到站：** 自动停止，获得奖励（食物 +5，零件 +3）
4. **停靠：** 可手动停车，停车后可收集物资

#### 资源消耗（每 2 秒）

| 消耗项 | 公式 | 备注 |
|--------|------|------|
| 食物 | `角色数 × 1` | 不足时饥饿额外 -5 |
| 燃料 | `3` | 固定 |
| 角色饥饿 | `-2`（有食物）/ `-5`（无食物） | 低于 20 时扣血 |
| 角色体温 | `-1` | 低于 30 时扣血 |
| 角色体力 | 行驶 `-2`，停靠 `+1` | clamp 到 [0, max_stamina] |

#### 物资收集

- 点击"收集"按钮，等待 5 秒
- 随机获得 食物 5~15、燃料 3~10
- 30% 概率触发敌人遭遇

#### 维修系统

| 条件 | 效果 |
|------|------|
| 血量 ≥ 90 | 修满到 100 |
| 50 ≤ 血量 < 90 | 修复 +20，上限 90 |
| 25 ≤ 血量 < 50 | 停靠修复 +10（行驶中不可修） |
| 血量 < 25 | 停靠状态不可修，行驶不可修 |

维修消耗：10 零件/次。

#### 角色面板

动态生成角色状态面板，显示每个角色的血量条、饥饿度、体温。

---

### 4.5 team — 列车编组（拖拽拼装）

**文件：** `scripts/team.gd`  
**场景：** `scenes/team.tscn`  
**保存路径：** `user://train_save.json`

**职责：** 核心建造系统。玩家通过拖拽卡片到铁轨来拼装列车编组，支持 7 种车型，复杂的放置规则校验。

#### 支持的车型

| 类型常量 | 中文名 | 初始数量 | 类别 |
|----------|--------|----------|------|
| `TYPE_LOCO` | 机车 | 3 | 动力 |
| `TYPE_COAL` | 煤水车 | 4 | 动力 |
| `TYPE_PASSENGER` | 客车 | 2 | 货运 |
| `TYPE_OPEN` | 敞车 | 1 | 货运 |
| `TYPE_TANK` | 罐车 | 1 | 货运 |
| `TYPE_SERVICE` | 勤务车厢 | 2 | 货运 |
| `TYPE_COMBAT` | 战斗车厢 | 2 | 货运 |

#### 构建菜单

```
构建菜单
├── 机车
├── 煤水车
├── 特殊机车（暂未实现）
├── 货车（子菜单）
│   ├── 敞车
│   └── 罐车
├── 客车
├── 勤务车厢
└── 战斗车厢
```

#### 放置规则（`_check_placement_rules`）

| 车型 | 规则 |
|------|------|
| **机车** | 只能放列车两端；总数 ≤ 2；机车数不能超过煤水车数 |
| **煤水车** | 不能单独放置；必须与机车相连；不能夹在车厢之间 |
| **货运车厢** | 不能单独放置；必须有机车；有两台机车时不能放两端；不能插入机车与煤水车之间（动力单元） |

#### 交互操作

| 操作 | 说明 |
|------|------|
| **拖放放置** | 从底部卡片面板拖到铁轨上释放 |
| **拖放回收** | 从铁轨上拖回车卡面板释放 |
| **视差滚动** | 鼠标拖动铁轨区域左右滚动，带惯性 |
| **一键清除** | 清除所有已放置车辆 |

#### 方向管理（`_refresh_flips`）

- 最右端机车自动翻转（朝右）
- 煤水车朝向最近的机车
- 货运车厢不翻转

#### 动力检查（`_has_unpowered_locomotives`）

- 每台机车必须有一台相邻的煤水车提供动力
- 煤水车必须在机车的朝向方向上直接相邻

#### 关键方法

| 方法 | 说明 |
|------|------|
| `_init_vehicle_data()` | 从 VehicleTypes 构建车辆数据 |
| `_show_cards(type)` | 展示指定类型的卡片 |
| `_try_place_vehicle(mouse_pos)` | 尝试放置车辆 |
| `_try_recycle_vehicle(mouse_pos)` | 尝试回收车辆 |
| `_check_placement_rules(type, index)` | 放置规则校验 |
| `_check_recycle_rules(index)` | 回收规则校验 |
| `_rearrange_vehicles()` | 重新布局所有车辆 |
| `_save_train()` / `_load_train_save()` | 编组保存/加载（含完整性校验） |

---

### 4.6 team_select — 人员编成

**文件：** `scripts/team_select.gd`  
**场景：** `scenes/team_select.tscn`  

**职责：** 编队管理系统。支持 4 个编队（Team1~4），每队最多 8 个位置，拖拽排序，角色详情查看。

#### 关键常量

| 常量 | 值 | 说明 |
|------|-----|------|
| `MAX_ECHELON_SIZE` | 8 | 每队最大人数 |
| `SLOT_HEIGHT` | 560 | 卡片槽高度 |
| `DRAG_SCALE` | 1.1 | 拖拽时缩放倍率 |

#### 核心流程

1. 从 `GameState.characters` 加载已保存的编队
2. 如果无存档，使用 `CharacterData.get_default_team()` 默认角色
3. 4 个编队切换按钮（Team1~4）
4. 点击空位 → 打开角色选择弹窗
5. 点击已有角色 → 打开查看模式（可离队）
6. 拖拽卡片 → 重新排序
7. 右侧面板显示角色详情（立绘、星级、HP、作战效能）

#### 关键方法

| 方法 | 说明 |
|------|------|
| `_load_saved_team()` | 从 GameState 加载编队（与 CharacterData 合并） |
| `_save_team()` | 保存到 GameState |
| `_update_slot_display()` | 刷新卡槽显示 |
| `_get_echelon_characters(echelon)` | 获取指定编队的角色（8 个位置，null 填空） |
| `_move_slot(from, to)` | 拖拽移动角色位置 |
| `_update_efficiency()` | 计算全队作战效能（总攻击力） |

---

### 4.7 character_select_dialog — 角色选择对话框

**文件：** `scripts/character_select_dialog.gd`  
**场景：** `scenes/character_select_dialog.tscn`  

**职责：** CanvasLayer 弹窗，显示可用角色列表（已分配的角色灰显不可选），支持两种模式。

#### 模式

| 模式 | 触发 | 说明 |
|------|------|------|
| **选择模式** | 点击空位 | 选人加入编队 |
| **查看模式** | 点击已有角色 | 可以离队（show leave button） |

#### 信号

| 信号 | 参数 | 说明 |
|------|------|------|
| `character_selected` | `char_data: Dictionary` | 选择了角色 |
| `character_removed` | `char_data: Dictionary` | 角色离队 |

#### 关键方法

| 方法 | 说明 |
|------|------|
| `setup(characters, assigned)` | 初始化选择模式 |
| `setup_view(char_data, characters, assigned)` | 初始化查看模式 |
| `_populate_grid()` | 生成角色卡片网格（200×120） |

---

### 4.8 CharacterData — 角色数据源

**文件：** `scripts/character_data.gd`  
**类型：** `RefCounted` 静态工具类（`class_name CharacterData`）

**职责：** 所有角色的唯一数据定义源。合并了 `team_select` 和 `survival` 所需的全部字段。

#### 8 个角色

| ID | 名称 | 角色 | 星级 | HP | 攻击 | 体力 | 特性 |
|----|------|------|------|-----|------|------|------|
| `conductor` | 列车长 | 全能 | ★5 | 100 | 60 | 100/100 | PDW专精, 全能指挥 |
| `laoge` | 老葛 | 司机 | ★4 | 110 | 55 | 120/120 | 猎枪专精, 驾驶专精 |
| `xiaowang` | 小王 | 警卫 | ★5 | 120 | 75 | 110/110 | 武器大师 |
| `xiaoliu` | 小刘 | 医疗 | ★4 | 90 | 45 | 95/95 | PDW专精, 医护专精 |
| `lisi` | 李四 | 工程师 | ★4 | 100 | 50 | 100/100 | 维修专精, 爆破专精 |
| `zhangsan` | 张三 | 侦察 | ★3 | 85 | 65 | 120/120 | 潜行专精, 狙击专精 |
| `wangwu` | 王五 | 厨师 | ★3 | 80 | 40 | 90/90 | 烹饪专精, 采集专精 |
| `zhaoliu` | 赵六 | 通讯兵 | ★3 | 75 | 50 | 100/100 | 通讯专精, 破解专精 |

#### 静态方法

| 方法 | 说明 |
|------|------|
| `get_default_team()` | 返回前 4 人（列车长、老葛、小王、小刘） |
| `find_by_id(id)` | 按 ID 查找角色（返回 deep copy） |
| `get_all_ids()` | 获取所有角色 ID 列表 |

---

### 4.9 VehicleTypes — 车辆类型配置

**文件：** `scripts/vehicle_types.gd`  
**类型：** `RefCounted` 静态工具类（`class_name VehicleTypes`）

#### 枚举

```gdscript
enum Type { LOCOMOTIVE, COAL_TENDER, PASSENGER, OPEN_CAR, TANK_CAR, SERVICE_CAR, COMBAT_CAR }
```

#### 配置字典（CONFIG）

每种类型包含：`name`（中文名）、`card_path`（卡片素材）、`vehicle_path`（车辆素材）、`initial_count`（初始数量）。

#### 静态方法

| 方法 | 说明 |
|------|------|
| `get_all_types()` | 返回所有类型枚举 |
| `from_string(s)` | 字符串 → 枚举 |
| `enum_to_string(t)` | 枚举 → 字符串 |
| `get_name(t)` / `get_card_path(t)` / `get_vehicle_path(t)` / `get_initial_count(t)` | 属性查询 |
| `build_initial_inventory()` | 构建初始库存字典 |

---

### 4.10 character_card — 角色卡片控件

**文件：** `scripts/character_card.gd`  
**场景：** `scenes/character_card.tscn`  
**类型：** `class_name CharacterCard`

**职责：** 用于 `team_select` 的可拖拽角色卡片。显示立绘、名称、角色、星级、HP、状态。

#### 信号

| 信号 | 说明 |
|------|------|
| `card_clicked` | 点击卡片 |
| `add_button_clicked` | 点击"添加"按钮 |
| `drag_started(card)` | 开始拖拽 |
| `drag_ended(card)` | 结束拖拽 |

#### 交互

- 鼠标按住水平拖拽超过 `DRAG_THRESHOLD (10px)` 触发拖拽
- 未超过阈值则触发点击
- 选中状态缩放 1.25×
- Preview 模式忽略所有输入

---

### 4.11 depot_card — 角色选择卡片控件

**文件：** `scripts/depot_card.gd`  
**场景：** `scenes/depot_card.tscn`

**职责：** 用于 `character_select_dialog` 的角色库卡片。仅展示立绘、名称、星级，支持点击选择/灰显不可选。

#### 信号

| 信号 | 说明 |
|------|------|
| `card_clicked(char_data)` | 点击卡片（附带角色数据） |

#### 方法

| 方法 | 说明 |
|------|------|
| `set_data(data)` | 设置角色数据 |
| `set_selectable(bool)` | 设置是否可选（灰显/无视输入） |

---

### 4.12 empty_slot — 空位插槽控件

**文件：** `scripts/empty_slot.gd`  
**场景：** `scenes/empty_slot.tscn`

**职责：** 编队中的空位占位符。仅包含一个"+"添加按钮和提示文字。

#### 信号

| 信号 | 说明 |
|------|------|
| `add_clicked` | 点击添加按钮 |

---

## 5. 数据流与依赖关系

```
┌─────────────────────────────────────────────────────────────────────┐
│                        GameState (Autoload)                         │
│  resources │ characters │ train │ morale │ is_traveling │ ...       │
└──────┬──────────┬──────────┬────────────────────────────────────────┘
       │          │          │
       ▼          ▼          ▼
    main.gd   team_select   survival
    (消耗)    (编队读写)    (消耗/维修)
       │          │
       │          ├── CharacterData (静态数据源)
       │          ├── character_card.gd (控件)
       │          ├── character_select_dialog.gd (弹窗)
       │          ├── depot_card.gd (卡片控件)
       │          └── empty_slot.gd (空位控件)
       │
       ├── team.gd ── VehicleTypes (静态配置)
       │
       └── title_screen.gd (入口)
```

**依赖方向：**
- 所有脚本依赖 `GameState`（Autoload，全局可访问）
- `team.gd` 依赖 `VehicleTypes`（静态配置类）
- `team_select.gd` / `character_select_dialog.gd` / `survival.gd` 依赖 `CharacterData`
- 场景脚本通过 `get_tree().change_scene_to_file()` 切换场景

---

## 6. 保存/加载机制

### GameState 保存

- **路径：** `user://game_state.json`
- **触发时机：**
  - 场景退出时自动（`_exit_tree()`）
  - 切换场景前手动调用
- **内容：** resources, characters, train, morale, is_traveling, travel_time, current_node

### 列车编组保存

- **路径：** `user://train_save.json`
- **触发时机：** 每次放置/回收/清除操作后
- **内容：** placed_vehicles（类型+翻转状态）, inventory（库存）
- **校验：** 加载时校验 `库存 + 已放置 == 初始总量`，损坏则重置

---

## 7. 资源清单

### 6 种游戏资源

| 资源 | 内部 Key | 初始值 | 用途场景 |
|------|----------|--------|----------|
| 食物 | `food` | 1000 | 主界面消耗、生存旅行消耗、角色饥饿 |
| 燃料 | `fuel` | 1000 | 主界面消耗、生存旅行消耗 |
| 药品 | `medicine` | 1000 | 生存模式（预留） |
| 零件 | `parts` | 1000 | 生存模式列车维修 |
| 小口径弹药 | `ammo_small` | 1000 | 生存模式（预留） |
| 大口径弹药 | `ammo_large` | 1000 | 生存模式（预留） |

### 美术素材

| 类别 | 数量 | 格式 |
|------|------|------|
| 角色立绘 | 5 张（含 1 张 conductor 旧版 + 1 张 wanggang） | PNG |
| 车辆素材 | 7 种 × 2（card + vehicle）= 14 张 | PNG |
| 背景/UI | 4 张（game_background, menu_background, wall, ceiling_floor） | JPG/PNG |
| 按钮 | 2 张（start_button, start_button_new） | PNG |
| 字体 | 1 个（宋体 simsun.ttc） | TTC |

---

## 8. 导出配置

| 预设 | 平台 | 导出路径 | 备注 |
|------|------|----------|------|
| Android | arm64-v8a | `Desktop/游戏安装包/project.ST.apk` | 签名、沉浸模式 |
| Web | — | 未配置 | 单线程 |

---

## 9. 项目运行方式

### 前置要求

- Godot Engine 4.7+（GL Compatibility 渲染）
- 操作系统：Windows / macOS / Linux

### 运行步骤

1. 打开 Godot Engine
2. 点击「导入」→ 选择本文件夹中的 `project.godot`
3. 等待导入完成（素材较大）
4. 按 `F5` 或点击「运行项目」启动
5. 标题界面 → 点击「开始游戏」→ 进入主界面

### 编辑器配置

- 主场景：`scenes/title_screen.tscn`
- 窗口大小：1280 × 720（`canvas_items` 拉伸模式）
- 默认背景色：`#0a1424`

---

> 文档生成时间：2026-07-20  
> 项目版本：Frostland Express Clean (Godot 4.7 GL Compatibility)
