extends Node
class_name CrewAmbitionsManager

## Manages crew personal ambitions — hidden goals that advance through gameplay.
## Each crew member gets one ambition at game start. Completion fires morale bonuses
## and can trigger loyalty events or mutiny risks.

var crew: Array = []
var rng: TillyRNG
var event_callbacks: Dictionary = {}  # "ambition_complete", "ambition_progress"

# --- Ambition catalogue ---
# Each entry defines one possible ambition.
# trigger_destinations: arriving here advances progress by 25 pts
# trigger_events: triggering this event advances progress by 15 pts
# completion_morale_bonus: applied to the crew member on completion
# category: "exploration", "discovery", "relationship", "combat", "survival"
const AMBITION_CATALOGUE: Array = [
	{
		"id": "visit_titan",
		"label": "Visit Titan's methane lakes",
		"category": "exploration",
		"trigger_destinations": ["titan"],
		"trigger_events": ["fuel_efficiency_win"],
		"completion_morale_bonus": 25
	},
	{
		"id": "visit_deep_system",
		"label": "Journey to the deep system",
		"category": "exploration",
		"trigger_destinations": ["pluto", "ceres"],
		"trigger_events": [],
		"completion_morale_bonus": 30
	},
	{
		"id": "discover_alien_life",
		"label": "Confirm extraterrestrial life",
		"category": "discovery",
		"trigger_destinations": ["europa", "enceladus"],
		"trigger_events": ["silent_probe_ping", "encrypted_distress_signal"],
		"completion_morale_bonus": 35
	},
	{
		"id": "survive_five_combats",
		"label": "Survive five hostile encounters",
		"category": "combat",
		"trigger_destinations": [],
		"trigger_events": [],  # Advanced manually by TillyGame after each combat win
		"completion_morale_bonus": 20
	},
	{
		"id": "befriend_crewmate",
		"label": "Form a deep bond with a crewmate",
		"category": "relationship",
		"trigger_destinations": [],
		"trigger_events": ["crew_bonding_dinner", "quiet_night_reflection"],
		"completion_morale_bonus": 20
	},
	{
		"id": "chart_anomaly",
		"label": "Chart an unexplained anomaly",
		"category": "discovery",
		"trigger_destinations": ["ganymede", "pluto"],
		"trigger_events": ["anomaly_detection", "gravity_anomaly"],
		"completion_morale_bonus": 25
	},
	{
		"id": "repair_under_fire",
		"label": "Repair ship systems during combat",
		"category": "survival",
		"trigger_destinations": [],
		"trigger_events": ["equipment_malfunction"],
		"completion_morale_bonus": 20
	},
	{
		"id": "visit_outer_moons",
		"label": "Visit all outer system moons",
		"category": "exploration",
		"trigger_destinations": ["europa", "ganymede", "enceladus"],
		"trigger_events": [],
		"completion_morale_bonus": 30
	}
]

# Role → preferred ambition categories (weighted assignment)
const ROLE_AMBITION_AFFINITY: Dictionary = {
	"pilot":     ["exploration", "survival", "combat"],
	"engineer":  ["survival", "discovery", "repair_under_fire"],
	"scientist": ["discovery", "exploration"],
	"security":  ["combat", "survival"],
	"medic":     ["relationship", "survival"],
	"diplomat":  ["relationship", "discovery"]
}


func _init(p_rng: TillyRNG, p_crew: Array) -> void:
	rng = p_rng
	crew = p_crew


func register_callback(event_type: String, callback: Callable) -> void:
	if not event_callbacks.has(event_type):
		event_callbacks[event_type] = []
	event_callbacks[event_type].append(callback)


func assign_ambitions() -> void:
	## Assign one ambition to each crew member at game start.
	## Role affinity biases the assignment.
	
	for member in crew:
		var preferred_categories = ROLE_AMBITION_AFFINITY.get(member.role, ["exploration"])
		
		# Collect matching ambitions (preferred category first)
		var preferred: Array = []
		var fallback: Array = []
		for ambition in AMBITION_CATALOGUE:
			if ambition["category"] in preferred_categories:
				preferred.append(ambition)
			else:
				fallback.append(ambition)
		
		var pool: Array = preferred if not preferred.is_empty() else fallback
		var chosen = pool[rng.next_int(0, pool.size())]
		
		member.set_ambition(
			chosen["id"],
			chosen["label"],
			chosen["trigger_destinations"],
			chosen["trigger_events"]
		)


func notify_destination_reached(dest_id: String) -> Array:
	## Call when the ship arrives at a new destination.
	## Returns array of {crew_member, xp_gained, completed} for all crew who progressed.
	
	var results: Array = []
	for member in crew:
		if member.health <= 0:
			continue
		var xp = member.advance_ambition_by_destination(dest_id)
		if xp > 0:
			results.append({
				"crew_member": member,
				"xp_gained": xp,
				"completed": member.ambition_complete
			})
			_handle_ambition_progress(member)
	return results


func notify_event_triggered(event_id: String) -> Array:
	## Call when any event is triggered.
	## Returns progress updates for affected crew.
	
	var results: Array = []
	for member in crew:
		if member.health <= 0:
			continue
		var xp = member.advance_ambition_by_event(event_id)
		if xp > 0:
			results.append({
				"crew_member": member,
				"xp_gained": xp,
				"completed": member.ambition_complete
			})
			_handle_ambition_progress(member)
	return results


func notify_combat_victory(winner_crew: Array) -> void:
	## Special-case: advance "survive_five_combats" ambition for living crew.
	for member in winner_crew:
		if member.health <= 0:
			continue
		if member.ambition_id == "survive_five_combats":
			member.ambition_progress = min(100, member.ambition_progress + 20)
			if member.ambition_progress >= 100 and not member.ambition_complete:
				member.ambition_complete = true
				_handle_ambition_progress(member)


func _handle_ambition_progress(member: CrewPersonality) -> void:
	if member.ambition_complete:
		# Find completion bonus from catalogue
		var bonus: int = 20
		for entry in AMBITION_CATALOGUE:
			if entry["id"] == member.ambition_id:
				bonus = entry.get("completion_morale_bonus", 20)
				break
		
		member.morale = min(100, member.morale + bonus)
		_fire_callbacks("ambition_complete", member)
		print("★ %s fulfilled ambition: %s (morale +%d)" % [member.name, member.ambition_label, bonus])
	else:
		_fire_callbacks("ambition_progress", member)


func _fire_callbacks(event_type: String, member: CrewPersonality) -> void:
	if event_callbacks.has(event_type):
		for cb in event_callbacks[event_type]:
			cb.call(member)


func get_ambitions_report() -> Array:
	## Returns sorted list of crew ambition statuses.
	var report: Array = []
	for member in crew:
		report.append({
			"name": member.name,
			"role": member.role,
			"ambition": member.get_ambition_status(),
			"progress": member.ambition_progress,
			"complete": member.ambition_complete
		})
	return report
