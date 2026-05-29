extends CharacterBody2D

## Enemy with FSM: IDLE -> CHASE -> HURT -> DEAD
## Data-driven via EnemyStats resource.

enum State { IDLE, CHASE, HURT, DEAD }

@export var stats: Resource

var current_health: int = 0
var current_state: State = State.IDLE
var is_invincible: bool = false
var player_ref: CharacterBody2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar_bg: ColorRect = $HealthBar/Background
@onready var health_bar_fill: ColorRect = $HealthBar/Fill
@onready var hurt_timer: Timer = $HurtTimer
@onready var death_timer: Timer = $DeathTimer
@onready var attack_area: Area2D = $AttackArea
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemy")

	if stats == null:
		stats = load("res://resources/enemies/basic_enemy.tres") 

	current_health = stats.max_health
	current_state = State.IDLE

	# Create placeholder texture
	_create_placeholder_texture()
	# Set size from stats
	sprite.scale = stats.size / 32.0
	_update_health_bar()

	# Find player reference
	player_ref = get_tree().get_first_node_in_group("player") as CharacterBody2D

	# Connect signals
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	hurt_timer.timeout.connect(_on_hurt_finished)
	death_timer.timeout.connect(_on_death_finished)


func _physics_process(_delta: float) -> void:
	match current_state:
		State.DEAD:
			return
		State.HURT:
			return

	# IDLE and CHASE: move toward player
	if player_ref and is_instance_valid(player_ref):
		var direction := (player_ref.global_position - global_position).normalized()
		velocity = direction * stats.move_speed
		if current_state == State.IDLE:
			current_state = State.CHASE
	else:
		velocity = Vector2.ZERO

	# Face direction of movement
	if velocity.length() > 10:
		sprite.rotation = velocity.angle()

	move_and_slide()


func take_damage(amount: int) -> void:
	if is_invincible or current_state == State.DEAD:
		return

	current_health = max(0, current_health - amount)
	EventBus.enemy_hit.emit(self, amount)
	_update_health_bar()

	if current_health <= 0:
		_die()
	else:
		_enter_hurt()


func _enter_hurt() -> void:
	current_state = State.HURT
	is_invincible = true

	# Knockback
	if player_ref and is_instance_valid(player_ref):
		var knockback_dir := (global_position - player_ref.global_position).normalized()
		velocity = knockback_dir * 150.0

	# Flash white
	sprite.modulate = Color.WHITE
	hurt_timer.start()


func _on_hurt_finished() -> void:
	if current_state == State.DEAD:
		return
	current_state = State.CHASE
	is_invincible = false
	sprite.modulate = Color.WHITE


func _die() -> void:
	current_state = State.DEAD
	collision_shape.set_deferred("disabled", true)
	attack_area.monitoring = false
	sprite.modulate = Color(0.4, 0.4, 0.4, 0.5)
	death_timer.start()


func _on_death_finished() -> void:
	EventBus.enemy_died.emit(self)
	queue_free()


func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(stats.contact_damage)


func _update_health_bar() -> void:
	var ratio := float(current_health) / float(stats.max_health)
	health_bar_fill.size.x = health_bar_bg.size.x * ratio
	# Color: green > 50%, yellow 25-50%, red < 25%
	if ratio > 0.5:
		health_bar_fill.color = Color.GREEN
	elif ratio > 0.25:
		health_bar_fill.color = Color.YELLOW
	else:
		health_bar_fill.color = Color.RED


func _create_placeholder_texture() -> void:
	# Enemy body - colored square with border
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(stats.color)
	# Darker border
	var border_color = stats.color.darkened(0.4)
	for x in 32:
		img.set_pixel(x, 0, border_color)
		img.set_pixel(x, 31, border_color)
	for y in 32:
		img.set_pixel(0, y, border_color)
		img.set_pixel(31, y, border_color)
	# Simple "eyes"
	img.set_pixel(8, 10, Color.WHITE)
	img.set_pixel(8, 20, Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(img)
