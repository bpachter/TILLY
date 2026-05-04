extends Node
class_name CrewMentalHealthManager

## Manages crew psychological conditions beyond morale/stress.
## Phobias develop from sustained high-stress exposure in specific contexts.
## Therapy events can reduce or remove phobias.
## Active phobias apply event-specific success penalties.

var crew: Array = []
var rng: TillyRNG
var event_callbacks: Dictionary = {}

# How many consecutive high-stress periods before a phobia forms
const PHOBIA_FORMATION_THRESHOLD: int = 3
# Stress level considered "high" for phobia exposure tracking
const HIGH_STRESS_LEVEL: int = 65

# --- Phobia definitions ---
# Each phobia:
#   id          - unique key
#   label       - display name
#   trigger_context - what causes exposure ticking ("combat", "transit", "deep_space")
#   penalty_events  - event IDs where this phobia applies a penalty
#   penalty_amount  - probability penalty on those events (-0.0 to -0.3)
const PHOBIA_CATALOGUE: Array = [
	{
		"id": "combat_ptsd",
		"label": "Combat PTSD",
		"trigger_context": "combat",
		"penalty_events": ["board_attempt", "rescue_mission"],
		"penalty_amount": -0.25
	},
	{
		"id": "void_agoraphobia",
		"label": "Void Agoraphobia",
		"trigger_context": "deep_space",
		"penalty_events": ["anomaly_detection", "gravity_anomaly", "silent_probe_ping"],
		"penalty_amount": -0.20
	},
	{
		"id": "claustrophobia",
		"label": "Claustrophobia",
		"trigger_context": "equipment",
		"penalty_events": ["equipment_malfunction", "experimental_upgrade"],
		"penalty_amount": -0.15
	},
	{
		"id": "xenophobia",
		"label": "Xenophobia",
		"trigger_context": "alien_contact",
		"penalty_events": ["encrypted_distress_signal", "rogue_ai_contact", "silent_probe_ping"],
		"penalty_amount": -0.20
	},
	{
		"id": "social_anxiety",
		"label": "Social Anxiety",
		"trigger_context": "social",
		"penalty_events": ["crew_bonding_dinner", "crew_conflict", "quiet_night_reflection"],
		"penalty_amount": -0.15
	}
]

# Contexts that can trigger phobia formation
# Maps context_id -> list of phobia IDs that could develop
const CONTEXT_PHOBIA_MAP: Dictionary = {
	"combat":        ["combat_ptsd"],
	"deep_space":    ["void_agoraphobia"],
	"equipment":     ["claustrophobia"],
	"alien_contact": ["xenophobia"],
	"social":        ["social_anxiety"]
}

# Therapy events that reduce phobia severity
const THERAPY_EVENTS: Array = [
	"crew_bonding_dinner",
	"quiet_night_reflection",
	"garden_harvest"
]


func _init(p_rng: TillyRNG, p_crew: Array) -> void:
	rng = p_rng
	crew = p_crew


func register_callback(event_type: String, callback: Callable) -> void:
	if not event_callbacks.has(event_type):
		event_callbacks[event_type] = []
	event_callbacks[event_type].append(callback)


func tick_phobia_exposure(context: String) -> void:
	## Called after any sustained high-stress experience in a given context.
	## Stressed crew members accumulate exposure toward phobia formation.
	
	var candidate_phobias = CONTEXT_PHOBIA_MAP.get(context, [])
	if candidate_phobias.is_empty():
		return
	
	for member in crew:
		if member.health <= 0:
			continue
		if member.stress < HIGH_STRESS_LEVEL:
			# Not stressed enough; reset exposure counter
			for phobia_id in candidate_phobias:
				member.reset_phobia_exposure(phobia_id)
			continue
		
		# Stressed in the right context — tick exposure
		for phobia_id in candidate_phobias:
			if member.has_phobia(phobia_id):
				continue  # Already has this phobia
			
			member.tick_phobia_exposure(phobia_id)
			var count: int = member.phobia_exposure_count.get(phobia_id, 0)
			
			if count >= PHOBIA_FORMATION_THRESHOLD:
				_form_phobia(member, phobia_id)


func _form_phobia(member: CrewPersonality, phobia_id: String) -> void:
	member.add_phobia(phobia_id)
	member.reset_phobia_exposure(phobia_id)
	
	# Find label for logging
	var label: String = phobia_id
	for entry in PHOBIA_CATALOGUE:
		if entry["id"] == phobia_id:
			label = entry["label"]
			break
	
	print("⚠ %s has developed: %s" % [member.name, label])
	_fire_callbacks("phobia_formed", member, phobia_id)


func apply_therapy_event(event_id: String) -> void:
	## Therapy events reduce exposure counters and have a chance to heal phobias.
	
	if event_id not in THERAPY_EVENTS:
		return
	
	for member in crew:
		if member.health <= 0:
			continue
		
		# Reset all exposure counters (break the cycle)
		member.phobia_exposure_count.clear()
		
		# 25% chance to cure a random active phobia
		if not member.phobias.is_empty() and rng.next_float() < 0.25:
			var idx = rng.next_int(0, member.phobias.size())
			var cured = member.phobias[idx]
			member.remove_phobia(cured)
			member.morale = min(100, member.morale + 10)
			print("✓ %s overcame %s" % [member.name, cured])
			_fire_callbacks("phobia_cured", member, cured)


func get_phobia_event_penalty(member: CrewPersonality, event_id: String) -> float:
	## Returns total probability penalty from active phobias for a given event.
	
	var total_penalty: float = 0.0
	for phobia_id in member.phobias:
		for entry in PHOBIA_CATALOGUE:
			if entry["id"] == phobia_id and event_id in entry["penalty_events"]:
				total_penalty += entry["penalty_amount"]
				break
	return total_penalty


func get_crew_phobia_report() -> Array:
	## Returns summary of each living crew member's active phobias.
	var report: Array = []
	for member in crew:
		if member.health <= 0:
			continue
		report.append({
			"name": member.name,
			"phobias": member.phobias.duplicate(),
			"exposure_counts": member.phobia_exposure_count.duplicate()
		})
	return report


func _fire_callbacks(event_type: String, member: CrewPersonality, payload: Variant = null) -> void:
	if event_callbacks.has(event_type):
		for cb in event_callbacks[event_type]:
			cb.call(member, payload)
