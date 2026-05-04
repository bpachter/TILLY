extends Node
class_name MoraleStressManager

## Monitors crew morale and stress levels.
## Triggers cascading events when thresholds are breached.
## Provides crew state utilities (panic detection, morale decay, stress recovery).

var crew: Array = []
var event_callbacks: Dictionary = {}  # stage -> [callback_funcs]

# Cascade trigger thresholds
const PANIC_THRESHOLD: int = 75
const DESPAIR_THRESHOLD: int = 20  # Morale collapses
const CRISIS_THRESHOLD: int = 30   # Crew starts making mistakes
const BONDING_OPPORTUNITY: int = 70  # Affinity, morale high
const CONFLICT_RISK: int = -50      # Affinity very low

# Natural decay rates (per time unit)
const MORALE_DECAY_RATE: float = 0.5  # Morale drops slowly over time
const STRESS_RECOVERY_RATE: float = 1.0  # Stress recovers faster than morale drops
const AFFINITY_NEUTRAL_DELTA: int = 1  # Integer delta applied per period toward neutral

# Track per-crew active cascades to avoid re-firing every period
# Keys: "panic:{crew_id}", "morale_crisis:{crew_id}", "decision_crisis:{crew_id}"
# Pairs: "bonding:{crew_a}:{crew_b}", "conflict:{crew_a}:{crew_b}"
var _active_cascades: Dictionary = {}


func _init(p_crew: Array) -> void:
	crew = p_crew


func register_cascade_callback(cascade_type: String, callback: Callable) -> void:
	## Register callback for cascade events (panic_onset, morale_crisis, bonding_opportunity, etc.)
	if not event_callbacks.has(cascade_type):
		event_callbacks[cascade_type] = []
	event_callbacks[cascade_type].append(callback)


func advance_time_period() -> Array:
	## Simulate time passage and mood changes.
	## Returns array of triggered cascade events.
	
	var cascades: Array = []
	
	for crew_member in crew:
		if crew_member.health <= 0:
			continue  # skip dead crew
		
		var prev_morale: int = crew_member.morale
		
		# Natural morale decay
		crew_member.morale = max(0, crew_member.morale - int(MORALE_DECAY_RATE))
		
		# Stress recovery (faster than morale loss)
		crew_member.recover_stress(int(STRESS_RECOVERY_RATE))
		
		# BUG-FIX #3: Panic onset detected when crew is panicked after applying external stress.
		# advance_time_period only RECOVERS stress, so panic here means it was already active.
		# Report it as ongoing panic (first time this period).
		var panic_key = "panic:%s" % crew_member.crew_id
		if crew_member.is_panicked():
			if not _active_cascades.has(panic_key):
				_active_cascades[panic_key] = true
				cascades.append({
					"type": "panic_onset",
					"crew_id": crew_member.crew_id,
					"crew_member": crew_member
				})
				trigger_callbacks("panic_onset", crew_member)
		else:
			_active_cascades.erase(panic_key)  # Cleared once stress drops below threshold
		
		# BUG-FIX #6: Track first-time morale_crisis crossing only, not every period.
		var crisis_key = "morale_crisis:%s" % crew_member.crew_id
		if crew_member.morale <= DESPAIR_THRESHOLD:
			if not _active_cascades.has(crisis_key):
				_active_cascades[crisis_key] = true
				cascades.append({
					"type": "morale_crisis",
					"crew_id": crew_member.crew_id,
					"crew_member": crew_member
				})
				trigger_callbacks("morale_crisis", crew_member)
		else:
			_active_cascades.erase(crisis_key)
		
		# BUG-FIX #6: Track first-time decision_crisis crossing only.
		var decision_key = "decision_crisis:%s" % crew_member.crew_id
		if crew_member.morale < CRISIS_THRESHOLD and crew_member.morale > DESPAIR_THRESHOLD:
			if not _active_cascades.has(decision_key):
				_active_cascades[decision_key] = true
				cascades.append({
					"type": "decision_crisis",
					"crew_id": crew_member.crew_id,
					"crew_member": crew_member
				})
				trigger_callbacks("decision_crisis", crew_member)
		else:
			_active_cascades.erase(decision_key)
	
	# BUG-FIX #4 & #5: Iterate pairs once (j > i) and apply integer drift.
	for i in range(crew.size()):
		if crew[i].health <= 0:
			continue
		for j in range(i + 1, crew.size()):
			if crew[j].health <= 0:
				continue
			
			var affinity_ij = crew[i].get_affinity(crew[j].crew_id)
			
			# Drift both sides toward neutral by 1 (integer, BUG-FIX #4)
			if affinity_ij > 0:
				crew[i].modify_affinity(crew[j].crew_id, -AFFINITY_NEUTRAL_DELTA)
				crew[j].modify_affinity(crew[i].crew_id, -AFFINITY_NEUTRAL_DELTA)
			elif affinity_ij < 0:
				crew[i].modify_affinity(crew[j].crew_id, AFFINITY_NEUTRAL_DELTA)
				crew[j].modify_affinity(crew[i].crew_id, AFFINITY_NEUTRAL_DELTA)
			
			# BUG-FIX #5: Cascade keys are symmetric so each pair fires at most once.
			var pair_key_a = "%s:%s" % [crew[i].crew_id, crew[j].crew_id]
			var pair_key_b = "%s:%s" % [crew[j].crew_id, crew[i].crew_id]
			
			var re_read_affinity = crew[i].get_affinity(crew[j].crew_id)
			
			var bond_key = "bonding:%s" % pair_key_a
			if re_read_affinity > BONDING_OPPORTUNITY:
				if not _active_cascades.has(bond_key):
					_active_cascades[bond_key] = true
					cascades.append({
						"type": "bonding_opportunity",
						"crew_a": crew[i].crew_id,
						"crew_b": crew[j].crew_id
					})
					trigger_callbacks("bonding_opportunity", crew[i], crew[j])
			else:
				_active_cascades.erase(bond_key)
			
			var conflict_key = "conflict:%s" % pair_key_a
			if re_read_affinity < CONFLICT_RISK:
				if not _active_cascades.has(conflict_key):
					_active_cascades[conflict_key] = true
					cascades.append({
						"type": "conflict_risk",
						"crew_a": crew[i].crew_id,
						"crew_b": crew[j].crew_id
					})
					trigger_callbacks("conflict_risk", crew[i], crew[j])
			else:
				_active_cascades.erase(conflict_key)
	
	return cascades


func get_crew_status_report() -> Dictionary:
	## Returns snapshot of crew psychological state.
	
	var report: Dictionary = {
		"crew_members": []
	}
	
	var total_morale: int = 0
	var total_stress: int = 0
	var panic_count: int = 0
	var crisis_count: int = 0
	
	for crew_member in crew:
		var member_status = {
			"crew_id": crew_member.crew_id,
			"name": crew_member.name,
			"morale": crew_member.morale,
			"stress": crew_member.stress,
			"health": crew_member.health,
			"status": get_crew_status_string(crew_member),
			"affinity_matrix": crew_member.relationship_matrix.duplicate()
		}
		report["crew_members"].append(member_status)
		
		total_morale += crew_member.morale
		total_stress += crew_member.stress
		
		if crew_member.is_panicked():
			panic_count += 1
		if crew_member.morale < CRISIS_THRESHOLD:
			crisis_count += 1
	
	var crew_count = max(1, crew.size())
	report["average_morale"] = total_morale / crew_count
	report["average_stress"] = total_stress / crew_count
	report["panic_count"] = panic_count
	report["crisis_count"] = crisis_count
	report["crew_health"] = "NOMINAL" if crisis_count == 0 else ("WARNING" if panic_count == 0 else "CRITICAL")
	
	return report


func get_crew_status_string(crew_member: CrewPersonality) -> String:
	## Human-readable status description.
	
	if crew_member.health <= 0:
		return "DECEASED"
	if crew_member.is_panicked():
		return "PANICKED"
	if crew_member.morale <= DESPAIR_THRESHOLD:
		return "DESPAIRING"
	if crew_member.morale < CRISIS_THRESHOLD:
		return "STRESSED"
	if crew_member.morale > 80 and crew_member.stress < 20:
		return "EXCELLENT"
	if crew_member.morale > 60:
		return "HEALTHY"
	return "CONCERNED"


func apply_emergency_morale_boost(magnitude: int = 15) -> void:
	## Emergency event (e.g., crew bonding dinner, significant discovery) boosts morale.
	
	for crew_member in crew:
		if crew_member.health <= 0:
			continue
		crew_member.morale = min(100, crew_member.morale + magnitude)
		crew_member.recover_stress(magnitude / 2)


func apply_emergency_stress_spike(magnitude: int = 20) -> void:
	## Emergency event (e.g., combat, threat detected) spikes stress.
	
	for crew_member in crew:
		if crew_member.health <= 0:
			continue
		crew_member.apply_stress(magnitude)
		crew_member.morale = max(0, crew_member.morale - magnitude / 2)


func handle_crew_death(dead_member: CrewPersonality) -> void:
	## Called when a crew member dies. Applies morale penalty to survivors.
	## Triggers crew_death cascade for registered listeners.
	
	for crew_member in crew:
		if crew_member.crew_id == dead_member.crew_id:
			continue
		if crew_member.health <= 0:
			continue
		# Morale hit scales with affinity: base -15, extra -10 if they were close
		var affinity = crew_member.get_affinity(dead_member.crew_id)
		var morale_hit: int = 15 + (10 if affinity > 40 else 0)
		crew_member.morale = max(0, crew_member.morale - morale_hit)
		crew_member.apply_stress(20)
	
	var death_key = "death:%s" % dead_member.crew_id
	_active_cascades[death_key] = true
	trigger_callbacks("crew_death", dead_member)


func trigger_callbacks(cascade_type: String, arg1: Variant = null, arg2: Variant = null) -> void:
	## Invoke all registered callbacks for this cascade type.
	
	if event_callbacks.has(cascade_type):
		for callback in event_callbacks[cascade_type]:
			callback.call(arg1, arg2)


func diagnose_crew_crisis() -> String:
	## Analyze crew state and suggest intervention.
	
	var report = get_crew_status_report()
	var diagnoses: Array = []
	
	if report.get("panic_count", 0) > 0:
		diagnoses.append("Multiple crew panicked - recommend immediate morale event")
	
	if report.get("crisis_count", 0) >= crew.size():
		diagnoses.append("CRITICAL: Entire crew in crisis - consider emergency destination")
	
	var avg_morale = report.get("average_morale", 50)
	if avg_morale < 30:
		diagnoses.append("Crew morale critically low - suggest social event (dinner, celebration)")
	
	var avg_stress = report.get("average_stress", 50)
	if avg_stress > 70:
		diagnoses.append("Crew stress extremely high - recommend rest period or exploration (change of pace)")
	
	if diagnoses.is_empty():
		return "Crew status nominal"
	else:
		return " | ".join(diagnoses)
