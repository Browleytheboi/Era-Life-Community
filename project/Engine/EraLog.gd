extends RefCounted
class_name EraLog

# Central gate for EraLife's diagnostic logging.
#
# The project had 239 bare print() calls, none of them gated, all of them
# shipping in release builds. Printing to stdout happens on the main thread and
# is not cheap: a busy frame in the crime pipeline could emit dozens of lines,
# which costs frame time and buries anything you actually want to read.
#
# Every diagnostic print now routes through EraLog.truth(). Default behaviour:
#
#   editor / debug build  -> logging ON
#   exported release build -> logging OFF
#
# Override at launch with a command line flag (works on the exported binary too):
#
#   EraLife.exe --eralife-logs      # force logging ON  (e.g. reproducing a bug)
#   EraLife.exe --no-eralife-logs   # force logging OFF
#
# Or toggle at runtime from anywhere, including the remote shell:
#
#   EraLog.set_enabled(true)

const FORCE_ENABLE_ARG: String = "--eralife-logs"
const FORCE_DISABLE_ARG: String = "--no-eralife-logs"

static var _resolved: bool = false
static var _enabled: bool = false


static func enabled() -> bool:
	if not _resolved:
		_resolved = true
		var args: PackedStringArray = OS.get_cmdline_args()
		if FORCE_ENABLE_ARG in args:
			_enabled = true
		elif FORCE_DISABLE_ARG in args:
			_enabled = false
		else:
			_enabled = OS.is_debug_build()
	return _enabled


static func set_enabled(value: bool) -> void:
	_resolved = true
	_enabled = bool(value)


# --- Failure tally -----------------------------------------------------------
#
# Counting is ALWAYS on, even when logging is gated off, because the counters are
# cheap (a dictionary increment) and they are what makes a failure visible during
# normal play without a console attached. The log line still respects enabled().

static var _failure_counts: Dictionary = {}
static var _failure_total: int = 0
static var _failure_recent: Array = []

const FAILURE_RECENT_LIMIT: int = 40


static func failure(engine: String, reason: String) -> void:
	var key: String = "%s|%s" % [str(engine), str(reason)]
	_failure_counts [key] = int(_failure_counts.get(key, 0)) + 1
	_failure_total += 1

	_failure_recent.append({
		"engine": str(engine),
		"reason": str(reason),
		"at_ms": int(Time.get_ticks_msec())
	})

	while _failure_recent.size() > FAILURE_RECENT_LIMIT:
		_failure_recent.pop_front()

	truth(
		"ERALIFE_FAILURE|engine=%s|reason=%s" % [str(engine), str(reason)]
	)


static func failure_summary() -> Dictionary:
	var rows: Array = []

	for raw_key in _failure_counts.keys():
		var parts: PackedStringArray = str(raw_key).split("|")
		rows.append({
			"engine": parts[0] if parts.size() > 0 else "",
			"reason": parts[1] if parts.size() > 1 else "",
			"count": int(_failure_counts.get(raw_key, 0))
		})

	rows.sort_custom(
		func(a, b): return int(a.get("count", 0)) > int(b.get("count", 0))
	)

	return {
		"schema": "eralife.failure_tally",
		"total": _failure_total,
		"distinct": _failure_counts.size(),
		"rows": rows,
		"recent": _failure_recent.duplicate(true)
	}


static func reset_failures() -> void:
	_failure_counts = {}
	_failure_total = 0
	_failure_recent = []


# --- Stall watchdog ----------------------------------------------------------
#
# The failure tally above catches functions that RETURN a failure. It cannot catch
# the shape that is far more expensive to debug: a function that quietly claims a
# piece of work and then returns without doing it, or without scheduling anything
# to continue it. There is no failure result to count -- the work simply stops, and
# the only symptom is a UI that never updates.
#
# Instead of trying to instrument 7,000 early returns, a system declares work with
# watch_begin(), reports forward motion with watch_progress(), and clears it with
# watch_end(). Anything still outstanding and untouched past the stall threshold is
# reported once. That catches the abandonment no matter which return caused it.

static var _watched: Dictionary = {}

const WATCH_STALL_MS: int = 4000


static func watch_begin(work_id: String, label: String = "") -> void:
	var now_ms: int = int(Time.get_ticks_msec())
	_watched [str(work_id)] = {
		"label": str(label),
		"began_at_ms": now_ms,
		"progressed_at_ms": now_ms,
		"steps": 0,
		"reported": false
	}


static func watch_progress(work_id: String) -> void:
	var key: String = str(work_id)
	if not _watched.has(key):
		return

	var entry: Dictionary = _watched [key]
	entry ["progressed_at_ms"] = int(Time.get_ticks_msec())
	entry ["steps"] = int(entry.get("steps", 0)) + 1
	_watched [key] = entry


static func watch_end(work_id: String) -> void:
	_watched.erase(str(work_id))


static func watch_sweep(stall_ms: int = WATCH_STALL_MS) -> Array:
	var now_ms: int = int(Time.get_ticks_msec())
	var stalled: Array = []

	for raw_key in _watched.keys():
		var entry: Dictionary = _watched [raw_key]

		if bool(entry.get("reported", false)):
			continue

		var idle_ms: int = now_ms - int(entry.get("progressed_at_ms", now_ms))
		if idle_ms < stall_ms:
			continue

		entry ["reported"] = true
		_watched [raw_key] = entry

		stalled.append({
			"work_id": str(raw_key),
			"label": str(entry.get("label", "")),
			"idle_ms": idle_ms,
			"steps": int(entry.get("steps", 0))
		})

		# A stall is a failure that never announced itself, so it lands in the same
		# tally as an explicit failure result.
		failure(
			"StallWatchdog",
			"%s_stalled_after_%d_steps" % [
				str(entry.get("label", "work")),
				int(entry.get("steps", 0))
			]
		)

		truth(
			"ERALIFE_STALLED|work=%s|label=%s|idle_ms=%d|steps=%d"
			% [
				str(raw_key),
				str(entry.get("label", "")),
				idle_ms,
				int(entry.get("steps", 0))
			]
		)

	return stalled


# Diagnostic line. Accepts the same shapes the old print() calls used, including
# the eight two-argument sites (e.g. print("AGEUP_TRUTH|", packet)).
static func truth(
	a = "",
	b = null,
	c = null,
	d = null,
	e = null
) -> void:
	if not enabled():
		return

	var text: String = str(a)
	if b != null:
		text += str(b)
	if c != null:
		text += str(c)
	if d != null:
		text += str(d)
	if e != null:
		text += str(e)

	print(text)
