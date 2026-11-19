class_name BattleView
extends Node2D
## Plays a fight live so the rules can be watched, then offers Continue.
## Placeholder shapes stand in for pixel-art sprites until the art pass.

signal continue_pressed

const CELL := Vector2(150, 64)
const GAP := 8.0
const BOARD_X := 190.0
## Rows from top to bottom: rival back, rival front, player front, player back.
const ROW_Y := [36.0, 108.0, 214.0, 286.0]
const FLASH_TIME := 0.15

const COLORS := {
	"bg": Color("1e2229"),
	"board": Color("2a3039"),
	"player": Color("c98a4b"),
	"rival": Color("5b7fa8"),
	"text": Color("f2ede4"),
	"muted": Color("9aa3ad"),
	"fluff": Color("6cc072"),
	"shield": Color("d8dde3"),
	"hit": Color("ffffff"),
}

var sim: BattleSim
var rival_name := "Rival kennel"
## Treat Bowl points the loser loses, as the season counts them.
var loss_damage := 0
var speed := 1.0
var _accumulator := 0.0
var _event_index := 0
var _flash := {}
var _font: Font
var _speed_button: Button
var _continue_button: Button


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_speed_button = _add_button("Speed x1", Vector2(BOARD_X, 470), _toggle_speed)
	_add_button("Skip", Vector2(BOARD_X + 130, 470), _skip)
	_continue_button = _add_button("Continue", Vector2(BOARD_X + 260, 470), func(): continue_pressed.emit())


## Starts showing a fresh, not yet started battle.
func play(p_sim: BattleSim, p_rival_name: String, p_loss_damage: int) -> void:
	sim = p_sim
	rival_name = p_rival_name
	loss_damage = p_loss_damage
	sim.start()
	_accumulator = 0.0
	_event_index = 0
	_flash.clear()


func _process(delta: float) -> void:
	if sim == null:
		return
	_continue_button.visible = sim.finished
	for unit in _flash.keys():
		_flash[unit] -= delta
		if _flash[unit] <= 0.0:
			_flash.erase(unit)
	if not sim.finished:
		_accumulator += delta * speed
		while _accumulator >= BattleSim.TICK and not sim.finished:
			_accumulator -= BattleSim.TICK
			sim.step()
		while _event_index < sim.events.size():
			_flash[sim.events[_event_index]["target"]] = FLASH_TIME
			_event_index += 1
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), COLORS["bg"])
	for i in ROW_Y.size():
		for lane in BattleSim.LANES:
			draw_rect(Rect2(_cell_pos(lane, ROW_Y[i]), CELL), COLORS["board"])
	for unit in sim.units:
		if unit.is_alive():
			_draw_unit(unit)
	_draw_side_panel(1, rival_name, 16.0, 40.0)
	_draw_side_panel(0, "Your pack", 16.0, 218.0)
	_draw_status()


func _draw_unit(unit: BattleUnit) -> void:
	var y: float = ROW_Y[_row_index(unit)]
	var pos := _cell_pos(unit.lane, y)
	var size := Vector2(CELL.x * unit.length + GAP * (unit.length - 1), CELL.y)
	var color: Color = COLORS["player"] if unit.side == 0 else COLORS["rival"]
	if _flash.has(unit):
		color = color.lerp(COLORS["hit"], 0.6)
	draw_rect(Rect2(pos, size), color)
	var label := unit.display_name()
	if unit.level > 1:
		label += " " + "★".repeat(unit.level)
	draw_string(_font, pos + Vector2(8, 22), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 14, COLORS["text"])
	draw_string(_font, pos + Vector2(8, 40), "Bite %d  Pace %.2f" % [unit.bite, unit.current_pace()], HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 11, COLORS["text"])
	# Fluff bar, with the shield drawn on top of it.
	var bar := Rect2(pos + Vector2(8, size.y - 14), Vector2(size.x - 16, 6))
	draw_rect(bar, Color(0, 0, 0, 0.35))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * unit.fluff / unit.max_fluff, bar.size.y)), COLORS["fluff"])
	if unit.shield > 0.0:
		var shield_w := minf(1.0, unit.shield / unit.max_fluff) * bar.size.x
		draw_rect(Rect2(bar.position - Vector2(0, 4), Vector2(shield_w, 3)), COLORS["shield"])


func _draw_side_panel(side: int, title: String, x: float, y: float) -> void:
	draw_string(_font, Vector2(x, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLORS["text"])
	var line := 1
	var active := Synergies.active(sim.side_units(side, false))
	var counts := Synergies.count(sim.side_units(side, false))
	for trait_name in active:
		var text := "%s %d (step %d)" % [trait_name, counts[trait_name], active[trait_name]]
		draw_string(_font, Vector2(x, y + 18 * line), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLORS["muted"])
		line += 1


func _draw_status() -> void:
	var text := "Time %.1f s" % sim.time
	if sim.time >= BattleSim.TIRED_AT and not sim.finished:
		text += "  (dogs are Tired)"
	if sim.finished:
		var result := sim.result()
		match result["winner"]:
			0:
				text = "Your pack wins! %s loses %d Treat Bowl points." % [rival_name, loss_damage]
			1:
				text = "%s wins. You lose %d Treat Bowl points." % [rival_name, loss_damage]
			_:
				text = "Draw. Both packs lose 1 Treat Bowl point."
	draw_string(_font, Vector2(BOARD_X, 400), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLORS["text"])


func _row_index(unit: BattleUnit) -> int:
	if unit.side == 1:
		return 1 - unit.row  # rival front row sits next to the middle
	return 2 + unit.row


func _cell_pos(lane: int, y: float) -> Vector2:
	return Vector2(BOARD_X + lane * (CELL.x + GAP), y)


func _add_button(text: String, pos: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.custom_minimum_size = Vector2(120, 36)
	button.pressed.connect(callback)
	add_child(button)
	return button


func _skip() -> void:
	while not sim.finished:
		sim.step()


func _toggle_speed() -> void:
	speed = 2.0 if speed == 1.0 else (4.0 if speed == 2.0 else 1.0)
	_speed_button.text = "Speed x%d" % int(speed)
