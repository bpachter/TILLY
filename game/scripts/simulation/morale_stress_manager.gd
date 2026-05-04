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
const AFFINITY_NEUTRAL_RATE: float = 0.1  # Relationships tend toward neutral


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
		# Natural morale decay
		crew_member.morale = max(0, crew_member.morale - MORALE_DECAY_RATE)
		
		# Stress recovery (slower than morale loss)
		crew_member.recover_stress(int(STRESS_RECOVERY_RATE))
		
		# Check panic threshold
		if crew_member.stress >= PANIC_THRESHOLD and crew_member.stress - MORALE_DECAY_RATE < PANIC_THRESHOLD:
			cascades.append({
				"type": "panic_onset",
				"crew_id": crew_member.crew_id,
				"crew_member": crew_member
			})
			trigger_callbacks("panic_onset", crew_member)
		
		# Check despair threshold
		if crew_member.morale <= DESPAIR_THRESHOLD:
			cascades.append({
				"type": "morale_crisis",
				"crew_id": crew_member.crew_id,
				"crew_member": crew_member
			})
			trigger_callbacks("morale_crisis", crew_member)
		
		# Check crisis threshold (mid-range, affects decision-making)
		if crew_member.morale < CRISIS_THRESHOLD and crew_member.morale > 10:
			cascades.append({
				"type": "decision_crisis",
				"crew_id": crew_member.crew_id,
				"crew_member": crew_member
			})
			trigger_callbacks("decision_crisis", crew_member)
	
	# Relationship decay toward neutral
	for i in range(crew.size()):
		for j in range(crew.size()):
			if i != j:
				var affinity = crew[i].get_affinity(crew[j].crew_id)
				if affinity > 0:
					crew[i].modify_affinity(crew[j].crew_id, int(-AFFINITY_NEUTRAL_RATE))
				elif affinity < 0:
					crew[i].modify_affinity(crew[j].crew_id, int(AFFINITY_NEUTRAL_RATE))
				
				# Check relationship thresholds
				if affinity > BONDING_OPPORTUNITY and not (affinity - 1 > BONDING_OPPORTUNITY):
					cascades.append({
						"type": "bonding_opportunity",
						"crew_a": crew[i].crew_id,
						"crew_b": crew[j].crew_id
					})
					trigger_callbacks("bonding_opportunity", crew[i], crew[j])
				
				if affinity < CONFLICT_RISK and not (affinity + 1 < CONFLICT_RISK):
					cascades.append({
						"type": "conflict_risk",
						"crew_a": crew[i].crew_id,
						"crew_b": crew[j].crew_id
					})
					trigger_callbacks("conflict_risk", crew[i], crew[j])
	
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
		crew_member.morale = min(100, crew_member.morale + magnitude)
		crew_member.recover_stress(magnitude / 2)


func apply_emergency_stress_spike(magnitude: int = 20) -> void:
	## Emergency event (e.g., combat, threat detected) spikes stress.
	
	for crew_member in crew:
		crew_member.apply_stress(magnitude)
		crew_member.morale = max(0, crew_member.morale - magnitude / 2)


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
