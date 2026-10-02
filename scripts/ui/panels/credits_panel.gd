class_name CreditsPanel
extends RefCounted
## Credits dialog.


static func open(parent: Node) -> void:
	var content := UiKit.modal(parent, "Credits", 640.0)
	content.add_child(UiKit.rich(
			"[center][b]WILDBOUND[/b]\nChronicles of the Aether\n\n"
			+ "Game design & story — the Wildbound team\n"
			+ "Built with [color=#e3a857]Godot Engine[/color]\n"
			+ "Characters and world are procedural placeholders\nfor the Blender production assets.\n\n"
			+ "[i]For every champion who learned by living.[/i][/center]"))
	var row := UiKit.hbox()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiKit.primary_button("Close", func() -> void: UiKit.close_modal(content), 200))
	content.add_child(row)
