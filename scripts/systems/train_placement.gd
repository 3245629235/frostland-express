extends RefCounted
class_name TrainPlacement
## 列车编组放置/回收规则引擎（纯静态方法，无状态）

const TYPE_LOCO = "locomotive"
const TYPE_COAL = "coal_tender"
const TYPE_PASSENGER = "passenger"
const TYPE_OPEN = "open_car"
const TYPE_TANK = "tank_car"
const TYPE_SERVICE = "service_car"
const TYPE_COMBAT = "combat_car"

# ===== 类型判断 =====
static func is_cargo_type(type: String) -> bool:
	return type == TYPE_PASSENGER or type == TYPE_OPEN or type == TYPE_TANK or type == TYPE_SERVICE or type == TYPE_COMBAT

# ===== 统计/查询 =====
static func count_type(type: String, placed_vehicles: Array) -> int:
	var count = 0
	for v in placed_vehicles:
		if v.type == type:
			count += 1
	return count

static func leftmost_loco_index(placed_vehicles: Array) -> int:
	for i in range(placed_vehicles.size()):
		if placed_vehicles[i].type == TYPE_LOCO:
			return i
	return -1

# ===== 放置规则校验 =====
## 返回空字符串表示合法，否则返回错误信息
static func check_placement_rules(type: String, insert_index: int, placed_vehicles: Array, player_inventory: Dictionary) -> String:
	if type == TYPE_LOCO:
		if insert_index != 0 and insert_index != placed_vehicles.size():
			return "机车只能放在列车两端"
		var loco_count = count_type(TYPE_LOCO, placed_vehicles)
		if loco_count >= 2:
			return "机车数量已达上限（两端各一个）"
		if not _locomotives_at_ends_after_insert(insert_index, placed_vehicles):
			return "放置后有机车不在两端，无法放置"
		var coal_count = count_type(TYPE_COAL, placed_vehicles) + player_inventory.get(TYPE_COAL, 0)
		if loco_count + 1 > coal_count:
			return "机车需要煤水车提供燃料，请先添加煤水车"

	elif type == TYPE_COAL:
		if placed_vehicles.is_empty():
			return "煤水车不能单独放置，请先放机车"
		if count_type(TYPE_LOCO, placed_vehicles) == 0:
			return "煤水车必须与机车相连"
		if count_type(TYPE_LOCO, placed_vehicles) == 1 and leftmost_loco_index(placed_vehicles) == 0 and insert_index <= leftmost_loco_index(placed_vehicles):
			return "当只有一个机车时，不能在机车左边放置煤水车"
		if not _locomotives_at_ends_after_insert(insert_index, placed_vehicles):
			return "放置后有机车不在两端，无法放置"
		if _coal_would_be_between_passengers(insert_index, placed_vehicles):
			return "煤水车不能放置在车厢之间"

	elif is_cargo_type(type):
		if placed_vehicles.is_empty():
			return "车厢不能单独放置，请先放机车"
		if count_type(TYPE_LOCO, placed_vehicles) == 0:
			return "车厢必须与机车相连"
		var loco_count = count_type(TYPE_LOCO, placed_vehicles)
		if loco_count >= 2:
			if insert_index == 0 or insert_index == placed_vehicles.size():
				return "有两个机车时，车厢不能放置在列车两端"
		if loco_count == 1 and leftmost_loco_index(placed_vehicles) == 0 and insert_index == 0:
			return "车厢不能放置在机车左边"
		if not _locomotives_at_ends_after_insert(insert_index, placed_vehicles):
			return "放置后有机车不在两端，无法放置"
		if _passenger_would_split_power_unit(insert_index, placed_vehicles):
			return "车厢不能放置在机车和煤水车之间"
		if insert_index > 0:
			var prev_type = placed_vehicles[insert_index - 1].type
			if prev_type == TYPE_LOCO:
				return "车厢不能直接连接在机车后面，请先放置煤水车"

	return ""

# ===== 回收规则校验 =====
static func check_recycle_rules(index: int, placed_vehicles: Array) -> String:
	var v = placed_vehicles[index]

	if v.type == TYPE_LOCO and index == 0 and placed_vehicles.size() > 1:
		return "最左侧的机车必须最后一个回收"

	if v.type == TYPE_LOCO or v.type == TYPE_COAL:
		if _all_locomotives_unpowered_after_remove(index, placed_vehicles):
			return "回收后所有机车将无动力，列车无法运行"

	return ""

# ===== 动力检查 =====
static func has_unpowered_locomotives(placed_vehicles: Array) -> bool:
	for i in range(placed_vehicles.size()):
		var v = placed_vehicles[i]
		if v.type != TYPE_LOCO:
			continue
		var has_power = false
		if v.flipped:
			for j in range(i - 1, -1, -1):
				var prev_v = placed_vehicles[j]
				if prev_v.type == TYPE_COAL:
					has_power = true
					break
				elif prev_v.type == TYPE_LOCO or is_cargo_type(prev_v.type):
					break
		else:
			for j in range(i + 1, placed_vehicles.size()):
				var next_v = placed_vehicles[j]
				if next_v.type == TYPE_COAL:
					has_power = true
					break
				elif next_v.type == TYPE_LOCO or is_cargo_type(next_v.type):
					break
		if not has_power:
			return true
	return false

static func all_locomotives_unpowered(placed_vehicles: Array) -> bool:
	for i in range(placed_vehicles.size()):
		var v = placed_vehicles[i]
		if v.type != TYPE_LOCO:
			continue
		var has_power = false
		if v.flipped:
			for j in range(i - 1, -1, -1):
				var prev_v = placed_vehicles[j]
				if prev_v.type == TYPE_COAL:
					has_power = true
					break
				elif prev_v.type == TYPE_LOCO or is_cargo_type(prev_v.type):
					break
		else:
			for j in range(i + 1, placed_vehicles.size()):
				var next_v = placed_vehicles[j]
				if next_v.type == TYPE_COAL:
					has_power = true
					break
				elif next_v.type == TYPE_LOCO or is_cargo_type(next_v.type):
					break
		if has_power:
			return false
	return true

# ===== 内部辅助 =====
static func _locomotives_at_ends_after_insert(insert_index: int, placed_vehicles: Array) -> bool:
	var new_size = placed_vehicles.size() + 1
	for i in range(placed_vehicles.size()):
		if placed_vehicles[i].type == TYPE_LOCO:
			var new_pos = i if i < insert_index else i + 1
			if new_pos != 0 and new_pos != new_size - 1:
				return false
	return true

static func _coal_would_be_between_passengers(insert_index: int, placed_vehicles: Array) -> bool:
	if placed_vehicles.is_empty():
		return false
	var has_cargo_before = false
	for i in range(insert_index):
		if is_cargo_type(placed_vehicles[i].type):
			has_cargo_before = true
			break
	var has_cargo_after = false
	for i in range(insert_index, placed_vehicles.size()):
		if is_cargo_type(placed_vehicles[i].type):
			has_cargo_after = true
			break
	return has_cargo_before and has_cargo_after

static func _passenger_would_split_power_unit(insert_index: int, placed_vehicles: Array) -> bool:
	if placed_vehicles.is_empty():
		return false
	var left_type = ""
	if insert_index > 0:
		left_type = placed_vehicles[insert_index - 1].type
	var right_type = ""
	if insert_index < placed_vehicles.size():
		right_type = placed_vehicles[insert_index].type
	if left_type == TYPE_LOCO and right_type == TYPE_COAL:
		return true
	if left_type == TYPE_COAL and right_type == TYPE_LOCO:
		return true
	return false

static func _all_locomotives_unpowered_after_remove(skip_index: int, placed_vehicles: Array) -> bool:
	var removed = placed_vehicles[skip_index]
	placed_vehicles.remove_at(skip_index)
	var result = all_locomotives_unpowered(placed_vehicles)
	placed_vehicles.insert(skip_index, removed)
	return result
