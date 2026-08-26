extends RefCounted
class_name EraUtils

# Single source of truth for the safe-cast helpers that were copy-pasted into
# ~120 engines. Local _safe_dictionary/_safe_array functions now delegate here
# instead of each carrying their own body.
#
# IMPORTANT: only the DEEP-COPY variants were consolidated. The original codebase
# contained three different semantics under the same name:
#
#   deep copy    .duplicate(true)   ~103 files  -> consolidated here
#   shallow copy .duplicate(false)     3 files  -> left alone
#   no copy      returns live reference 16 files -> left alone
#
# The no-copy versions return an alias, so callers that mutate the result are
# mutating the original. Rewriting those to deep copy would silently break them.
# They are listed in the audit at the bottom of this file if you ever want to
# reconcile them deliberately.


static func days_in_month(month: int, year: int = 0) -> int:
	# Birth dates were clamped with clampi(day, 1, 31) regardless of month, so
	# February 31st and April 31st were accepted everywhere a birthday is set.
	var clean_month: int = clampi(int(month), 1, 12)

	if clean_month == 2:
		var clean_year: int = int(year)
		var leap: bool = (
			clean_year % 4 == 0
			and (
				clean_year % 100 != 0
				or clean_year % 400 == 0
			)
		)
		return 29 if leap else 28

	if clean_month in [4, 6, 9, 11]:
		return 30

	return 31


static func clamp_day_for_month(day: int, month: int, year: int = 0) -> int:
	return clampi(
		int(day),
		1,
		days_in_month(month, year)
	)


static func safe_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}


static func safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []


# --- Remaining divergence ------------------------------------------------
#
# All 25 aliasing (_live_*) helpers were reviewed site by site and converted to
# deep copy; every mutating site already wrote its result back explicitly, so the
# conversion was behaviour preserving. _live_dictionary / _live_array no longer
# exist anywhere in the project.
#
# Still NOT consolidated -- these return a SHALLOW copy (.duplicate(false)),
# which differs from a deep copy for nested containers:
#   _shallow_dictionary: UniversalSwitchContractEngine, RelationshipsHubContractEngine, CrimePanel
#   _shallow_array:      RelationshipsHubContractEngine
#
# One behaviour note from the conversion: BendingDojoEngine._dojo_reputation_row()
# is a read helper that used to write "tier_label" into state as a side effect of
# the alias. Nothing read that persisted value -- every consumer goes through the
# function, which recomputes it from renown -- so the side effect is gone.
