class_name CreditsScreen
extends FlowScreen
## Credits (§14): CREDITS.md as it stands in the repository (the engine, fonts and every delivered
## batch of sound, music and art with its licence), shown as text so the screen can never drift
## from the file.

const PATH: String = "res://CREDITS.md"


static func make(p_back: String = AppRoot.TITLE) -> CreditsScreen:
	var s: CreditsScreen = CreditsScreen.new()
	s.name = "CreditsScreen"
	s.back_route = p_back
	return s


func build_screen() -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", Tokens.SPACE_L)
	frame.add_child(col)
	col.add_child(header(Strings.fmt("ui.credits.title")))
	var rt: RichTextLabel = RichTextLabel.new()
	rt.name = "CreditsText"
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_color_override("default_color", Tokens.color("text.primary"))
	rt.text = to_bbcode(FileAccess.get_file_as_string(PATH))
	# Versions, years and licence numbers are the credits' own text.
	rt.set_meta("audit_numeric_ok", "the credits' own text")
	col.add_child(FlowScreen.scroll_of(rt))


## The little Markdown CREDITS.md uses, as BBCode: headings, bullets, bold and code.
static func to_bbcode(md: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	var bold: RegEx = RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
	var code: RegEx = RegEx.create_from_string("`(.+?)`")
	for line: String in md.replace("[", "[lb]").split("\n"):
		var l: String = line
		if l.begins_with("## "):
			l = "\n[b]" + l.trim_prefix("## ") + "[/b]"
		elif l.begins_with("# "):
			l = "[b]" + l.trim_prefix("# ") + "[/b]"
		elif l.begins_with("- "):
			l = "• " + l.trim_prefix("- ")
		elif l.begins_with("  "):
			l = "   " + l.strip_edges()
		l = bold.sub(l, "[b]$1[/b]", true)
		l = code.sub(l, "$1", true)
		out.append(l)
	return "\n".join(out)
