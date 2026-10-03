extends Resource
class_name RestaurantLevelData
## One restaurant level: its layout scene, caps and costs.
## Edit the .tres files in data/levels/ to rebalance without touching code.

@export var level := 1
@export var display_name := "Tiny Stall"
@export var layout_scene: PackedScene
## C concept this level teaches (shown in the upgrade panel).
@export var c_focus := ""
@export var table_cap := 2
@export var max_chairs_per_table := 2
## Coins to upgrade FROM this level to the next (0 at the last level).
@export var upgrade_cost := 0
@export var table_base_cost := 40
@export var chair_cost := 15
