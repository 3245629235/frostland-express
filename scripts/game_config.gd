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

