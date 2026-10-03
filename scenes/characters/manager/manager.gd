extends CharacterBody2D
class_name Manager
## Player-controlled owner/manager (FR-02). WASD to move, E to interact.
## Placeholder look: a diamond. Art is loaded automatically from
## assets/character/manager_sheet.png (walk sheet) or manager.png — see
## assets/ART_GUIDE.md. The diamond hides when art is found.

signal focus_changed(target: Node)
signal interacted(target: Node, result: String)

@export var speed := 340.0

const PixelArt := preload("res://scenes/art/pixel_art.gd")
## Screen px from the body centre down to the feet (sprite bottom).
const FEET_Y := 20.0

var _anim_time := 0.0

var can_move := true
var _nearby: Array[Node] = []
var _focus: Node = null

@onready var interaction_area: Area2D = $InteractionArea


func _ready() -> void:
	var tex: Texture2D = $Sprite.texture
	if tex == null:
		tex = PixelArt.character("character", "manager")
	PixelArt.setup_character($Sprite, tex, FEET_Y)
	var has_art: bool = tex != null
	if has_art:
		$NameLabel.position.y = FEET_Y + 4
	$Body.visible = not has_art
	$Outline.visible = not has_art
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if can_move and not _typing():
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()
	_anim_time += delta
	PixelArt.animate_character($Sprite, velocity, _anim_time)
	_update_focus()


## True while the player types in a code editor or text box (WASD are letters
## then, not movement). Windows can stay open while walking around.
func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is TextEdit or f is LineEdit


func _unhandled_input(event: InputEvent) -> void:
	if can_move and event.is_action_pressed("interact") and _focus != null:
		get_viewport().set_input_as_handled()
		var result = _focus.interact(self)
		interacted.emit(_focus, result if result is String else "")


## Name tag under the manager (the player's name).
func set_display_name(text: String) -> void:
	$NameLabel.text = text if text != "" else "Manager"


## Forget nearby objects (call when the restaurant layout is swapped).
func clear_interactions() -> void:
	_nearby.clear()
	if _focus != null:
		_focus = null
		focus_changed.emit(null)


func _on_body_entered(body: Node) -> void:
	if body != self and body.has_method("interact"):
		_nearby.append(body)


func _on_body_exited(body: Node) -> void:
	_nearby.erase(body)


## Interactables in reach: what the area reported (staff) plus a direct shape
## query, because an Area2D doesn't report StaticBody2D stations, tables or the
## "+ Table" spots reliably.
func _in_reach() -> Array:
	var out: Array = _nearby.duplicate()
	var cs := interaction_area.get_child(0) as CollisionShape2D
	if cs == null or cs.shape == null:
		return out
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = cs.shape
	q.transform = cs.global_transform
	q.collision_mask = interaction_area.collision_mask
	q.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(q, 32):
		var b = hit.collider
		if b != null and b.has_method("interact") and not b in out:
			out.append(b)
	return out


## Focus the closest interactable in range.
func _update_focus() -> void:
	var best: Node = null
	var best_dist := INF
	for n in _in_reach():
		if not is_instance_valid(n) or not n.can_interact():
			continue
		var d := global_position.distance_squared_to((n as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			best = n
	if not can_move:
		best = null
	if best != _focus:
		_focus = best
		focus_changed.emit(_focus)
