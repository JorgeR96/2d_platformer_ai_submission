extends CharacterBody2D

const SPEED := 220.0
const JUMP_VELOCITY := -600.0
const GRAVITY := 1400.0

@onready var animated_sprite = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		velocity.x = direction * SPEED
		animated_sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	if not is_on_floor():
		animated_sprite.play("1_jump_girl")
	elif direction != 0.0:
		animated_sprite.play("1_run_girl")
	else:
		animated_sprite.play("1_idle_girl")
		

	move_and_slide()
