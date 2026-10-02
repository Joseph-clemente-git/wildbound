class_name PanelHost
extends Control
## Hosts lodge sub-screens as side sheets over the 3D lodge, keeping the
## world visible (story §45: panels instead of new scenes).

signal closed

## panel id -> script path of a LodgePanel subclass
const PANELS := {
	"champion": "res://scripts/ui/panels/champion_panel.gd",
	"skills": "res://scripts/ui/panels/champion_panel.gd",
	"training": "res://scripts/ui/panels/training_panel.gd",
	"trainers": "res://scripts/ui/panels/trainers_panel.gd",
	"equipment": "res://scripts/ui/panels/equipment_panel.gd",
	"aether": "res://scripts/ui/panels/aether_panel.gd",
	"recovery": "res://scripts/ui/panels/recovery_panel.gd",
	"journey": "res://scripts/ui/panels/journey_panel.gd",
	"codex": "res://scripts/ui/panels/codex_panel.gd",
}

var lodge: Node
var _current: LodgePanel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()


func has_open_panel() -> bool:
	return _current != null and is_instance_valid(_current)


func open(panel_id: String, options: Dictionary = {}) -> void:
	close()
	if not PANELS.has(panel_id) or not ResourceLoader.exists(PANELS[panel_id]):
		UiKit.toast(self, "That part of the lodge is still being prepared.", UiTheme.WARN)
		return
	var script: GDScript = load(PANELS[panel_id])
	_current = script.new()
	_current.host = self
	_current.panel_id = panel_id
	_current.options = options
	add_child(_current)
	_current.close_requested.connect(close)


func close() -> void:
	if has_open_panel():
		_current.queue_free()
		_current = null
		Sfx.play("ui_back")
		closed.emit()


## Switch to another panel (e.g. "Train" from the champion panel).
func switch_to(panel_id: String, options: Dictionary = {}) -> void:
	open(panel_id, options)
