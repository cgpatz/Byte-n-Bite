# Byte n' Bite — Pixel Art Guide

## 1. The rules (read once)

- **Draw on a 16 px grid: 1 tile = 16 × 16 art pixels.** The game shows every
  pixel 4× bigger (1 tile = 64 × 64 on screen) with crisp, unblurred pixels.
- **Save as PNG with transparency.** Draw at 1× (don't upscale before saving).
- **Top-down, 3/4 view.** Things can be taller than their floor tiles (a fridge
  can be 16 × 24): the bottom of the image sits on the station's tiles and the
  extra height rises above.
- **Art is found by file name.** Drop the PNG in the right folder with the right
  name and it appears in the game. Nothing to drag into the Inspector. Missing
  files keep the placeholder shapes, so you can add art one piece at a time.
- **Per-level versions (optional):** put a file in a level folder to override it
  for that level only, e.g. `assets/stations/L5/grill.png` is used in Level 5
  and `assets/stations/grill.png` everywhere else.
- **Seeing new art:** play the game (it loads on start). In the editor, select
  the level's top node and press **Reload Art** in the Inspector.
- **Hiding placeholders:** in game, **Admin Run → F10 → untick "Show
  placeholder boxes"**. In a level scene, untick **Show Greybox** on the top node.

## 2. Tracing templates

`assets/_templates/` has every layout as a picture (Godot ignores this folder):

| File | Use |
|---|---|
| `L1_TinyStall_16px.png` … `L5_GrandRestaurant_16px.png` | **Paint your background on top of these.** Exact size, 1 tile = 16 px |
| `L5_cafe_16px.png`, `L5_diner_16px.png`, `L5_kitchen_16px.png` | Level 5 rooms, one background each |
| `*_64px.png` | Same layouts at game size, with names and a tile grid, for reference |

After moving stations or walls, open `tools/ExportLayoutTemplates.tscn` and
press **F6** to make fresh templates.

## 3. Characters (walk sheets)

Name the file `<name>_sheet.png` for an animated walk cycle, or `<name>.png` for
a single still image.

```
Walk sheet: 4 rows × 4 frames, each frame 16 wide × 24 tall  ->  64 × 96 px
  row 1: walking DOWN   (frame 1 = standing pose)
  row 2: walking UP
  row 3: walking LEFT
  row 4: walking RIGHT
```

- Frames can also be 16 × 16 (sheet 64 × 64). Any number of frames per row works.
- Feet go at the **bottom** of the frame; the game places the feet on the
  character's floor position.
- The held food item is drawn at the character's right hand; leave that side
  readable.

Where they go:

| File | Who |
|---|---|
| `assets/character/manager_sheet.png` | the manager (player) |
| `assets/character/staff/<name>_sheet.png` | Jane, John, Lee, Rose, Gab (lower-case file names) |
| `assets/character/customers/<name>_sheet.png` | every customer; a new file here is a new customer |
| `assets/character/customers/<name>_sit.png` | optional seated pose: 3 frames of 16 × 24 (48 × 24): facing down, left, right |

## 4. File names and sizes

### Backgrounds — `assets/backgrounds/levels/`

Floor, walls, doors, windows and painted-on details. Walls are **not** separate
pieces: paint them into the background.

| File | Size (px) | Tiles |
|---|---|---|
| `L1.png` Tiny Stall | 128 × 128 | 8 × 8 |
| `L2.png` Small Diner | 192 × 160 | 12 × 10 |
| `L3.png` Neighborhood Cafe | 256 × 224 | 16 × 14 |
| `L4.png` Busy Eatery | 352 × 288 | 22 × 18 |
| `L5_cafe.png`, `L5_diner.png`, `L5_kitchen.png` | 272 × 224 each | 17 × 14 each |

Level 5 rooms share their wall column, so the edges overlap by one tile.

### Kitchen stations — `assets/stations/`

Size = the station's floor tiles × 16. Taller is fine (it rises upward).
**Bold** sizes differ from the other levels, so put that one in a level folder
(e.g. `stations/L5/grill.png`).

| File | L1 | L2 | L3 | L4 | L5 |
|---|---|---|---|---|---|
| `grill.png` | 32×16 | 32×16 | 32×16 | 32×16 | **16×32** |
| `assembly.png` | 32×16 | 32×16 | **80×16** | **128×16** | **48×32** |
| `fridge.png` | 16×16 | 16×16 | **16×32** | **16×32** | **16×32** |
| `serving_counter.png` | **64×16** | 128×16 | 128×16 | **208×16** | **16×48** (window) |
| `receiving.png` (delivery floor area) | **16×32** | 32×32 | 32×32 | **48×48** | **48×64** |
| `back_door.png` | 16×16 | 16×16 | 16×16 | 16×16 | 16×16 |
| `fryer.png` | — | 32×16 | 32×16 | 32×16 | **16×16** |
| `trash.png` | — | 16×16 | 16×16 | 16×16 | 16×16 |
| `prep_board.png` | — | — | 32×16 | 32×16 | **32×48** (island) |
| `stove.png` | — | — | — | 32×16 | 32×16 |
| `sink.png` | — | — | — | 32×16 | **48×16** |
| `pantry.png`, `oven.png`, `coffee_machine.png`, `drinks_dispenser.png` | — | — | — | — | 32×16 each |
| `freezer.png`, `dish_rack.png` | — | — | — | — | 16×32 each |
| `blender.png`, `rice_cooker.png` | — | — | — | — | 16×16 each |
| `pastry_case.png` | — | — | — | — | 64×16 |
| `spice_rack.png` (island) | — | — | — | — | 32×48 |

Long counters (assembly, serving counter) can also be painted into the
background instead; then leave their file out and hide the placeholders.

### Furniture and decor — `assets/decor/`

| File | Size | Where |
|---|---|---|
| `table.png` | 16×16 | every level (bought tables) |
| `chair.png` | about 10×10 | around tables (left, right, top, bottom) |
| `stool.png` | about 8×8 | counter stools, L2–L4 |
| `plant.png` | 16×16 | L1–L4 |
| `awning.png` | 64×16 | L1 (use the `Foreground` layer if it should cover characters) |
| `chalkboard.png` | 16×16 | L1 |
| `plants.png` (planter box) | L3 32×16, L4 48×16 | use `decor/L3/`, `decor/L4/` |
| `shelves.png` | 16×48 | L3, L4 |
| `booth.png` | 16×32 | L3 |
| `tea_shelf.png`, `sofa.png`, `kitchen_shelves.png`, `kitchen_planters.png` | 48×16 | L5 |
| `menu_board.png` | 32×16 | L5 cafe |
| `cafe_planters.png` | 64×16 | L5 cafe |
| `diner_planter.png` | 48×16 and 64×16 | L5 diner (draw 48 wide; the long ones get a gap) |
| `cafe_plant.png`, `diner_plant.png`, `kitchen_plant.png`, `lounge_table.png`, `cafe_armchair.png`, `staff_door.png` | 16×16 | L5 |
| `armchair.png` | 16×32 | L5 cafe |

Small details that don't block walking (rugs, cups, signs) can go in the
level's `Art/Props` node as Sprite2D nodes (set Scale to 4, 4).

### Characters — `assets/character/`

| File | Size |
|---|---|
| `manager_sheet.png` | 64×96 |
| `staff/jane_sheet.png`, `staff/ben_sheet.png`, `staff/carla_sheet.png`, `staff/dan_sheet.png`, `staff/ella_sheet.png`, `staff/finn_sheet.png` | 64×96 each |
| `customers/…` (customer system not built yet) | 64×96 each, plus a sitting pose |

### Food — `assets/food/` (12 × 12 each, shown 48 × 48)

- **Ingredients** (`food/ingredients/`): `rice`, `egg`, `hotdog`, `tocino`,
  `bread`, `cheese`, `bun`, `patty`, `lettuce`, `tomato`, `chicken`,
  `noodles`.
- **Cooked versions** (`<name>_cooked.png`): `rice_cooked` (fried rice),
  `egg_cooked`, `hotdog_cooked`, `tocino_cooked`, `bread_cooked` (toast),
  `patty_cooked`, `chicken_cooked`, `noodles_cooked`.
- **Dishes** (`food/dishes/`): `egsilog`, `hotsilog`, `tocilog`,
  `grilled_cheese`, `hamburger`, `fried_chicken_meal`, `garden_salad`,
  `cheeseburger`, `pancit_canton`, `chicken_sandwich`,
  `double_cheeseburger`, `silog_platter`, `signature_bowl`.

### UI — `assets/ui/`

| File | Size | Shown |
|---|---|---|
| `hud/coin.png`, `hud/restaurant.png`, `hud/manager_level.png`, `hud/exp.png` | 16×16 | 2× in the top bar |
| `icons/start.png`, `new_game.png`, `load_game.png`, `settings.png`, `exit.png` | 16×16 | 3× on the menu buttons |
| `../backgrounds/main_menu_bg.png` | 480×270 | 4× = full screen |
| `logo/logo.png` (logo + "Cook. Code. Create.") | about 260×210 | fits the logo area |

## 5. What to draw, by priority

### Priority 1 — Level 1 playable with art (draw first)

- [ ] Manager walk sheet
- [ ] Jane walk sheet
- [ ] Level 1 background (`L1.png`, trace `L1_TinyStall_16px.png`)
- [ ] L1 stations: grill, assembly, fridge, serving counter (64×16), back door, delivery area
- [ ] Table and chair
- [ ] Level 1 food: rice, egg, hotdog (raw and cooked); dishes egsilog, hotsilog
- [ ] Top-bar icons: coin, restaurant, manager level, EXP
- [ ] Main menu: background, logo, 5 button icons
- [ ] Choose a pixel font (a free one is fine; it gets set in `game_theme.tres`)

### Priority 2 — Level 2 and the next features (customers and deliveries)

- [ ] Level 2 background
- [ ] Fryer, trash, stool, plant
- [ ] Level 2 food: tocino, bread, cheese (+ cooked tocino, toast); dishes tocilog, grilled cheese
- [ ] 3–4 customer walk sheets and a sitting pose
- [ ] Customer reactions (16×16): happy, okay, upset; order speech bubble
- [ ] Delivery crate (16×16)

### Priority 3 — Levels 3 and 4

- [ ] Level 3 and Level 4 backgrounds
- [ ] Prep board, stove, sink; bigger counters and fridge for L3/L4 (see the table)
- [ ] Shelves, booth, planter boxes
- [ ] Level 3–4 food: bun, patty, lettuce, tomato, chicken, noodles (+ cooked patty, chicken, noodles); 6 dishes
- [ ] Staff: Ben, Carla, Dan

### Priority 4 — Level 5 and polish

- [ ] Level 5 backgrounds: cafe, diner, kitchen
- [ ] Level 5 stations (coffee machine, blender, drinks dispenser, pastry case, pantry, oven, freezer, rice cooker, spice rack, dish rack) and L5 versions of grill, fryer, prep board, assembly, sink, serving window
- [ ] Level 5 decor (sofa, armchairs, tea shelf, menu board, planters, plants)
- [ ] Level 5 dishes: double cheeseburger, silog platter, signature bowl
- [ ] Staff: Ella, Finn
- [ ] UI skin: panel frame and button (9-slice), Challenge Board, Recipe Book pages
- [ ] Effects: level-up burst, coin pop, cooking steam/sizzle
- [ ] Staff specialization badges: Chef, Assistant Chef, Sales

## 6. Rules that keep the game working

- Keep each station's **Station Id** (e.g. `GRILL`): staff code and the art
  loader both use it.
- Resize a station with its **Size** property, not the Scale tool.
- Tables appear at the `TableSlots` markers; move the markers to move tables.
- Level 5 camera rooms are the frames under `Rooms`.
- A station can still use its own image: set **Art** in the Inspector (tick
  **Art Fit** to stretch it to the box instead of drawing it 4×).
