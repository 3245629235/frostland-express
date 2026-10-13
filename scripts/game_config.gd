extends Node
## 全局游戏配置常量（Autoload 单例）
## 所有魔法数字集中管理，方便调参


func _ready() -> void:
	# 2.7 输入抽象：保证「click」动作在鼠标之外也绑定触摸屏（Android 主力平台）
	_ensure_click_action()


func _ensure_click_action() -> void:
	if not InputMap.has_action("click"):
		InputMap.add_action("click", 0.5)
	# 触屏绑定（project.godot 持久化了鼠标绑定；触摸事件在启动时补上）
	var has_touch := false
	for ev in InputMap.action_get_events("click"):
		if ev is InputEventScreenTouch:
			has_touch = true
			break
	if not has_touch:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		InputMap.action_add_event("click", touch)

# ===== 世界时间 =====
## 资源消耗间隔（秒）
const CONSUME_INTERVAL: float = 2.0
## 现实时间压缩倍率（Day 6）：现实 1 秒 = 游戏内 X 秒。
## 里程推进按游戏内时间折算，使 420km 单程在 30~60 现实分钟内完成。
## 全速 100 m/s（360 km/h 显示）×3 = 等效 1080 km/h → 420km ≈ 23 分钟；均速 ~200 km/h ≈ 42 分钟/圈。
const TIME_COMPRESSION: float = 3.0

# ===== 角色消耗 =====
## 每个角色每 tick 消耗的食物量（Day 6：30 分钟 = 900 tick × 0.8 ≈ 720，初始 800~1000 够一程并形成压力）
const FOOD_PER_CHAR_PER_TICK: float = 0.2

# ===== 列车物理 =====
## 空气阻力系数（乘以速度² = 空气阻力，单位: N）
const AERO_FACTOR: float = 0.02
## 刹车减速度（m/s²）——用户反馈原 15 太慢，提升为 60（高速时约 2 秒刹停）
const BRAKE_DECEL: float = 60.0

# ===== 燃料消耗（DEMO_DESIGN §2.2）=====
## 基础燃料消耗（每 CONSUME_INTERVAL 2s，速度>0 时；Day 6：30 分钟 ≈ 900~1350，初始 1000 + 站补给可撑一程）
const FUEL_BASE_PER_TICK: float = 1.0
## 速度超过该值（km/h）时油耗加成
const FUEL_SPEED_BONUS_KMH: float = 60.0
## 油耗加成倍率（速度>60 km/h 时 +50%）
const FUEL_SPEED_BONUS_MULT: float = 1.5

# ===== 角色状态（每 CONSUME_INTERVAL 2s 结算，DEMO_DESIGN §2.3）=====
## 饥饿：有食物 -2，无食物 -5；<20 扣 HP 3
const HUNGER_DELTA_HAS_FOOD: float = -0.5
const HUNGER_DELTA_NO_FOOD: float = -1.2
const HUNGER_DAMAGE_THRESHOLD: float = 20.0
## 体温：行驶 -1，停靠 +2；<30 扣 HP 3
const TEMP_DELTA_MOVING: float = -0.25
const TEMP_DELTA_STOPPED: float = 0.5
const TEMP_DAMAGE_THRESHOLD: float = 30.0
## 体力：行驶 -2，停靠 +1；0 时不可操作交互点
const STAMINA_DELTA_MOVING: float = -0.5
const STAMINA_DELTA_STOPPED: float = 0.25
## 低状态扣血
const HEALTH_DAMAGE_PER_TICK: float = 3.0
## 自动用药：HP<50% 时消耗 1 药品恢复 20（DEMO_DESIGN §2.1/§2.3）
const AUTO_MEDICINE_HP_RATIO: float = 0.5
const AUTO_MEDICINE_COST: int = 1
const AUTO_MEDICINE_HEAL: float = 20.0

# ===== 维修（DEMO_DESIGN §2.4）=====
const REPAIR_COST_PARTS: int = 10
const REPAIR_FULL_THRESHOLD: float = 90.0    # ≥90 修满 100
const REPAIR_MINOR_THRESHOLD: float = 50.0   # 50~89 +20，上限 90
const REPAIR_MINOR_AMOUNT: float = 20.0
const REPAIR_MINOR_CAP: float = 90.0
const REPAIR_SEVERE_THRESHOLD: float = 25.0  # 25~49 停靠 +10；<25 不可修
const REPAIR_SEVERE_AMOUNT: float = 10.0

# ===== 收集（DEMO_DESIGN §2.1/§3）=====
const COLLECT_DURATION: float = 5.0
const COLLECT_FOOD_MIN: float = 30.0
const COLLECT_FOOD_MAX: float = 60.0
const COLLECT_FUEL_MIN: float = 30.0
const COLLECT_FUEL_MAX: float = 60.0
const STATION_COLLECT_DURATION: float = 5.0

