extends SceneTree
## Writes every synthesised fallback sound (§15.4) to WAV for a listening check, and prints a
## level report: length and peak per id. Delivered sounds are not included; they have their own
## report at intake (§15.2).
##   godot --headless --path . -s tools/audio_preview.gd -- [--out build/audio_preview]


func _initialize() -> void:
	var out: String = "build/audio_preview"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out)
	var written: int = 0
	var failed: int = 0
	for id: String in SoundSynth.RECIPES.keys():
		var st: AudioStreamWAV = SoundSynth.stream(id)
		var err: Error = st.save_to_wav(out.path_join(id + ".wav"))
		if err != OK:
			failed += 1
			printerr("audio_preview: could not write %s (%s)" % [id, error_string(err)])
			continue
		written += 1
		print("%-20s %5.2f s  peak %4.2f  %s" % [id, SoundSynth.length_of(st), SoundSynth.peak_of(st), "effects" if SoundSynth.GAME_SOUNDS.has(id) else "ui"])
	print("audio_preview: %d sound(s) written to %s; silent until delivered: %s" % [written, out, ", ".join(SoundSynth.BEDS)])
	quit(1 if failed > 0 else 0)
