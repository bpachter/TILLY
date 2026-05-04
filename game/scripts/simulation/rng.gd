extends Node
class_name TillyRNG

## Deterministic random number generator using Xorshift128+
## Guarantees reproducible sequences for identical seeds.

var state: PackedInt64Array = PackedInt64Array([0, 0])


func _init(seed_value: int = 0) -> void:
	set_seed(seed_value)


func set_seed(seed_value: int) -> void:
	if seed_value == 0:
		seed_value = randi()
	state[0] = seed_value
	state[1] = seed_value ^ 0x1234567890ABCDEF
	_advance()


func _advance() -> void:
	var s1: int = state[0]
	var s0: int = state[1]
	state[0] = s0
	s1 ^= s1 << 23
	state[1] = s1 ^ s0 ^ (s1 >> 17) ^ (s0 >> 26)


func next_uint64() -> int:
	_advance()
	return state[1] + state[0]


func next_int(min_val: int, max_val: int) -> int:
	if min_val == max_val:
		return min_val
	var range_val: int = max_val - min_val
	return min_val + int(next_uint64() % range_val)


func next_float() -> float:
	return float(next_uint64() % 1000000) / 1000000.0


func next_weighted_choice(weights: PackedFloat64Array) -> int:
	if weights.is_empty():
		return -1
	var total: float = 0.0
	for w in weights:
		total += w
	if total <= 0:
		return 0
	var roll: float = next_float() * total
	var acc: float = 0.0
	for i in range(weights.size()):
		acc += weights[i]
		if roll < acc:
			return i
	return weights.size() - 1


func get_state() -> PackedInt64Array:
	return state.duplicate()


func set_state(saved_state: PackedInt64Array) -> void:
	if saved_state.size() == 2:
		state = saved_state.duplicate()
