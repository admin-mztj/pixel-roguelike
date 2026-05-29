extends CharacterBody2D

## Player controller: movement, aiming, melee attack, and dodge.

# Movement
const MOVE_SPEED := 200.0
const DASH_SPEED := 600.0

# Attack
const ATTACK_COOLDOWN := 0.4
const ATTACK_RANGE := 40.0
const ATTACK_DAMAGE := 15

# Dodge
const DASH_DURATION := 0.15
const DASH_COOLDOWN := 3.0

# Invincibility after taking damage
const HURT_IFRAMES := 0.5

# State flags
var is_dashing: bool = false
var can_attack: bool = true
var can_dodge: bool = true
var is_invincible: bool = false
var aim_direction: Vector2 = Vector2.RIGHT

# Nodes
@onready var sprite: Sprite2D = $Sprite2D
@onready var aim_indicator: Sprite2D = $AimIndicator
@onready var attack_area: Area2D = $AttackArea
@onready var attack_cooldown: Timer = $AttackCooldown
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown: Timer = $DashCooldown
@onready var hurt_timer: Timer = $HurtTimer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("player")
	# Generate placeholder textures
	_create_placeholder_textures()
	# Disable attack area until used
	attack_area.monitoring = false
	attack_area.monitorable = false
	_remove_attack_area_from_world()
	# Connect timers
	attack_cooldown.timeout.connect(_on_attack_cooldown_finished)
	dash_timer.timeout.connect(_on_dash_finished)
	dash_cooldown.timeout.connect(_on_dash_ready)
	hurt_timer.timeout.connect(_on_hurt_invincibility_finished)
	# Connect attack hit detection
	attack_area.body_entered.connect(_on_attack_hit)
	# Init health
	GameState.reset()
	# Position player at center of room
	global_position = _get_room_center()


func _create_placeholder_textures() -> void:
	# Player body - blue square with border
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.3, 0.9, 1.0))
	# White border
	for x in 32:
		img.set_pixel(x, 0, Color.WHITE)
		img.set_pixel(x, 31, Color.WHITE)
	for y in 32:
		img.set_pixel(0, y, Color.WHITE)
		img.set_pixel(31, y, Color.WHITE)
	# Eyes to show direction
	img.set_pixel(22, 10, Color.WHITE)
	img.set_pixel(22, 20, Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(img)

	# Aim indicator - small white dot
	var aim_img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	aim_img.fill(Color(1, 1, 1, 0))
	aim_img.fill_rect(Rect2i(2, 2, 4, 4), Color.WHITE)
	aim_indicator.texture = ImageTexture.create_from_image(aim_img)


func _physics_process(_delta: float) -> void:
	# Calculate aim direction from mouse position
	var mouse_pos := get_global_mouse_position()
	aim_direction = (mouse_pos - global_position).normalized()
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	_update_aim_indicator()

	# Movement
	if is_dashing:
		# During dash, velocity is locked
		move_and_slide()
		return

	# Read input
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * MOVE_SPEED

	# Rotate sprite to face aim direction
	sprite.rotation = aim_direction.angle()

	move_and_slide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		if can_attack and not is_dashing:
			_perform_attack()

	if event.is_action_pressed("dodge"):
		if can_dodge:
			_perform_dodge()


func _perform_attack() -> void:
	can_attack = false
	attack_cooldown.start()

	# Place attack hitbox in world space in front of player
	var attack_parent := attack_area.get_parent()
	if attack_parent != get_tree().current_scene:
		attack_area.reparent(get_tree().current_scene, false)

	attack_area.global_position = global_position + aim_direction * ATTACK_RANGE
	attack_area.rotation = aim_direction.angle()
	attack_area.monitoring = true

	# Brief hit window, then remove
	await get_tree().create_timer(0.1).timeout
	attack_area.monitoring = false
	_remove_attack_area_from_world()


func _on_attack_hit(body: Node2D) -> void:
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(ATTACK_DAMAGE)


func _on_attack_cooldown_finished() -> void:
	can_attack = true


func _perform_dodge() -> void:
	is_dashing = true
	is_invincible = true
	can_dodge = false

	# Set dash direction (use aim direction, or move direction if not aiming)
	var dash_dir := aim_direction
	if Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO:
		dash_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()

	velocity = dash_dir * DASH_SPEED
	dash_timer.start()
	dash_cooldown.start()

	# Visual feedback - flash
	sprite.modulate = Color(1, 1, 1, 0.5)


func _on_dash_finished() -> void:
	is_dashing = false
	is_invincible = false
	sprite.modulate = Color(1, 1, 1, 1)


func _on_dash_ready() -> void:
	can_dodge = true


func take_damage(amount: int) -> void:
	if is_invincible:
		return
	if not GameState.is_player_alive:
		return

	is_invincible = true
	hurt_timer.start()
	GameState.take_damage(amount)

	# Visual feedback - knockback and flash
	var knockback_dir := (global_position - get_global_mouse_position()).normalized()
	if knockback_dir == Vector2.ZERO:
		knockback_dir = -aim_direction
	velocity = knockback_dir * 300.0
	sprite.modulate = Color.RED

	if not GameState.is_player_alive:
		_die()


func _on_hurt_invincibility_finished() -> void:
	is_invincible = false
	sprite.modulate = Color(1, 1, 1, 1)


func _die() -> void:
	# Disable collision, input, and attacks
	collision_shape.set_deferred("disabled", true)
	attack_area.monitoring = false
	set_physics_process(false)
	set_process_input(false)
	sprite.modulate = Color(0.3, 0.3, 0.3, 0.6)
	# Keep the player body and camera in place — do NOT queue_free()


func _remove_attack_area_from_world() -> void:
	# Reparent attack area back to player
	if attack_area.get_parent() != self:
		attack_area.reparent(self, false)
		attack_area.position = Vector2.ZERO


func _update_aim_indicator() -> void:
	if aim_indicator:
		aim_indicator.global_position = global_position + aim_direction * 30.0


func _get_room_center() -> Vector2:
	# Default center - will be overridden by game manager
	return Vector2(480, 270)
