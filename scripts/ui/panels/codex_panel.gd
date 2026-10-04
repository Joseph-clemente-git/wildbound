extends LodgePanel
## Codex: animals, mentors, equipment, Aether, regions, rivals, stories and
## battle records, unlocked gradually (story §32).

var _category := ""


func build(container: VBoxContainer) -> void:
	set_title("Codex")
	var entries := CodexSystem.entries()
	var categories := entries.keys()
	categories.sort()
	categories.erase("Guide")
	categories.push_front("Guide")
	if _category.is_empty() or not entries.has(_category):
		_category = "Guide"
	var tabs: Array = []
	for category: String in categories:
		tabs.append([category, category])
	set_tabs(tabs, _category, func(category: String) -> void:
		_category = category
		rebuild())
	for entry: Dictionary in entries.get(_category, []):
		card(entry["title"], entry["text"])
	if _category == "Guide":
		var replay := card("Replay the opening", "Watch Old Magnus's welcome again.")
		replay.add_child(UiKit.button("Replay", func() -> void:
			Router.go("story", {"event": "opening", "next": "lodge"})))
