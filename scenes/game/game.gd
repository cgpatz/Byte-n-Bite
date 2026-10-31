extends Node2D
## Gameplay root: loads the layout for the current restaurant level, places
## tables and characters, runs the camera, and wires HUD and panels together.

const PAUSE_SCENE := preload("res://scenes/ui/pause_menu/PauseMenu.tscn")
const LevelChallenges := preload("res://systems/challenges/level_challenges.gd")
const LevelGoals := preload("res://systems/goals/level_goals.gd")
const STATION_SCENE := preload("res://scenes/stations/Station.tscn")
const TABLE_SPOT_SCRIPT := preload("res://scenes/game/table_spot.gd")
const CONFIRM_SCRIPT := preload("res://scenes/ui/confirm/confirm_dialog.gd")
var confirm_dialog: Control
## Restaurant level on screen, to tell an upgrade from a load or admin jump.
var _shown_level := 0
const CODE_SETS_SCENE := preload("res://scenes/ui/admin_panel/CodeSetsWindow.tscn")
const STATS_SCENE := preload("res://scenes/ui/stats_panel/StatsPanel.tscn")
const RECIPE_SCENE := preload("res://scenes/ui/recipe_book/RecipeBook.tscn")
const LIBRARY_SCENE := preload("res://scenes/ui/library_panel/LibraryPanel.tscn")
const TUTORIAL_SCENE := preload("res://scenes/ui/tutorial/TutorialWindow.tscn")
const GUIDE_SCRIPT := preload("res://scenes/ui/guide/gameplay_guide.gd")
const Lessons := preload("res://data/help/lessons.gd")
## Extra keys: R = Recipe Book, L = Library, Tab = Stats.
const EXTRA_KEYS := {"recipe_book": KEY_R, "library": KEY_L, "stats": KEY_TAB, "tutorial": KEY_T, "market": KEY_M}

# --- Market (FR-11–FR-14, FR-58–FR-61) ---
const MARKET_SCRIPT := preload("res://scenes/market/market.gd")
const SHOP_SCRIPT := preload("res://scenes/ui/shop/shop_window.gd")
const FRIDGE_SCRIPT := preload("res://scenes/ui/shop/fridge_window.gd")
const CRATE_SCRIPT := preload("res://scenes/market/delivery_crate.gd")
const Market := preload("res://systems/market/market_rules.gd")
## The Market is built far away from the restaurant in the same world, so the
## restaurant (staff, customers) keeps running while the manager shops.
const MARKET_ORIGIN := Vector2(0, -3000)
var market: Node2D
var shop_window: Control
var fridge_window: Control
var crates_root: Node2D
var in_market := false
var _pad_armed := false
var _door_extras: Array = []
var _out_of_stock_said := {}

var stats_panel: Control
var code_sets_window: Control
var recipe_book: Control
var library_panel: Control
var tutorial_window: Control
## Chef Miso's RPG-style gameplay tutorial (new game and every new level).
var guide: CanvasLayer
## Open Chef Miso's lesson when a new C concept unlocks (tests turn this off).
var tutorials_enabled := true
const TABLE_SCENE := preload("res://scenes/restaurant/table/Table.tscn")
const NavGrid := preload("res://systems/navigation/nav_grid.gd")
const Kitchen := preload("res://systems/kitchen/kitchen_rules.gd")
const Progression := preload("res://data/progression/progression.gd")
const STAFF_SCENE := preload("res://scenes/characters/staff/Staff.tscn")
const PixelArt := preload("res://scenes/art/pixel_art.gd")
const BACKGROUND := Color(0.16, 0.12, 0.1)
## Screen margin (px) kept around small restaurants.
const AUTOSAVE_SECONDS := 60.0
const CustomerScript := preload("res://scenes/characters/customer/customer.gd")
## Seconds between new customers, per restaurant level (a little random).
const CUSTOMER_INTERVAL := [22.0, 26.0, 10.0, 9.0, 8.0]
## How long customers wait (seconds) before leaving, per restaurant level.
## Beginners get more time.
const CUSTOMER_PATIENCE := [150.0, 120.0, 90.0, 90.0, 90.0]
## Extra coins the first time each dish is ever served (rewards trying new dishes).
const FIRST_DISH_BONUS := 50
## Dishes that can wait on the serving counter for a customer who orders them.
const COUNTER_LIMIT := 6

var restaurant: Restaurant
## Walkable grid for staff pathfinding; rebuilt when the layout or seating changes.
var nav := NavGrid.new()

# Customers and orders (FR-09, FR-10).
## Turn off to stop new customers (tests use this).
var customers_enabled := true
var customers_root: Node2D
## Every chair and stool: {key, pos, facing, cafe, customer}.
var seats: Array = []
## Waiting orders, oldest first: {customer, dish, claimed_by, serving, taken,
## posted, ticket}. taken: a staff member has asked the customer (take_order());
## posted: the ticket is on the serving counter, waiting for a cook
## (post_order() / check_counter()).
var orders: Array = []
## Ticket numbers shown on the counter (1, 2, 3...).
var _next_ticket := 1
var ticket_rail: Node2D
## Dishes served before anyone ordered them, waiting on the counter.
var counter_dishes: Array = []
var _spawn_timer := 3.0
var _looks: Array = []

@onready var restaurant_holder: Node2D = $RestaurantHolder
@onready var tables_root: Node2D = $Tables
@onready var manager: Manager = $Characters/Manager
@onready var staff_root: Node2D = $Characters/Staff
@onready var camera: Camera2D = $Camera2D
@onready var ui: CanvasLayer = $UI
@onready var hud = $UI/HUD
@onready var programming_panel = $UI/ProgrammingPanel
@onready var upgrade_panel = $UI/UpgradePanel
@onready var admin_panel = $UI/AdminPanel



func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND)
	# Depth: stations, tables and characters are drawn in Y order (lower = in front).
	customers_root = Node2D.new()
	customers_root.name = "Customers"
	$Characters.add_child(customers_root)
	for n in [self, restaurant_holder, tables_root, $Characters, staff_root, customers_root]:
		n.y_sort_enabled = true
	_looks = CustomerScript.available_looks()
	ticket_rail = Node2D.new()
	ticket_rail.name = "TicketRail"
	ticket_rail.set_script(preload("res://scenes/game/ticket_rail.gd"))
	ticket_rail.game = self
	ticket_rail.visible = false  # orders now show on the HUD Order board
	add_child(ticket_rail)
	hud.game = self
	manager.focus_changed.connect(hud.show_prompt_for)
	manager.interacted.connect(_on_manager_interacted)
	for staff in staff_root.get_children():
		if staff is Staff:
			_hook_staff(staff)
	_add_windows()
	_setup_market()
	guide = CanvasLayer.new()
	guide.set_script(GUIDE_SCRIPT)
	guide.game = self
	add_child(guide)
	programming_panel.closed.connect(_on_panel_closed)
	upgrade_panel.closed.connect(_on_panel_closed)
	admin_panel.closed.connect(_on_panel_closed)
	admin_panel.code_sets_requested.connect(_open_code_sets)
	hud.set_admin_badge(GameState.admin_mode)
	GameState.restaurant_level_changed.connect(_on_level_changed)
	GameState.seating_changed.connect(_spawn_tables)
	GameState.cafe_changed.connect(_on_cafe_changed)
	GameState.goal_reached.connect(_on_goal_reached)
	GameState.staff_roster_changed.connect(_on_roster_changed)
	GameState.player_leveled_up.connect(_on_player_leveled_up)
	_sync_staff()
	_shown_level = GameState.restaurant_level
	_load_level()
	manager.set_display_name(GameState.manager_name)
	if not GameState.admin_mode:
		_show_new_lesson.call_deferred()
	# Autosave: every minute, and after upgrades and level-ups (not in Admin Runs).
	var autosave := Timer.new()
	autosave.wait_time = AUTOSAVE_SECONDS
	autosave.autostart = true
	autosave.timeout.connect(_autosave)
	add_child(autosave)
	GameState.restaurant_level_changed.connect(_autosave.unbind(1))
	GameState.player_leveled_up.connect(_autosave.unbind(2))
	GameState.seating_changed.connect(_autosave)


func _autosave() -> void:
	GameState.save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.save_now()


# --- Level loading ---------------------------------------------------------------

func _load_level() -> void:
	for c in restaurant_holder.get_children():
		c.queue_free()
	manager.clear_interactions()  # old stations are being freed
	for staff in _staff_list():
		staff.reset_work()
	_clear_customers()
	var data := GameState.level_data()
	restaurant = data.layout_scene.instantiate() as Restaurant
	restaurant_holder.add_child(restaurant)
	if _placeholders_forced_off:
		restaurant.show_greybox = false
	_apply_cafe_lock()
	_spawn_tables()
	in_market = false
	hud.set_in_market(false)
	_place_characters()
	_setup_camera()
	_spawn_crates()
	_decorate_back_door()


## The Grand Restaurant's Café door stays shut until the Café is bought.
func _apply_cafe_lock() -> void:
	var door := restaurant.get_node_or_null("Walls/CafeDoor")
	if door and GameState.cafe_step >= 1:
		door.get_parent().remove_child(door)
		door.queue_free()
		manager.clear_interactions()


func _on_cafe_changed(step: int) -> void:
	if restaurant == null:
		return
	_apply_cafe_lock()
	_build_nav()
	if step == 1:
		hud.show_toast("The Café is open! Macchiato is on the menu.")
	elif step > 1:
		var names: Array = []
		for d in Kitchen.cafe_step_dishes(step):
			names.append(Kitchen.title_of(d))
		hud.show_toast("New on the Café menu: %s" % " + ".join(names))


func _on_level_changed(level: int) -> void:
	var upgraded := level > _shown_level
	_shown_level = level
	_load_level()
	hud.show_toast("Welcome to the %s!" % GameState.level_data().display_name)
	# Every restaurant upgrade pops up that level's lesson (its key new C idea).
	_show_new_lesson(upgraded)


## A new level (or a new game): first Chef Miso's gameplay guide shows what's
## new (once per level), then that level's C lesson opens: always after a
## restaurant upgrade (force), otherwise only if the player hasn't seen it yet.
func _show_new_lesson(force := false) -> void:
	var lv: int = GameState.restaurant_level
	if not tutorials_enabled:
		return
	await get_tree().create_timer(0.8).timeout
	if not tutorials_enabled or not is_inside_tree() or GameState.restaurant_level != lv:
		return
	while _modal_open() or (guide and guide.is_running()):
		await get_tree().create_timer(0.3).timeout
	# Guides go in order: an unfinished earlier level's guide comes first.
	if guide:
		for g in range(1, lv + 1):
			if GameState.guides_done.has(g):
				continue
			await guide.run(g)
			if not is_inside_tree() or GameState.restaurant_level != lv:
				return
	if Lessons.for_level(lv).is_empty() or tutorial_window.visible:
		return
	if not force and GameState.tutorials_seen.has(lv):
		return
	while _modal_open():
		await get_tree().create_timer(0.3).timeout
	hud.show_prompt_for(null)
	tutorial_window.open_lesson(lv)


## Bought tables go into the layout's table slots, in order.
func _spawn_tables() -> void:
	for c in tables_root.get_children():
		c.queue_free()
	var slots := restaurant.get_table_slot_info()
	# Tell the seating system how many chairs each slot's table can hold.
	var caps: Array[int] = []
	for s in slots:
		caps.append(Table.FAMILY_MAX_CHAIRS if s.family else GameState.level_data().max_chairs_per_table)
	GameState.slot_chair_caps = caps
	for i in mini(GameState.tables_owned(), slots.size()):
		var t := TABLE_SCENE.instantiate() as Table
		t.kind = Table.Kind.FAMILY if slots[i].family else Table.Kind.SMALL
		t.ends_first = slots[i].ends_first
		var family: bool = slots[i].family
		t.station_id = "TABLE_%d" % (i + 1)
		t.display_name = ("Family Table %d" if family else "Table %d") % (i + 1)
		t.chairs = GameState.table_chairs[i]
		t.draw_greybox = restaurant.show_greybox and not _placeholders_forced_off
		t.auto_art = PixelArt.for_level("decor", "family_table" if family else "table", restaurant.level_key())
		t.chair_auto_art = PixelArt.for_level("decor", "chair", restaurant.level_key())
		t.position = slots[i].pos
		t.table_index = i
		tables_root.add_child(t)
	# The next table you can buy shows as a dashed "+ Table" spot (press E there).
	var n := GameState.tables_owned()
	if n < mini(GameState.table_limit(), slots.size()):
		var spot := STATION_SCENE.instantiate()
		spot.set_script(TABLE_SPOT_SCRIPT)
		spot.size = Table.FAMILY_SIZE if slots[n].family else Table.SMALL_SIZE
		spot.position = slots[n].pos
		tables_root.add_child(spot)
	manager.clear_interactions()
	_build_nav()
	_build_seats()


func _place_characters() -> void:
	manager.global_position = restaurant.get_manager_spawn()
	var i := 0
	for staff in _staff_list():
		_place_staff(staff, i)
		i += 1


## Puts the i-th staff member at their spawn marker, nudged so nobody overlaps.
func _place_staff(staff: Staff, i: int) -> void:
	var base := restaurant.get_staff_spawn(i)
	var taken: Array = []
	for other in _staff_list():
		if other != staff:
			taken.append(other.global_position)
	for off in [Vector2.ZERO, Vector2(56, 0), Vector2(-56, 0), Vector2(0, 56), Vector2(0, -56),
			Vector2(56, 56), Vector2(-56, 56), Vector2(56, -56), Vector2(-56, -56), Vector2(112, 0), Vector2(-112, 0)]:
		var p: Vector2 = base + off
		var cell := nav._to_cell(p)
		if not nav.is_free(cell):
			continue
		var clear := true
		for t in taken:
			if (t as Vector2).distance_to(p) < 40.0:
				clear = false
				break
		if clear:
			staff.global_position = p
			return
	staff.global_position = base


# --- Staff roster (Jane + staff unlocked by restaurant and player levels) ---------

func _staff_list() -> Array:
	var out: Array = []
	for c in staff_root.get_children():
		if c is Staff and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _hook_staff(staff: Staff) -> void:
	staff.world = self
	if not staff.program_requested.is_connected(_open_programming_panel):
		staff.program_requested.connect(_open_programming_panel)


## Adds staff who joined and removes any no longer on the roster (admin level jumps).
func _sync_staff() -> Array:
	var roster := GameState.staff_roster()
	var wanted: Array = roster.map(func(e): return e.name)
	var added: Array = []
	for staff in _staff_list():
		if not staff.staff_name in wanted:
			staff.reset_work()
			staff.queue_free()
	var have: Array = _staff_list().map(func(st): return st.staff_name)
	for e in roster:
		if e.name in have:
			continue
		var staff := STAFF_SCENE.instantiate() as Staff
		staff.name = e.name
		staff.staff_name = e.name
		staff.color = e.color
		staff_root.add_child(staff)
		_hook_staff(staff)
		added.append(staff)
	return added


func _on_roster_changed(joined: Array) -> void:
	var added := _sync_staff()
	if restaurant == null:
		return
	var i := _staff_list().size() - added.size()
	for staff in added:
		_place_staff(staff, i)
		i += 1
	if not joined.is_empty():
		hud.show_toast("New staff: %s joined the team! Press E on them to program." % ", ".join(joined))


func _on_player_leveled_up(level: int, rewards: Array) -> void:
	var text := "Manager Level %d!" % level
	if not rewards.is_empty():
		text += "  " + ",  ".join(rewards)
	hud.show_toast(text)


# --- Staff support (called by Staff while running C programs) --------------------

## Marks every solid station, wall and table as blocked for staff paths.
func _build_nav() -> void:
	var solids: Array = []
	_collect_solids(restaurant, solids)
	for t in tables_root.get_children():
		if t is Station and not t.is_queued_for_deletion():
			solids.append(_station_rect(t))
	nav.build(restaurant.get_bounds(), solids)


func _collect_solids(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Station and c.solid:
			out.append(_station_rect(c))
		_collect_solids(c, out)


func _station_rect(s: Station) -> Rect2:
	return Rect2(s.global_position - s.size / 2.0, s.size)


func get_station(station_id: String) -> Station:
	return restaurant.get_station(station_id) if restaurant else null


## Gap (px) between a station's edge and the spot where staff stand to use it.
const WORK_GAP := 24.0
## Side-by-side distance when several staff use the same station.
const WORK_SPACING := 40.0


## The exact spot a staff member stands to use a station: centred just below
## it (in front of it, as seen from above). If below is blocked (a wall or
## another counter), the top, left or right side is used instead. Staff who
## arrive while someone else is working there stand beside them.
## Returns {"ok", "pos", "path"}.
func work_spot(station: Station, staff: Node) -> Dictionary:
	var r := _station_rect(station)
	var c := r.get_center()
	var sides := [
		[Vector2(c.x, r.end.y + WORK_GAP), Vector2(1, 0), Vector2(0, 1)],        # below
		[Vector2(c.x, r.position.y - WORK_GAP), Vector2(1, 0), Vector2(0, -1)],  # above
		[Vector2(r.position.x - WORK_GAP, c.y), Vector2(0, 1), Vector2(-1, 0)],  # left
		[Vector2(r.end.x + WORK_GAP, c.y), Vector2(0, 1), Vector2(1, 0)],        # right
	]
	var others := 0
	for s in _staff_list():
		if s != staff and station.station_id != "" and (s.get("_at_station") == station.station_id or s.get("_going_to") == station.station_id):
			others += 1
	for side in sides:
		var base: Vector2 = side[0]
		var along: Vector2 = side[1]
		var out: Vector2 = side[2]
		# Slots along this side: centre first; a second staff member gets the next slot.
		var order := [0, 1, -1, 2, -2]
		for n in others % order.size():
			order.push_back(order.pop_front())
		var half: float = absf(r.size.dot(along)) / 2.0
		for slot in order:
			var p: Vector2 = base + along * WORK_SPACING * slot
			if absf((p - base).dot(along)) > half + 12.0:
				continue  # keep in front of the station, not past its end
			for push in [0.0, 12.0, 24.0]:
				var q: Vector2 = p + out * push
				if not nav.is_free(nav._to_cell(q)):
					continue
				var res: Dictionary = nav.find_path(staff.global_position, Rect2(q - Vector2(4, 4), Vector2(8, 8)), 18.0)
				if res.ok:
					var pts: PackedVector2Array = res.points
					pts.append(q)
					return {"ok": true, "pos": q, "path": pts}
	return {"ok": false}


func find_path(from: Vector2, station: Station, reach: float) -> Dictionary:
	return nav.find_path(from, _station_rect(station), reach)


func level_display_name() -> String:
	return GameState.level_data().display_name


## serve(): reserves the order this dish belongs to (the staff member then
## carries it to the customer). Empty when nobody has ordered it.
func claim_serving(staff: Staff, dish: String) -> Dictionary:
	var order := _find_order(dish, staff)
	if order.is_empty():
		return {}
	order.serving = staff
	order.claimed_by = staff
	var c = order.customer
	if c != null and is_instance_valid(c):
		c.food_coming = true
	return order


## True while a staff member is making this customer's order (they took it,
## or took its ticket, and haven't served it yet). The customer waits calmly:
## their patience is paused so they don't walk out mid-cooking.
func is_being_made(customer: Node) -> bool:
	for o in orders:
		if o.customer == customer:
			return o.taken and o.claimed_by != null and not o.posted
	return false


## Today's Special (Level 1): a Run makes the dish for the customer who has
## waited longest, so that customer is reserved for this staff member.
func reserve_special_order(staff: Node) -> void:
	if not GameState.special_active():
		return
	for o in orders:
		if o.claimed_by == staff:
			return
	for o in orders:
		if o.taken and o.claimed_by == null and not o.posted:
			o.claimed_by = staff
			return


## A staff program ended or stopped: orders it was making but never served
## go back to waiting (their customers' patience runs again).
func release_claims(staff: Node) -> void:
	for o in orders:
		if o.claimed_by == staff and o.get("serving") == null:
			o.claimed_by = null


## The staff member stopped before handing it over.
func unclaim_serving(order: Dictionary) -> void:
	order.serving = null
	var c = order.get("customer", null)
	if c != null and is_instance_valid(c):
		c.food_coming = false


## Hands the dish over: the customer pays. Returns the coins earned.
func deliver_order(order: Dictionary, staff: Staff) -> int:
	orders.erase(order)
	_refresh_tickets()
	return _deliver(order, staff.staff_name, staff.profit_mult())


func counter_full() -> bool:
	return counter_dishes.size() >= COUNTER_LIMIT


## A dish nobody ordered yet waits on the serving counter.
func put_on_counter(dish: String) -> void:
	counter_dishes.append(dish)
	hud.show_toast("%s is waiting on the counter: no customer has ordered it yet." % Kitchen.title_of(dish))


## Path to stand next to a point (a customer's seat).
func path_to_point(from: Vector2, point: Vector2) -> Dictionary:
	return nav.find_path(from, Rect2(point - Vector2(16, 16), Vector2(32, 32)), 30.0)


func _find_order(dish: String, staff: Staff) -> Dictionary:
	for pass_i in 3:
		for o in orders:
			if o.dish != dish:
				continue
			if not o.taken and o.customer != null:
				continue  # the customer hasn't told anyone their order yet
			if o.get("serving") != null and o.serving != staff:
				continue  # someone else is already carrying this one
			if pass_i == 0 and o.claimed_by == staff:
				return o
			if pass_i == 1 and o.claimed_by == null:
				return o
			if pass_i == 2:
				return o
	return {}


## Pays for a delivered order and lets the customer eat. Returns the price.
## mult = the serving staff member's upgrade bonus (1.0 = none); the extra
## coins count as profit too.
func _deliver(order: Dictionary, by: String, mult := 1.0) -> int:
	var dish: String = order.dish
	var base: int = Kitchen.DISHES[dish].price if Kitchen.DISHES.has(dish) else 10
	var price: int = roundi(base * mult)
	var first := int(GameState.dishes_served.get(dish, 0)) == 0
	GameState.money += price
	GameState.record_sale(dish, price)
	if first:
		GameState.money += FIRST_DISH_BONUS
	var who := "a customer"
	var c = order.customer
	if c != null and is_instance_valid(c):
		who = c.customer_name
		c.receive_dish()
	if first:
		hud.show_toast("First %s ever! %s served %s  +%d coins (+%d first-dish bonus)" % [Kitchen.title_of(dish), by, who, price, FIRST_DISH_BONUS])
	else:
		hud.show_toast("%s served %s to %s!  +%d coins" % [by, Kitchen.title_of(dish), who, price])
	GameState.add_sale_exp(base)  # a level-up toast may replace the sale toast
	return price


## Adds an order (customer may be null, e.g. in tests). At Restaurant Level 1
## (Today's Special) everyone knows the order, so it counts as taken right away;
## otherwise a staff member has to take it with take_order().
func place_order(customer: Node, dish: String) -> void:
	var order := {"customer": customer, "dish": dish, "claimed_by": null, "serving": null,
		"taken": GameState.special_active(), "posted": false, "ticket": 0}
	orders.append(order)
	if order.taken:
		_mark_taken(order)
		_hand_over_from_counter(order)


## The customer told someone their order: show it and slow their impatience.
func _mark_taken(order: Dictionary) -> void:
	order.taken = true
	var c = order.customer
	if c != null and is_instance_valid(c):
		c.order_taken = true
		c.queue_redraw()


## A matching dish already waiting on the counter is handed over right away.
func _hand_over_from_counter(order: Dictionary) -> bool:
	if not order.dish in counter_dishes:
		return false
	counter_dishes.erase(order.dish)
	orders.erase(order)
	_deliver(order, "The counter")
	_refresh_tickets()
	return true


## take_order(), step 1: reserves the customer who has waited longest and whose
## order nobody has taken. Empty when every order is taken. The staff member
## then walks over and calls finish_taking().
func reserve_order_to_take(staff: Node) -> Dictionary:
	for o in orders:
		if not o.taken and o.get("taker") == null:
			o.taker = staff
			return o
	return {}


## take_order(), step 2: the staff member reached the customer and heard the
## order. They are now the one making it (until they post it to the counter).
func finish_taking(order: Dictionary, staff: Node) -> int:
	order.erase("taker")
	_mark_taken(order)
	order.claimed_by = staff
	var id := Kitchen.id_of(order.dish)
	_hand_over_from_counter(order)
	return id


## The staff member stopped before reaching the customer.
func cancel_taking(order: Dictionary) -> void:
	order.erase("taker")


## take_order() with a test order (no customer): taken on the spot.
func take_order_now(staff: Node) -> int:
	var o := reserve_order_to_take(staff)
	if o.is_empty():
		return Kitchen.NOTHING
	return finish_taking(o, staff)


## Kept for old programs: next_order() now means take_order().
func next_order(staff: Node = null) -> int:
	return take_order_now(staff)


## has_order(): true while a customer is waiting for someone to take their order.
func has_order(_staff: Node = null) -> bool:
	for o in orders:
		if not o.taken and o.get("taker") == null:
			return true
	return false


## post_order(DISH): the waiter pins the order they took on the counter as a
## ticket at the back of the queue. Returns the ticket number, or 0 when this
## staff member hasn't taken an order for that dish.
func post_order(staff: Node, dish: String) -> int:
	for o in orders:
		if o.taken and not o.posted and o.claimed_by == staff and (dish == "" or o.dish == dish):
			o.posted = true
			o.claimed_by = null
			o.ticket = _next_ticket
			_next_ticket += 1
			_refresh_tickets()
			return o.ticket
	return 0


## check_counter(): the oldest ticket on the counter (first in, first out).
## The cook takes it off the counter and makes that dish.
func check_counter(staff: Node) -> int:
	var best: Dictionary = {}
	for o in orders:
		if o.posted and o.claimed_by == null and (best.is_empty() or o.ticket < best.ticket):
			best = o
	if best.is_empty():
		return Kitchen.NOTHING
	best.posted = false
	best.claimed_by = staff
	_refresh_tickets()
	return Kitchen.id_of(best.dish)


## The dishes on the counter's tickets, oldest first (for orders(list)).
func counter_tickets() -> Array:
	var posted: Array = orders.filter(func(o): return o.posted and o.claimed_by == null)
	posted.sort_custom(func(a, b): return a.ticket < b.ticket)
	return posted.map(func(o): return o.dish)


func _refresh_tickets() -> void:
	if ticket_rail:
		ticket_rail.queue_redraw()


# --- Customers ------------------------------------------------------------------------

## Collects every chair (around bought tables) and counter stool as a seat.
func _build_seats() -> void:
	var taken := {}
	for s in seats:
		if s.customer != null and is_instance_valid(s.customer):
			taken[s.key] = s.customer
	seats = []
	var cafe_rect := Rect2()
	var cafe_room := restaurant.get_node_or_null("Rooms/Cafe") as Control
	if cafe_room:
		cafe_rect = Rect2(cafe_room.global_position, cafe_room.size)
	var i := 0
	for t in tables_root.get_children():
		if not t is Table or t.is_queued_for_deletion():
			continue
		var offsets: Array = t.chair_offsets()
		for c in mini(t.chairs, offsets.size()):
			var off: Vector2 = offsets[c]
			var facing := "right" if off.x < -1 else ("left" if off.x > 1 else ("down" if off.y < 0 else "up"))
			var pos: Vector2 = t.global_position + off
			_add_seat("t%d_%d" % [i, c], pos, facing, cafe_rect.has_point(pos), taken)
		i += 1
	var stools := restaurant.get_node_or_null("Stations/CounterStools")
	if stools:
		for st in stools.get_children():
			if st is Node2D:
				_add_seat("s_" + st.name, st.global_position, "up", cafe_rect.has_point(st.global_position), taken)


func _add_seat(key: String, pos: Vector2, facing: String, cafe: bool, taken: Dictionary) -> void:
	seats.append({"key": key, "pos": pos, "facing": facing, "cafe": cafe, "customer": taken.get(key, null)})


func _free_seats() -> Array:
	var out: Array = []
	for s in seats:
		if s.customer != null and is_instance_valid(s.customer):
			continue
		if s.cafe and GameState.cafe_step < 1:
			continue
		out.append(s)
	return out


## Where customers come in and leave: the entrance gap in the front wall.
func _entrance() -> Vector2:
	var floor_rect := restaurant.get_node_or_null("Floor/EntranceFloor") as ColorRect
	if floor_rect:
		return floor_rect.global_position + floor_rect.size / 2.0
	return restaurant.get_manager_spawn()


## Brings in one customer (random look) to a random free seat. Returns it, or null.
func spawn_customer(dish := "") -> Node:
	if restaurant == null:
		return null
	var free := _free_seats()
	free.shuffle()
	var door := _entrance()
	for seat in free:
		var res: Dictionary = nav.find_path(door, Rect2(seat.pos - Vector2(12, 12), Vector2(24, 24)), 20.0)
		if not res.ok:
			continue
		var c: Node2D = Node2D.new()
		c.set_script(CustomerScript)
		var look: String = _looks.pick_random() if not _looks.is_empty() else "guest"
		c.setup(look, res.points, seat, door)
		c.game = self
		c.patience = CUSTOMER_PATIENCE[clampi(GameState.restaurant_level, 1, 5) - 1]
		c.position = door
		if dish != "":
			c.set_meta("wants", dish)
		seat.customer = c
		c.left_restaurant.connect(_on_customer_left)
		customers_root.add_child(c)
		return c
	return null


## Called by a customer once seated: they order something on the menu.
func customer_seated(c: Node) -> void:
	var dish: String = c.get_meta("wants", "")
	if dish == "":
		var menu: Array = []
		for d in GameState.current_menu():
			if Kitchen.is_cafe(d) == bool(c.seat.cafe):
				menu.append(d)
		if menu.is_empty():
			menu = GameState.current_menu()
		# Level 1: everyone orders Today's Special (no take_order() yet).
		if GameState.special_active() and GameState.todays_special in menu:
			dish = GameState.todays_special
		else:
			dish = menu.pick_random()
	c.dish = dish
	c.queue_redraw()
	place_order(c, dish)


## A customer waited too long: their order is cancelled and they walk out.
func customer_gave_up(c: Node) -> void:
	for o in orders.duplicate():
		if o.customer == c:
			orders.erase(o)
	for s in seats:
		if s.customer == c:
			s.customer = null
	_refresh_tickets()
	GameState.customers_lost += 1
	hud.show_toast("%s waited too long for %s and left without eating." % [c.customer_name, Kitchen.title_of(c.dish)])


func _on_customer_left(c: Node) -> void:
	for s in seats:
		if s.customer == c:
			s.customer = null
	for o in orders.duplicate():
		if o.customer == c:
			orders.erase(o)
	_refresh_tickets()


func _clear_customers() -> void:
	if customers_root:
		for c in customers_root.get_children():
			c.queue_free()
	seats = []
	orders = []
	counter_dishes = []
	_next_ticket = 1
	_refresh_tickets()
	_spawn_timer = 3.0


# --- Camera ----------------------------------------------------------------------
# A following camera: it smoothly follows the manager and stops at the
# restaurant's edges. If the restaurant is smaller than the screen on one axis,
# it stays centred on that axis instead.

## Camera zoom. 1.5 keeps pixel art crisp (16 px art × 4 × 1.5 = 6 px per art pixel).
const FOLLOW_ZOOM := 1.5
## How quickly the camera catches up with the manager (higher = snappier).
const FOLLOW_SPEED := 6.0
## Extra space (px) shown past the restaurant's walls.
const EDGE_MARGIN := 48.0

var _cam_bounds := Rect2()


func _setup_camera() -> void:
	_cam_bounds = restaurant.get_bounds().grow(EDGE_MARGIN)
	camera.zoom = Vector2(FOLLOW_ZOOM, FOLLOW_ZOOM)
	if in_market and market:
		_cam_bounds = market.bounds().grow_individual(0, 110, 0, 0)  # room under the HUD
		var z := maxf(FOLLOW_ZOOM, get_viewport_rect().size.x / market.bounds().size.x)
		camera.zoom = Vector2(z, z)
	camera.global_position = _camera_target()  # jump there on level load


## Where the camera should be: on the manager, kept inside the restaurant.
func _camera_target() -> Vector2:
	var half := get_viewport_rect().size / camera.zoom / 2.0
	var p := manager.global_position
	var out := Vector2()
	for axis in 2:
		var lo: float = _cam_bounds.position[axis] + half[axis]
		var hi: float = _cam_bounds.end[axis] - half[axis]
		out[axis] = _cam_bounds.get_center()[axis] if lo > hi else clampf(p[axis], lo, hi)
	return out


func _process(delta: float) -> void:
	if restaurant == null:
		return
	var t := 1.0 - exp(-FOLLOW_SPEED * delta)
	camera.global_position = camera.global_position.lerp(_camera_target(), t)
	GameState.tick_market(delta)
	_check_teleport_pad()
	_check_miso_quest(delta)
	if customers_enabled:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			spawn_customer()
			var base: float = CUSTOMER_INTERVAL[clampi(GameState.restaurant_level, 1, 5) - 1]
			_spawn_timer = base * randf_range(0.8, 1.25)


# --- Panels ------------------------------------------------------------------------

## Show/hide every placeholder box (layout, tables). Used by the admin panel
## to preview art; collisions are unaffected.
var _placeholders_forced_off := false


func set_placeholders_visible(on: bool) -> void:
	_placeholders_forced_off = not on
	restaurant.show_greybox = on
	for t in tables_root.get_children():
		if t is Station:
			t.draw_greybox = on


func _on_manager_interacted(target: Node, result: String) -> void:
	if _market_interaction(target):
		return
	if _offer_upgrade(target):
		return
	hud.show_toast(result)


# --- In-world upgrades: walk to the spot, press E, confirm ------------------------
# Upgrade Board (chalkboard): restaurant level · "+ Table" spot: a table ·
# a table: a chair · Café door: open the Café · Café menu board: next recipes.

func _offer_upgrade(target: Node) -> bool:
	var gs = GameState
	if target is Table:
		var i: int = target.table_index
		if i < 0 or i >= gs.table_chairs.size() or gs.table_chairs[i] >= gs.chair_cap(i):
			return false
		_ask("Add a chair", "Give %s another chair so one more customer can sit there (%d / %d chairs)." % [
			target.display_name, gs.table_chairs[i], gs.chair_cap(i)],
			gs.level_data().chair_cost, func(): _bought(gs.buy_chair_at(i), "New chair added!"))
		return true
	if target.get_script() == TABLE_SPOT_SCRIPT:
		_ask("Buy a table", "Put a new table here. It comes with 1 chair (tables: %d / %d)." % [
			gs.tables_owned(), gs.table_limit()],
			gs.next_table_cost(), func(): _bought(gs.buy_table(), "New table bought!"))
		return true
	if not target is Station:
		return false
	if target.opens == "upgrades":
		if gs.restaurant_level >= gs.MAX_RESTAURANT_LEVEL:
			hud.show_toast("The Grand Restaurant is fully upgraded!")
			return true
		var d: RestaurantLevelData = gs.level_data()
		var next: RestaurantLevelData = gs.level_data(gs.restaurant_level + 1)
		var lines: Array = []
		for g in gs.goals_left():
			lines.append("☐ Goal: %s (%d / %d)" % [g.title, gs.goal_progress(g), g.n])
		for g in gs.challenges_left():
			lines.append("☐ Challenge: %s: %s" % [g.title, g.task])
		if not lines.is_empty():
			_ask("Upgrade the restaurant", "Finish this level's goals and challenges first (also listed at the top left):\n" + "\n".join(lines),
				d.upgrade_cost, Callable(), "Upgrade", true)
			return true
		_ask("Upgrade the restaurant", "Move up to Level %d: %s. It teaches %s and brings new dishes. Seating starts again at 1 table." % [
			next.level, next.display_name, next.c_focus],
			d.upgrade_cost, func(): _bought(gs.upgrade_restaurant(), ""), "Upgrade")
		return true
	if target.station_id == "CAFE_DOOR" and gs.cafe_step < 1:
		_ask("Open the Café", "Unlock the Café room: coffee drinks and pastries, starting with Macchiato. Café tables can be bought after.",
			gs.next_cafe_cost(), func(): _bought(gs.buy_cafe_step(), ""), "Unlock")
		return true
	if target.opens == "cafe_menu":
		if gs.cafe_step >= Kitchen.CAFE_STEPS:
			hud.show_toast("The Café menu is complete!")
			return true
		var names: Array = []
		for dd in Kitchen.cafe_step_dishes(gs.cafe_step + 1):
			names.append(Kitchen.title_of(dd))
		_ask("New Café recipes", "Add %s to the Café menu (recipe set %d of %d)." % [
			" + ".join(names), gs.cafe_step + 1, Kitchen.CAFE_STEPS],
			gs.next_cafe_cost(), func(): _bought(gs.buy_cafe_step(), ""))
		return true
	return false


func _ask(title: String, body: String, cost: int, on_yes: Callable, yes_text := "Buy", locked := false) -> void:
	_confirm_dialog().ask(title, body, cost, on_yes, yes_text, locked)


func _confirm_dialog() -> Control:
	if confirm_dialog == null:
		confirm_dialog = Control.new()
		confirm_dialog.set_script(CONFIRM_SCRIPT)
		ui.add_child(confirm_dialog)
		confirm_dialog.closed.connect(_on_panel_closed)
	manager.can_move = false
	hud.show_prompt_for(null)
	return confirm_dialog


# --- Staff upgrades (code editor's Upgrade button or the Stats window's Staff page) ---

## Asks to buy the next level for a staff member. Lv 9 -> 10 also picks a
## role (Chef / Barista / Cashier / Waiter).
func offer_staff_upgrade(staff_name: String) -> void:
	var gs = GameState
	var lv: int = gs.staff_level(staff_name)
	var spec: String = gs.staff_spec(staff_name)
	if lv >= Progression.MAX_STAFF_LEVEL:
		hud.show_toast("%s is already max level (Lv %d %s)." % [staff_name, lv, spec])
		return
	var cost: int = gs.staff_upgrade_cost(staff_name)
	var now := "Now (Lv %d): %s" % [lv, Progression.staff_perks_text(lv, spec)]
	if lv + 1 >= Progression.MAX_STAFF_LEVEL:
		var lines: Array = []
		for sp in Progression.STAFF_SPECIALIZATIONS:
			lines.append("• %s: %s" % [sp, Progression.SPECIALIZATION_INFO[sp]])
		_confirm_dialog().ask_choice("Upgrade %s to Lv 10" % staff_name,
			"%s\nLv 10: %s\n\nPick a role (it can't be changed later):\n%s" % [
				now, Progression.staff_perks_text(lv + 1), "\n".join(lines)],
			cost, Progression.STAFF_SPECIALIZATIONS,
			func(sp: String): _staff_upgraded(gs.upgrade_staff(staff_name, sp), staff_name))
		return
	_ask("Upgrade %s" % staff_name, "%s\nLv %d: %s" % [now, lv + 1, Progression.staff_perks_text(lv + 1, spec)],
		cost, func(): _staff_upgraded(gs.upgrade_staff(staff_name), staff_name), "Upgrade")


func _staff_upgraded(ok: bool, staff_name: String) -> void:
	if not ok:
		return
	var lv: int = GameState.staff_level(staff_name)
	var spec: String = GameState.staff_spec(staff_name)
	hud.show_toast("%s is now Lv %d%s!" % [staff_name, lv, (" " + spec) if spec != "" else ""])


## Level challenges: called by a staff member after each printf and serve().
func check_challenges(staff: Node) -> void:
	var lv: int = GameState.restaurant_level
	# The Level Challenge (and Mastery) unlock after Chef Miso's quests.
	if not GameState.miso_done(lv):
		return
	for id in LevelChallenges.met_mastery(lv, staff.run_trace):
		if GameState.complete_mastery(lv, id):
			var m: Dictionary = LevelChallenges.find_mastery(lv, id)
			hud.show_toast("★ Mastery: %s!  +%d coins  +%d EXP" % [m.title, m.coins, m.exp])
	for id in LevelChallenges.met(lv, staff.run_trace):
		if GameState.complete_challenge(lv, id):
			var g: Dictionary = LevelChallenges.find(lv, id)
			hud.show_toast("Challenge done: %s!  +%d coins  +%d EXP%s" % [g.title, g.coins, g.exp, _all_done_text(lv)])


## Level goal reached (a sale counted toward it): toast with the reward.
func _on_goal_reached(level: int, id: String) -> void:
	var g: Dictionary = LevelGoals.find(level, id)
	hud.show_toast("Goal reached: %s!  +%d coins  +%d EXP%s" % [g.title, g.coins, g.exp, _all_done_text(level)])


func _all_done_text(lv: int) -> String:
	if not GameState.goals_left(lv).is_empty() or not GameState.challenges_left(lv).is_empty():
		return ""
	return "  ·  Level %d complete%s" % [lv, ": upgrade at the chalkboard!" if lv < GameState.MAX_RESTAURANT_LEVEL else "!"]


func _bought(ok: bool, message: String) -> void:
	if ok and message != "":
		hud.show_toast(message)


func _open_programming_panel(staff: Staff) -> void:
	hud.show_prompt_for(null)
	programming_panel.open(staff)
	programming_panel.move_to_front()


func _open_upgrade_panel() -> void:
	manager.can_move = false
	hud.show_prompt_for(null)
	upgrade_panel.open()


## Admin: ready-to-copy programs (scenes/ui/admin_panel/code_sets_window.gd).
func _open_code_sets() -> void:
	if code_sets_window == null:
		code_sets_window = CODE_SETS_SCENE.instantiate()
		code_sets_window.game = self
		ui.add_child(code_sets_window)
		code_sets_window.closed.connect(_on_panel_closed)
	code_sets_window.open()


func _open_admin_panel() -> void:
	manager.can_move = false
	hud.show_prompt_for(null)
	admin_panel.open()


## Stats, Recipe Book and Library windows, their keys and HUD buttons.
func _add_windows() -> void:
	for action in EXTRA_KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = EXTRA_KEYS[action]
			InputMap.action_add_event(action, ev)
	stats_panel = STATS_SCENE.instantiate()
	recipe_book = RECIPE_SCENE.instantiate()
	library_panel = LIBRARY_SCENE.instantiate()
	tutorial_window = TUTORIAL_SCENE.instantiate()
	for w in [stats_panel, recipe_book, library_panel, tutorial_window]:
		ui.add_child(w)
		w.closed.connect(_on_panel_closed)
	hud.window_requested.connect(_open_window)
	stats_panel.staff_upgrade_requested.connect(offer_staff_upgrade)
	programming_panel.upgrade_requested.connect(offer_staff_upgrade)


## Lessons, Recipe Book, Library and Stats float: several can be open while the
## manager keeps walking. The key (or HUD button) opens a window, or closes it
## when it's already open.
func _open_window(which: String) -> void:
	if _modal_open():
		return
	if which == "pause":
		ui.add_child(PAUSE_SCENE.instantiate())
		return
	if which == "market":
		if in_market:
			return_from_market()
		else:
			go_to_market()
		return
	var w: Control = {"stats": stats_panel, "recipe_book": recipe_book, "library": library_panel, "tutorial": tutorial_window}.get(which)
	if w == null:
		return
	if w.visible:
		w.close()
		return
	w.open()


func _on_panel_closed() -> void:
	manager.can_move = not _modal_open()


## Pop-ups that need an answer first (they stop the manager and the hotkeys).
func _modal_open() -> bool:
	for w in [upgrade_panel, admin_panel, confirm_dialog, shop_window, fridge_window]:
		if w and w.visible:
			return true
	return false


func _any_panel_open() -> bool:
	if _modal_open():
		return true
	for w in [programming_panel, stats_panel, recipe_book, library_panel, tutorial_window, code_sets_window]:
		if w and w.visible:
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	# Clicking the restaurant takes the keyboard back from a code editor.
	if event is InputEventMouseButton and event.pressed:
		get_viewport().gui_release_focus()
	if _modal_open():
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		ui.add_child(PAUSE_SCENE.instantiate())
	elif event.is_action_pressed("recipe_book") or event.is_action_pressed("library") or event.is_action_pressed("stats") or event.is_action_pressed("tutorial") or event.is_action_pressed("market"):
		get_viewport().set_input_as_handled()
		for action in EXTRA_KEYS:
			if event.is_action_pressed(action):
				_open_window(action)
	elif GameState.admin_mode and event.is_action_pressed("admin_panel"):
		get_viewport().set_input_as_handled()
		_open_admin_panel()


# --- Market, deliveries and inventory ---------------------------------------------

func _setup_market() -> void:
	market = Node2D.new()
	market.name = "Market"
	market.set_script(MARKET_SCRIPT)
	market.position = MARKET_ORIGIN
	add_child(market)
	crates_root = Node2D.new()
	crates_root.name = "Crates"
	crates_root.y_sort_enabled = true
	add_child(crates_root)
	shop_window = Control.new()
	shop_window.set_script(SHOP_SCRIPT)
	ui.add_child(shop_window)
	shop_window.closed.connect(_on_panel_closed)
	fridge_window = Control.new()
	fridge_window.set_script(FRIDGE_SCRIPT)
	ui.add_child(fridge_window)
	fridge_window.closed.connect(_on_panel_closed)
	fridge_window.market_requested.connect(go_to_market)
	GameState.delivery_arrived.connect(_on_delivery_arrived)
	GameState.deliveries_changed.connect(_on_deliveries_changed)
	GameState.cafe_changed.connect(func(_s): market.refresh())


## Back door / M: the manager goes to the Market. The restaurant keeps running.
func go_to_market() -> void:
	if in_market or market == null:
		return
	in_market = true
	_pad_armed = false
	manager.clear_interactions()
	manager.global_position = market.arrival_point()
	_setup_camera()
	camera.global_position = _camera_target()
	hud.set_in_market(true)
	hud.show_toast("Night Market: walk to a stall and press E. Step on the pad to go back.")


## Teleport pad / M: back to the restaurant, in front of the back door.
func return_from_market() -> void:
	if not in_market:
		return
	in_market = false
	manager.clear_interactions()
	manager.global_position = back_door_spot()
	_setup_camera()
	camera.global_position = _camera_target()
	hud.set_in_market(false)


## A free spot just inside the back door (where the manager comes back).
func back_door_spot() -> Vector2:
	var door := get_station("BACK_DOOR")
	if door == null:
		return restaurant.get_manager_spawn()
	return nav.cell_center(nav._nearest_free(nav._to_cell(door.global_position)))


func _check_teleport_pad() -> void:
	if not in_market or market == null or _modal_open():
		return
	var d := manager.global_position.distance_to(market.pad_point())
	if d > 110.0:
		_pad_armed = true
	elif _pad_armed and d < 36.0:
		return_from_market()


## Market stalls, the price board, the pad, the back door, crates and the fridge.
func _market_interaction(target: Node) -> bool:
	if target.get_script() == CRATE_SCRIPT:
		var c: Dictionary = GameState.claim_crate(target.crate_index)
		if not c.is_empty():
			hud.show_toast("+%d %s in the kitchen (now %d)." % [c.n, Market.title(c.ing), GameState.stock_of(c.ing)])
			for k in _out_of_stock_said.keys():
				if str(k).ends_with("|" + c.ing):
					_out_of_stock_said.erase(k)
		return true
	if not target is Station:
		return false
	if target.station_id == "BACK_DOOR":
		go_to_market()
		return true
	if target.station_id == "FRIDGE":
		manager.can_move = false
		hud.show_prompt_for(null)
		fridge_window.open()
		return true
	if target.opens.begins_with("shop:"):
		manager.can_move = false
		hud.show_prompt_for(null)
		shop_window.open(target.opens.trim_prefix("shop:"))
		return true
	if target.opens == "price_board":
		_ask("Price Board", price_board_text(), 0, Callable(), "OK")
		return true
	if target.opens == "return":
		return_from_market()
		return true
	return false


## "Rice 10 · Egg 4 ..." for every unlocked ingredient.
func inventory_text() -> String:
	var parts: Array = []
	for ing in Kitchen.INGREDIENTS:
		if Kitchen.available(ing, GameState.restaurant_level, GameState.cafe_step) == "":
			parts.append("%s %d" % [Market.title(ing), GameState.stock_of(ing)])
	var t := "Ingredients in the kitchen:\n" + "  ·  ".join(parts)
	if not GameState.crates.is_empty():
		t += "\n\n%d crate(s) waiting in the delivery area: press E on them to bring them in." % GameState.crates.size()
	t += "\n\nBuy more at the Market (back door or M)."
	return t


func price_board_text() -> String:
	var lines: Array = []
	for key in Market.STALLS:
		var st: Dictionary = Market.STALLS[key]
		if st.get("cafe", false) and GameState.cafe_step < 1:
			lines.append("%s: opens with the Café" % st.title)
			continue
		var parts: Array = []
		for ing in st.items:
			if Kitchen.available(ing, GameState.restaurant_level, GameState.cafe_step) != "":
				continue
			var n := int(GameState.market_stock.get(ing, 0))
			parts.append("%s %d (%s)" % [Market.title(ing), Market.price(ing), "sold out" if n <= 0 else "%d left" % n])
		lines.append("%s: %s" % [st.title, ", ".join(parts) if not parts.is_empty() else "nothing for your level yet"])
	return "Prices in coins, and what each stall has tonight:\n" + "\n".join(lines) + \
		"\n\nStock changes every %d minutes (next in %s). Deliveries take %d s + %d s per item (max %d s); one crate holds %d." % [
		int(Market.RESTOCK_SECONDS / 60), Market.clock(GameState.market_restock_left), int(Market.DELIVERY_BASE),
		int(Market.DELIVERY_PER_ITEM), int(Market.DELIVERY_MAX), Market.CRATE_SIZE]


## Crates in the delivery area (from GameState.crates).
func _spawn_crates() -> void:
	if crates_root == null:
		return
	for c in crates_root.get_children():
		c.queue_free()
	var area := get_station("RECEIVING")
	if area == null:
		return
	var cap := maxi(GameState.crate_capacity(), GameState.crates.size())
	var r := Rect2(area.global_position - area.size / 2.0, area.size)
	var cols := clampi(ceili(sqrt(cap * r.size.x / maxf(r.size.y, 1.0))), 1, cap)
	var rows := ceili(cap / float(cols))
	var step := Vector2(r.size.x / cols, r.size.y / rows)
	for i in GameState.crates.size():
		var cr := STATION_SCENE.instantiate()
		cr.set_script(CRATE_SCRIPT)
		cr.setup(i, GameState.crates[i])
		cr.position = r.position + Vector2((i % cols + 0.5) * step.x, (i / cols + 0.5) * step.y + 8)
		crates_root.add_child(cr)
		# Crates from a truck that is still driving in stay hidden until it unloads.
		if _hide_crates_from >= 0 and i >= _hide_crates_from:
			cr.visible = false
			cr.interactable = false
	manager.clear_interactions()


func _on_deliveries_changed() -> void:
	_spawn_crates()
	hud.refresh_deliveries()


func _on_delivery_arrived(cart: Dictionary) -> void:
	var n := Market.crates_for(cart)
	hud.show_delivery_arrived(n)
	if _hide_crates_from < 0:
		_hide_crates_from = GameState.crates.size() - n
	_drive_truck()


## Index of the first crate still on the truck (-1 = none).
var _hide_crates_from := -1
var _truck: Sprite2D

## The delivery truck drives in through the back door to the delivery area,
## opens up, the crates pop out, and it drives away.
func _drive_truck() -> void:
	var area := get_station("RECEIVING")
	var door := get_station("BACK_DOOR")
	var sheet := PixelArt.find(["res://assets/delivery/delivery_truck_drive_sheet.png"])
	if area == null or sheet == null or _truck != null:
		if _truck == null:
			_unload_crates()
		return
	var from: Vector2 = door.global_position if door else area.global_position + Vector2(-260, 0)
	var to: Vector2 = area.global_position
	if from.distance_to(to) < 40.0:
		from = to + Vector2(-260, 0)
	_truck = Sprite2D.new()
	_truck.texture = sheet
	_truck.hframes = 2
	_truck.scale = Vector2(2, 2)
	_truck.z_index = 4
	_truck.flip_h = to.x < from.x
	_truck.global_position = from
	_truck.modulate.a = 0.0
	add_child(_truck)
	var anim := create_tween().set_loops(10)
	anim.tween_callback(func():
		if is_instance_valid(_truck) and _truck.hframes == 2:
			_truck.frame = 1 - _truck.frame).set_delay(0.12)
	var tw := create_tween()
	tw.tween_property(_truck, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(_truck, "global_position", to, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		anim.kill()
		_truck.hframes = 1
		_truck.frame = 0
		_truck.texture = PixelArt.find(["res://assets/delivery/delivery_truck_open.png"]) if PixelArt.find(["res://assets/delivery/delivery_truck_open.png"]) else sheet
		_unload_crates())
	tw.tween_interval(1.1)
	tw.tween_callback(func():
		_truck.texture = sheet
		_truck.hframes = 2
		_truck.flip_h = not _truck.flip_h)
	tw.tween_property(_truck, "global_position", from, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_truck, "modulate:a", 0.0, 1.0)
	tw.tween_callback(func():
		_truck.queue_free()
		_truck = null)


## Shows the crates that were on the truck with a little drop-in bounce.
func _unload_crates() -> void:
	var first := _hide_crates_from
	_hide_crates_from = -1
	if first < 0:
		return
	for c in crates_root.get_children():
		if c.is_queued_for_deletion() or c.visible:
			continue
		c.visible = true
		c.interactable = true
		var target: Vector2 = c.position
		c.position = target + Vector2(0, -40)
		c.modulate.a = 0.0
		var tw := c.create_tween()
		tw.tween_interval(0.12 * (c.crate_index - first))
		tw.tween_property(c, "modulate:a", 1.0, 0.1)
		tw.parallel().tween_property(c, "position", target, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	manager.clear_interactions()


## A staff member ran out of an ingredient (one toast per ingredient until restocked).
## A notification card pops up (once per staff member and ingredient until the
## ingredient is restocked or 20 seconds pass).
func note_out_of_stock(ing: String, who := "") -> void:
	var key := "%s|%s" % [who, ing]
	var now := Time.get_ticks_msec()
	if _out_of_stock_said.has(key) and now - int(_out_of_stock_said[key]) < 20000:
		return
	_out_of_stock_said[key] = now
	var title := "%s is out of %s!" % [who, Market.title(ing)] if who != "" else "Out of %s!" % Market.title(ing)
	hud.notify(title, "Buy more at the Market (back door or M), then claim the crates in the delivery area.",
		PixelArt.food_icon(ing, false, false), Color(0.85, 0.3, 0.2))


## MARKET sign above the back door, and a glow when the manager is next to it.
func _decorate_back_door() -> void:
	for n in _door_extras:
		if is_instance_valid(n):
			n.queue_free()
	_door_extras.clear()
	var door := get_station("BACK_DOOR")
	if door == null:
		return
	var sign_tex := PixelArt.find(["res://assets/market/market_sign.png"])
	if sign_tex:
		var sg := Sprite2D.new()
		sg.texture = sign_tex
		sg.scale = Vector2(3, 3)
		sg.z_index = 2
		sg.position = door.global_position + Vector2(0, -door.size.y / 2.0 - 30)
		add_child(sg)
		_door_extras.append(sg)
	var glow_tex := PixelArt.find(["res://assets/market/back_door_glow.png"])
	if glow_tex:
		var gl := Sprite2D.new()
		gl.name = "BackDoorGlow"
		gl.texture = glow_tex
		gl.scale = Vector2(door.size.x / glow_tex.get_width() * 1.1, door.size.y / glow_tex.get_height() * 1.6)
		gl.position = door.global_position
		gl.z_index = 1
		gl.visible = false
		add_child(gl)
		_door_extras.append(gl)
		if not manager.focus_changed.is_connected(_on_focus_for_glow):
			manager.focus_changed.connect(_on_focus_for_glow)


func _on_focus_for_glow(target: Node) -> void:
	for n in _door_extras:
		if is_instance_valid(n) and n.name == "BackDoorGlow":
			n.visible = target is Station and target.station_id == "BACK_DOOR"


# --- Chef Miso quests (Quest Log): checked while staff programs run -------------

const MisoQuests := preload("res://data/help/miso_quests.gd")
var _miso_k := -1          # quest being watched (index in this level's list)
var _miso_level := 0
var _miso_runs := {}       # staff name -> run_count when that quest started
var _miso_timer := 0.0


## The current Chef Miso quest is done when any staff member's NEW run (Run
## pressed after the quest became current) uses its C idea.
func _check_miso_quest(delta: float) -> void:
	if not tutorials_enabled:
		return
	_miso_timer -= delta
	if _miso_timer > 0.0:
		return
	_miso_timer = 0.25
	var lv: int = GameState.restaurant_level
	var q: Dictionary = GameState.current_miso_quest(lv)
	if q.is_empty():
		return
	var k: int = GameState.miso_progress(lv)
	if k != _miso_k or lv != _miso_level:
		_miso_k = k
		_miso_level = lv
		_miso_runs = {}
		for s in _staff_list():
			_miso_runs[s.staff_name] = s.run_count
		return
	for s in _staff_list():
		if s.run_count > int(_miso_runs.get(s.staff_name, 0)) and MisoQuests.met(q.check, s.run_trace):
			if GameState.complete_miso_quest(lv, k):
				var left: int = MisoQuests.for_level(lv).size() - (k + 1)
				hud.notify("Chef Miso Quest done!", "%s  ✔%s" % [q.topic, ("   Next quest is in your Quest Log." if left > 0 else "   Level Challenge unlocked!")],
					load("res://assets/ui/windows/tutorial/mentor.png"), Color(0.95, 0.7, 0.25), 5.0)
			return
