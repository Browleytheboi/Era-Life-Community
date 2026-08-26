extends Resource
class_name InvestigationLayer

const CONTRACT_VERSION:= 1

var gs
var ledger: Array = []
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs

func build_evidence_packet(crime_event: Dictionary = {}) -> Dictionary:
	var crime_raw: Variant = crime_event.get("crime", {})
	var crime: Dictionary = crime_raw if typeof(crime_raw) == TYPE_DICTIONARY else {}

	var era_name: String = str(crime_event.get("era", "")).strip_edges()
	var legal_system: String = str(crime_event.get("legal_system", "")).strip_edges()
	var severity: float = clamp(float(crime.get("severity", 0.35)), 0.0, 1.0)
	var success_before_arrest: bool = bool(crime.get("success_before_arrest", false))
	var payout: int = int(crime.get("payout", 0))

	var forensics: float = _forensics_for_era(era_name)
	var witness_strength: float = clamp(0.18 + severity * 0.22, 0.0, 0.55)
	var physical_strength: float = clamp(forensics * (0.25 + severity * 0.35), 0.0, 0.75)
	var financial_strength: float = clamp(float(payout) / 50000.0, 0.0, 0.3)
	var caught_bonus: float = 0.22 if not success_before_arrest else 0.08

	var evidence_strength: float = clamp(witness_strength + physical_strength + financial_strength + caught_bonus, 0.0, 1.0)

	var evidence: Array = [
		{
			"type": "witness_packet",
			"strength": witness_strength,
			"description": "Witnesses and local reports place the accused near the event."
		},
		{
			"type": "physical_trace",
			"strength": physical_strength,
			"description": "Era-appropriate forensic traces connect the accused to the crime."
		}
	]

	if payout > 0:
		evidence.append({
			"type": "financial_trace",
			"strength": financial_strength,
			"description": "Money movement after the crime created a financial trail."
		})

	var packet:= {
		"schema": "eralife.evidence_packet",
		"version": CONTRACT_VERSION,
		"case_seed": str(crime_event.get("crime_event_id", "")),
		"legal_system": legal_system,
		"evidence_strength": evidence_strength,
		"evidence": evidence,
		"history": [
			{
				"event_name": "evidence_packet_built",
				"evidence_strength": evidence_strength,
				"at_ms": int(Time.get_ticks_msec())
			}
		],
		"built_at_ms": int(Time.get_ticks_msec())
	}

	ledger.append(packet.duplicate(true))
	last_report = packet.duplicate(true)
	return packet

func export_state() -> Dictionary:
	return {
		"schema": "eralife.investigation_layer_state",
		"version": CONTRACT_VERSION,
		"ledger": ledger.duplicate(true),
		"last_report": last_report.duplicate(true)
	}

func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return { "success": false, "reason": "InvestigationLayer import data must be a Dictionary."}

	var ledger_raw: Variant = data.get("ledger", [])
	ledger = ledger_raw.duplicate(true) if typeof(ledger_raw) == TYPE_ARRAY else []

	var report_raw: Variant = data.get("last_report", {})
	last_report = report_raw.duplicate(true) if typeof(report_raw) == TYPE_DICTIONARY else {}

	return { "success": true, "imported_at_ms": int(Time.get_ticks_msec())}

func _forensics_for_era(era_name: String) -> float:
	match str(era_name):
		"Ancient Era":
			return 0.0
		"Medieval Era":
			return 0.05
		"Industrial Era":
			return 0.2
		"Future Era":
			return 0.92
		_:
			return 0.6