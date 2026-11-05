"""Writes a restaurant level .tscn from a compact Python description."""


def station(name, parent, pos, size, sid="", disp="", color=(0.33, 0.23, 0.16), solid=True,
            interactable=None, info="", extra=None, layer2=False, meta=None):
    L = [f'[node name="{name}" parent="{parent}" instance=ExtResource("2_station")]',
         f"position = Vector2({pos[0]}, {pos[1]})"]
    if layer2 or not solid:
        L.append("collision_layer = 2")
    L.append("collision_mask = 0")
    L.append(f'station_id = "{sid}"')
    L.append(f'display_name = "{disp}"')
    L.append(f"size = Vector2({size[0]}, {size[1]})")
    L.append("color = Color(%s, %s, %s, 1)" % color)
    if not disp:
        L.append("show_label = false")
    if not solid:
        L.append("solid = false")
    if interactable is False or (interactable is None and not sid and not (extra or {}).get("opens")):
        L.append("interactable = false")
    if info:
        L.append(f'info_text = "{info}"')
    for k, v in (extra or {}).items():
        L.append(f'{k} = "{v}"' if isinstance(v, str) else f"{k} = {v}")
    for k, v in (meta or {}).items():
        L.append(f'metadata/{k} = "{v}"' if isinstance(v, str) else f"metadata/{k} = {str(v).lower() if isinstance(v, bool) else v}")
    return "\n".join(L) + "\n"


def rect_node(name, parent, r, color=(0.5, 0.35, 0.24)):
    x0, y0, x1, y1 = r
    return (f'[node name="{name}" type="ColorRect" parent="{parent}"]\n'
            f"offset_left = {x0}\noffset_top = {y0}\noffset_right = {x1}\noffset_bottom = {y1}\n"
            f"mouse_filter = 2\ncolor = Color({color[0]}, {color[1]}, {color[2]}, 1)\n")


def marker(name, parent, pos, meta=None):
    s = f'[node name="{name}" type="Marker2D" parent="{parent}"]\nposition = Vector2({pos[0]}, {pos[1]})\n'
    for k, v in (meta or {}).items():
        s += (f'metadata/{k} = "{v}"\n' if isinstance(v, str) else f"metadata/{k} = {str(v).lower() if isinstance(v, bool) else v}\n")
    return s


def write(path, root, level_name, grid, outside, outside_pos, floors, walls, stations, stools, decor,
          tables, spawns, rooms=None, extra_ext=""):
    out = [f'[gd_scene format=3]\n',
           '[ext_resource type="Script" path="res://scenes/restaurant/restaurant.gd" id="1_layout"]',
           '[ext_resource type="PackedScene" path="res://scenes/stations/Station.tscn" id="2_station"]',
           '[ext_resource type="Script" path="res://scenes/restaurant/grid_overlay.gd" id="3_grid"]',
           '[ext_resource type="Script" path="res://scenes/restaurant/art_background.gd" id="90_artbg"]',
           '[ext_resource type="TileSet" path="res://assets/tiles/restaurant_tileset.tres" id="91_tiles"]',
           f'[ext_resource type="Texture2D" path="{outside}" id="92_outside"]', extra_ext, '',
           f'[node name="{root}" type="Node2D"]', 'script = ExtResource("1_layout")',
           f'level_name = "{level_name}"', f"grid_size = Vector2i({grid[0]}, {grid[1]})",
           "show_greybox = false", "outside_view = true", '',
           '[node name="Floor" type="Node2D" parent="."]', '']
    for n, r in floors:
        out.append(rect_node(n, "Floor", r))
    out += ['[node name="Art" type="Node2D" parent="."]', '',
            '[node name="Outside" type="Sprite2D" parent="Art"]', "z_index = -10", "texture_filter = 1",
            f"position = Vector2({outside_pos[0]}, {outside_pos[1]})", "scale = Vector2(4, 4)",
            'texture = ExtResource("92_outside")', "centered = false", '']
    if rooms:
        pass
    else:
        out += ['[node name="Background" type="Sprite2D" parent="Art"]', "texture_filter = 1", "centered = false",
                'script = ExtResource("90_artbg")', f"fit_size = Vector2({grid[0] * 64}, {grid[1] * 64})", '']
    out += ['[node name="Tiles" type="TileMapLayer" parent="Art"]', 'tile_set = ExtResource("91_tiles")', '',
            '[node name="Props" type="Node2D" parent="Art"]', "y_sort_enabled = true", '',
            '[node name="Walls" type="Node2D" parent="."]', '']
    for w in walls:
        out.append(station(parent="Walls", **w))
    out += ['[node name="Stations" type="Node2D" parent="."]', '']
    for s in stations:
        out.append(station(parent="Stations", **s))
    out += ['[node name="CounterStools" type="Node2D" parent="Stations"]', '']
    for i, (p, facing) in enumerate(stools):
        out.append(station(f"Stool{i + 1}", "Stations/CounterStools", p, (28, 28), color=(0.75, 0.2, 0.18),
                           solid=False, meta={"facing": facing}))
    out += ['[node name="Decor" type="Node2D" parent="Stations"]', '']
    for d in decor:
        out.append(station(parent="Stations/Decor", **d))
    out += ['[node name="TableSlots" type="Node2D" parent="."]', '']
    for i, (p, meta) in enumerate(tables):
        out.append(marker(f"TableSlot{i + 1}", "TableSlots", p, meta))
    out += ['[node name="Spawns" type="Node2D" parent="."]', '']
    for n, p in spawns:
        out.append(marker(n, "Spawns", p))
    if rooms:
        out += ['[node name="Rooms" type="Node2D" parent="."]', '']
        for n, r in rooms:
            x0, y0, x1, y1 = r
            out.append(f'[node name="{n}" type="ReferenceRect" parent="Rooms"]\noffset_left = {x0}\noffset_top = {y0}\n'
                       f'offset_right = {x1}\noffset_bottom = {y1}\nmouse_filter = 2\neditor_only = true\n')
    out += ['[node name="GridOverlay" type="Node2D" parent="."]', 'script = ExtResource("3_grid")',
            f"grid_size = Vector2i({grid[0]}, {grid[1]})", '',
            '[node name="Foreground" type="Node2D" parent="."]', "z_index = 10", '']
    open(path, "w").write("\n".join(out))
