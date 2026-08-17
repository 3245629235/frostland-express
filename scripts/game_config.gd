extends Node
## 全局游戏配置常量（Autoload 单例）
## 所有魔法数字集中管理，方便调参

# ===== 世界时间 =====
## 资源消耗间隔（秒）
const CONSUME_INTERVAL: float = 2.0

# ===== 角色消耗 =====
## 每个角色每 tick 消耗的食物量
const FOOD_PER_CHAR_PER_TICK: int = 1

# ===== 列车物理 =====
## 空气阻力系数（乘以速度² = 空气阻力，单位: N）
const AERO_FACTOR: float = 0.02
## 刹车减速度（m/s²）
const BRAKE_DECEL: float = 15.0
## 最高速度（DEMO_DESIGN §2.2: 0~120 km/h）
const MAX_SPEED_MS: float = 120.0 / 3.6

# ===== 燃料消耗（DEMO_DESIGN §2.2）=====
## 基础燃料消耗（每 CONSUME_INTERVAL 2s，速度>0 时）
const FUEL_BASE_PER_TICK: float = 3.0
## 速度超过该值（km/h）时油耗加成
const FUEL_SPEED_BONUS_KMH: float = 60.0
## 油耗加成倍率（速度>60 km/h 时 +50%）
const FUEL_SPEED_BONUS_MULT: float = 1.5

