extends CanvasLayer

## HUD displaying player health bar.

@onready var health_bar_bg: ColorRect = $HealthBar/Background
@onready var health_bar_fill: ColorRect = $HealthBar/Fill
@onready var health_label: Label = $HealthBar/HealthLabel


func _ready() -> void:
	EventBus.player_health_changed.connect(_on_health_changed)
	# Initialize display
	_update_display(GameState.player_current_health, GameState.player_max_health)


func _on_health_changed(current: int, maximum: int) -> void:
	_update_display(current, maximum)


func _update_display(current: int, maximum: int) -> void:
	var ratio := float(current) / float(maximum)
	health_bar_fill.size.x = health_bar_bg.size.x * ratio

	# Color: green > 50%, yellow 25-50%, red < 25%
	if ratio > 0.5:
		health_bar_fill.color = Color(0.1, 0.8, 0.2, 1)
	elif ratio > 0.25:
		health_bar_fill.color = Color(1.0, 0.8, 0.1, 1)
	else:
		health_bar_fill.color = Color(0.9, 0.15, 0.15, 1)

	health_label.text = "%d / %d" % [current, maximum]
