class_name VoiceCueRegistry
extends RefCounted
## Presentation-only voice metadata. These IDs are derived from authored story identity, never
## from prose, and are not serialized into GameState or included in command/event checksums.

const DEFAULT_LOCALE: String = "en"


## Builds the stable cue for one event step without changing the event payload. The optional
## asset is named from chain/step so an intake batch can add it later without touching simulation
## data; until then the cue remains fully usable as written dialogue.
static func event_cue(chain_id: String, step: int, step_data: Dictionary, locale: String = DEFAULT_LOCALE) -> Dictionary:
	var chain: String = chain_id.strip_edges()
	var n: int = maxi(step, 1)
	if chain.is_empty():
		return {}
	return normalize({
		"utterance_id": "event/%s/%d" % [chain, n],
		"speaker": DictIO.str_of(step_data, "speaker"),
		"text_key": DictIO.str_of(step_data, "body_key"),
		"story_chain": chain,
		"story_step": n,
		"locale": locale if not locale.strip_edges().is_empty() else DEFAULT_LOCALE,
		"asset_id": "voice_%s_%d" % [chain.replace("-", "_"), n],
	})


## A non-event presentation cue can use the same lifecycle while keeping a stable authored ID.
static func presentation_cue(utterance_id: String, speaker: String, text_key: String, asset_id: String = "", locale: String = DEFAULT_LOCALE) -> Dictionary:
	return normalize({
		"utterance_id": utterance_id,
		"speaker": speaker,
		"text_key": text_key,
		"story_chain": "",
		"story_step": 0,
		"locale": locale if not locale.strip_edges().is_empty() else DEFAULT_LOCALE,
		"asset_id": asset_id,
	})


## Normalizes a cue at the presentation boundary. Unknown metadata is retained for tooling, but
## the service only trusts the stable identity and optional manifest asset ID below.
static func normalize(raw: Dictionary) -> Dictionary:
	var cue: Dictionary = raw.duplicate(true)
	cue["utterance_id"] = str(cue.get("utterance_id", "")).strip_edges()
	cue["speaker"] = str(cue.get("speaker", "")).strip_edges()
	cue["text_key"] = str(cue.get("text_key", "")).strip_edges()
	cue["story_chain"] = str(cue.get("story_chain", "")).strip_edges()
	cue["story_step"] = maxi(int(cue.get("story_step", 0)), 0)
	cue["locale"] = str(cue.get("locale", DEFAULT_LOCALE)).strip_edges()
	if str(cue["locale"]).is_empty():
		cue["locale"] = DEFAULT_LOCALE
	cue["asset_id"] = str(cue.get("asset_id", "")).strip_edges()
	return cue


static func valid(cue: Dictionary) -> bool:
	var n: Dictionary = normalize(cue)
	return not str(n.get("utterance_id", "")).is_empty() and not str(n.get("text_key", "")).is_empty()
