extends Node2D
## The season screen: build your pack in the shop, then watch your fight.
## Click a shop card to buy. Click one of your dogs to select it, then click an
## empty board cell or bench slot to move it there.

const CELL := Vector2(140, 62)
const GAP := 8.0
const LEFT := 190.0
const BOARD_Y := [70.0, 140.0]  # front row, back row
const BENCH_Y := 238.0
const BENCH_SLOT := Vector2(86, 56)
const SHOP_Y := 330.0
const SHOP_CARD := Vector2(136, 84)
const STANDINGS_X := 800.0

const COLORS := {
	"bg": Color("1e2229"),
	"cell": Color("2a3039"),
	"text": Color("f2ede4"),
	"muted": Color("9aa3ad"),
	"select": Color("f2c14e"),
	"warn": Color("e8846b"),
	"you": Color("c98a4b"),
}
## Card colour per tier, 1 to 5.
const TIER_COLORS := [Color("6b7280"), Color("4f8a5b"), Color("4a74a8"), Color("8a5aa8"), Color("c49a3a")]

var season: Season
var selected: PackDog = null
var message := ""
var _font: Font
var _battle_view: BattleView
var _shop_buttons: Array = []
var _game_over_button: Button


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_battle_view = BattleView.new()
	_battle_view.visible = false
	_battle_view.continue_pressed.connect(_after_battle)
	add_child(_battle_view)
	_shop_buttons = [
		_add_button("Reroll (1)", Vector2(LEFT, 440), func(): _act(season.player().reroll(), "Not enough kibble.")),
		_add_button("Train +4 XP (4)", Vector2(LEFT + 128, 440), func(): _act(season.player().buy_xp(), "Not enough kibble, or already level 8.")),
		_add_button("Bury 1 kibble", Vector2(LEFT + 256, 440), func(): _act(season.player().bury(1, season.round_number), "Nothing to bury, or 5 already buried.")),
		_add_button("Sell", Vector2(LEFT + 384, 440), _sell_selected),
		_add_button("Fight!", Vector2(LEFT + 512, 440), _fight),
	]
	_game_over_button = _add_button("New season", Vector2(LEFT, 440), _new_season)
	_new_season()


func _new_season() -> void:
	season = Season.new()
	season.start_round()
	selected = null
	message = "Buy dogs in the shop, then put them on your board."
	_show_shop()


func _show_shop() -> void:
	_battle_view.visible = false
	for b in _shop_buttons:
		b.visible = true
	_game_over_button.visible = false
	queue_redraw()


func _fight() -> void:
	selected = null
	season.play_fights()
	var fight: Dictionary = season.fights[0]
	var rival: Pack = fight["b"]
	for b in _shop_buttons:
		b.visible = false
	_battle_view.visible = true
	_battle_view.play(season.build_fight(fight["a"], rival), rival.name, season.loss_damage(fight["result"]))
	queue_redraw()


func _after_battle() -> void:
	if season.is_over():
		_battle_view.visible = false
		_game_over_button.visible = true
		queue_redraw()
		return
	season.start_round()
	message = ""
	_show_shop()


func _process(_delta: float) -> void:
	if not _battle_view.visible:
		queue_redraw()


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _battle_view.visible or season.is_over():
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var pos: Vector2 = event.position
	var pack := season.player()
	for i in Economy.SHOP_SIZE:
		if _shop_rect(i).has_point(pos):
			_act(pack.buy(i), "Can't buy: not enough kibble, or the bench is full.")
			return
	for row in BattleSim.ROWS:
		for lane in BattleSim.LANES:
			if _cell_rect(row, lane).has_point(pos):
				_click_cell(row, lane)
				return
	for i in Economy.BENCH_SIZE:
		if _bench_rect(i).has_point(pos):
			_click_bench(i)
			return
	selected = null


func _click_cell(row: int, lane: int) -> void:
	var pack := season.player()
	var dog := pack.dog_at(row, lane)
	if dog != null:
		selected = null if dog == selected else dog
		return
	if selected == null:
		return
	if not selected.on_board() and pack.board().size() >= pack.board_limit():
		message = "Your board is full: level up to field more dogs."
	elif not pack.place(selected, row, lane):
		message = "That dog doesn't fit there."
	else:
		message = ""
		selected = null


func _click_bench(i: int) -> void:
	var bench := season.player().bench()
	if i < bench.size():
		selected = null if bench[i] == selected else bench[i]
	elif selected != null and selected.on_board():
		_act(season.player().to_bench(selected), "The bench is full.")
		selected = null


func _sell_selected() -> void:
	if selected == null:
		message = "Select one of your dogs first."
		return
	season.player().sell(selected)
	selected = null
	message = ""


func _act(ok: bool, failure: String) -> void:
	message = "" if ok else failure
	queue_redraw()


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	if _battle_view.visible:
		return
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), COLORS["bg"])
	if season.is_over():
		_draw_game_over()
		return
	var pack := season.player()
	_text(Vector2(16, 26), "Round %d" % season.round_number, 16)
	var bones := "  ·  Buried %d" % pack.buried_total() if pack.buried_total() > 0 else ""
	var streak := "  ·  %s streak %d" % ["Win" if pack.streak > 0 else "Loss", absi(pack.streak)] if absi(pack.streak) >= 2 else ""
	_text(Vector2(LEFT, 26), "Kibble %d  ·  Pack Level %d (%s)  ·  Treat Bowl %d%s%s" % [
		pack.kibble, pack.level, "%d XP to next" % pack.xp_to_next() if pack.xp_to_next() > 0 else "max",
		pack.treat_bowl, bones, streak], 15)

	_text(Vector2(LEFT, 62), "Board %d / %d   (front row on top)" % [pack.board().size(), pack.board_limit()], 12, COLORS["muted"])
	for row in BattleSim.ROWS:
		for lane in BattleSim.LANES:
			draw_rect(_cell_rect(row, lane), COLORS["cell"])
	for dog in pack.board():
		var r := _cell_rect(dog.row, dog.lane)
		r.size.x = CELL.x * dog.length() + GAP * (dog.length() - 1)
		_draw_dog(r, dog)

	_text(Vector2(LEFT, BENCH_Y - 6), "Bench", 12, COLORS["muted"])
	var bench := pack.bench()
	for i in Economy.BENCH_SIZE:
		var r := _bench_rect(i)
		if i < bench.size():
			_draw_dog(r, bench[i])
		else:
			draw_rect(r, COLORS["cell"])

	_text(Vector2(LEFT, SHOP_Y - 6), "Shop", 12, COLORS["muted"])
	for i in Economy.SHOP_SIZE:
		_draw_shop_card(_shop_rect(i), pack.shop[i])

	_draw_synergies(pack)
	_draw_standings()
	if selected != null:
		var b := selected.breed()
		_text(Vector2(LEFT, 526), "%s (tier %d, level %d): %s" % [b["name"], b["tier"], selected.level, b["ability"]], 12, COLORS["muted"])
	if message != "":
		_text(Vector2(LEFT, 502), message, 13, COLORS["warn"])


func _draw_dog(r: Rect2, dog: PackDog) -> void:
	draw_rect(r, TIER_COLORS[dog.tier() - 1])
	if dog == selected:
		draw_rect(r, COLORS["select"], false, 3.0)
	var stars := "★".repeat(dog.level)
	_text(r.position + Vector2(6, 18), dog.breed()["name"], 12, COLORS["text"], r.size.x - 12)
	_text(r.position + Vector2(6, r.size.y - 8), stars, 12, COLORS["select"])


func _draw_shop_card(r: Rect2, id: String) -> void:
	if id == "":
		draw_rect(r, COLORS["cell"])
		return
	var b := BreedDB.get_breed(id)
	draw_rect(r, TIER_COLORS[b["tier"] - 1])
	_text(r.position + Vector2(6, 18), b["name"], 12, COLORS["text"], r.size.x - 12)
	_text(r.position + Vector2(6, 38), ", ".join(b["groups"]), 11, COLORS["text"], r.size.x - 12)
	_text(r.position + Vector2(6, 54), ", ".join(b["jobs"]), 11, COLORS["text"], r.size.x - 12)
	_text(r.position + Vector2(6, 76), "%d kibble" % b["tier"], 12, COLORS["select"])


func _draw_synergies(pack: Pack) -> void:
	_text(Vector2(16, 62), "Synergies", 13)
	var units := pack.board().map(func(d): return BattleUnit.new(d.breed(), 0, 0, 0, d.level))
	var counts := Synergies.count(units)
	var names := counts.keys()
	names.sort_custom(func(a, b): return counts[a] > counts[b])
	var y := 82.0
	for trait_name in names:
		var steps: Array = Synergies.THRESHOLDS.get(trait_name, [])
		var reached := Synergies.level_reached(trait_name, counts[trait_name])
		var next := "max" if reached >= steps.size() else "next at %d" % steps[reached]
		var color: Color = COLORS["text"] if reached > 0 else COLORS["muted"]
		_text(Vector2(16, y), "%s %d (%s)" % [trait_name, counts[trait_name], next], 11, color)
		y += 16


func _draw_standings() -> void:
	_text(Vector2(STANDINGS_X, 62), "League", 13)
	var y := 82.0
	for pack in season.standings():
		var color: Color = COLORS["you"] if pack.is_human else (COLORS["text"] if pack.is_alive() else COLORS["muted"])
		var value := "%d" % pack.treat_bowl if pack.is_alive() else "out"
		_text(Vector2(STANDINGS_X, y), pack.name, 11, color, 110)
		_text(Vector2(STANDINGS_X + 120, y), value, 11, color)
		y += 17


func _draw_game_over() -> void:
	var place := season.player_place()
	var title := "Golden Bone! Your pack wins the league." if place == 1 else "Season over: your pack finishes #%d of 8." % place
	_text(Vector2(LEFT, 120), title, 22)
	_text(Vector2(LEFT, 160), "Rounds played: %d" % season.round_number, 14, COLORS["muted"])
	_draw_standings()


func _text(pos: Vector2, text: String, size: int, color: Color = COLORS["text"], width: float = -1) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width, size, color)


# --- Layout -----------------------------------------------------------------

func _cell_rect(row: int, lane: int) -> Rect2:
	return Rect2(Vector2(LEFT + lane * (CELL.x + GAP), BOARD_Y[row]), CELL)


func _bench_rect(i: int) -> Rect2:
	return Rect2(Vector2(LEFT + i * (BENCH_SLOT.x + 6), BENCH_Y), BENCH_SLOT)


func _shop_rect(i: int) -> Rect2:
	return Rect2(Vector2(LEFT + i * (SHOP_CARD.x + GAP), SHOP_Y), SHOP_CARD)


func _add_button(text: String, pos: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.custom_minimum_size = Vector2(120, 36)
	button.pressed.connect(callback)
	add_child(button)
	return button
