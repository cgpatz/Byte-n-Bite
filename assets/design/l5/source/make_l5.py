import sys
sys.path.insert(0, '/home/claude/l3work')
from gen_tscn import write

T = 64


def w(name, x0, y0, x1, y1, **k):
    return dict(name=name, pos=((x0 + x1) / 2, (y0 + y1) / 2), size=(x1 - x0, y1 - y0), **k)


def s(name, cx, cy, sw, sh, **k):
    """Station from the README's world centre and size (a little smaller, like the other levels)."""
    return dict(name=name, pos=(cx, cy), size=(sw - 8, sh - 8), **k)


CAFE_LOCK = dict(sid="CAFE_DOOR", disp="Café (locked)", color=(0.45, 0.18, 0.14),
                 info="The Café is locked. Press E here to unlock it.")
walls = [
    w("WallTop", 0, 0, 3136, 64),
    w("WallLeftUpper", 0, 64, 64, 704),
    w("BackDoor", 0, 704, 64, 768, sid="BACK_DOOR", disp="Back Door", color=(0.35, 0.55, 0.35),
      info="Back door: the delivery truck parks in the yard outside."),
    w("WallLeftLower", 0, 768, 64, 832),
    w("WallBottomLeft", 0, 832, 1536, 896),
    w("WallBottomRight", 1664, 832, 2112, 896),
    w("DeliveryWallTop", 64, 512, 320, 576),
    w("DeliveryWallRight", 320, 512, 384, 704),
    w("DinerKitchenWallTop", 1024, 64, 1088, 256),
    w("DinerKitchenWallMiddle", 1024, 576, 1088, 640),
    w("DinerKitchenWallBottom", 1024, 768, 1088, 832),
    w("CafeDinerWallTop", 2048, 64, 2112, 192),
    w("CafeDoor", 2048, 192, 2112, 320, **CAFE_LOCK),
    w("SalleTerraceWall", 2048, 320, 2112, 576),
    w("SalleTerraceWallBottom", 2048, 704, 2112, 832),
    w("CafeWallBottomLeft", 2112, 384, 2560, 448),
    w("CafeDoorTerrace", 2560, 384, 2688, 448, **CAFE_LOCK),
    w("CafeWallBottomRight", 2688, 384, 3072, 448),
    w("WallRightCafe", 3072, 64, 3136, 448),
]
C = (0.6, 0.6, 0.6)
stations = [
    s("Fridge", 96, 224, 64, 64, sid="FRIDGE", disp="Fridge", color=(0.75, 0.82, 0.88), info="Fridge: staff take ingredients from here."),
    s("Freezer", 160, 224, 64, 64, sid="FREEZER", disp="Freezer", color=(0.7, 0.85, 0.95), info="Freezer: frozen goods."),
    s("Pantry", 256, 256, 128, 128, sid="PANTRY", disp="Pantry", color=(0.6, 0.45, 0.3), info="Pantry: dry goods."),
    s("PrepBoard", 512, 416, 128, 192, sid="PREP_BOARD", disp="Prep", color=(0.72, 0.55, 0.35), info="Prep Board: chop and prepare ingredients."),
    s("SpiceRack", 640, 416, 128, 192, sid="SPICE_RACK", disp="Spices", color=(0.6, 0.35, 0.25), info="Spice Rack: season dishes."),
    s("Assembly", 800, 384, 192, 128, sid="ASSEMBLY", disp="Assembly", color=(0.8, 0.7, 0.5), info="Assembly: combine components into a dish."),
    s("Grill", 416, 128, 64, 128, sid="GRILL", disp="Grill", color=(0.35, 0.35, 0.38), info="Grill: cooks patties and meat."),
    s("RiceCooker", 480, 96, 64, 64, sid="RICE_COOKER", disp="Rice", color=(0.92, 0.92, 0.85), info="Rice Cooker: the only place to cook rice."),
    s("Fryer", 544, 96, 64, 64, sid="FRYER", disp="Fryer", color=(0.75, 0.6, 0.25), info="Fryer: makes fries."),
    s("Stove", 640, 96, 128, 64, sid="STOVE", disp="Stove", color=(0.4, 0.3, 0.3), info="Stove: boil and stir-fry."),
    s("Oven", 768, 96, 128, 64, sid="OVEN", disp="Oven", color=(0.5, 0.3, 0.2), info="Oven: bakes bread and pastries."),
    s("DishRack", 672, 768, 64, 128, sid="DISH_RACK", disp="Dish Rack", color=C, info="Dish Rack: clean plates."),
    s("Trash", 736, 800, 64, 64, sid="TRASH", disp="Trash", color=(0.3, 0.4, 0.3), info="Trash: throw away burnt food."),
    s("Sink", 864, 800, 192, 64, sid="SINK", disp="Sink", color=(0.6, 0.7, 0.8), info="Sink: wash plates and vegetables."),
    s("ServingCounter", 1056, 416, 64, 320, sid="SERVING_COUNTER", disp="Serving Counter", color=(0.85, 0.62, 0.35),
      info="Serving Counter: finished dishes go here."),
    dict(name="DeliveryRoom", pos=(192, 704), size=(248, 248), sid="RECEIVING", disp="Deliveries", color=(0.95, 0.8, 0.3),
         solid=False, info="Delivery room: the truck drops the crates here. Buy ingredients from the store first."),
    s("CoffeeMachine", 2176, 96, 128, 64, sid="COFFEE_MACHINE", disp="Coffee", color=(0.4, 0.3, 0.25), info="Coffee Machine: espresso drinks."),
    s("DrinksDispenser", 2304, 96, 128, 64, sid="DRINKS_DISPENSER", disp="Drinks", color=(0.8, 0.5, 0.2), info="Drinks Dispenser: juices and sodas."),
    s("Blender", 2400, 96, 64, 64, sid="BLENDER", disp="Blender", color=(0.7, 0.7, 0.75), info="Blender: shakes and smoothies."),
    s("PastryCase", 2272, 288, 320, 64, sid="PASTRY_CASE", disp="Pastry Case", color=(0.9, 0.8, 0.6), info="Pastry Case: croissants and cakes."),
]
decor = [
    s("KitchenShelves", 192, 96, 256, 64, color=C),
    s("KitchenPlant", 992, 96, 64, 64, color=(0.3, 0.5, 0.25)),
    dict(name="Chalkboard", pos=(1504, 800), size=(48, 48), disp="Chalkboard", color=(0.2, 0.25, 0.22),
         extra={"opens": "upgrades"}),
    s("DinerPlantTopLeft", 2016, 96, 64, 64, color=(0.3, 0.5, 0.25)),
    s("DinerPlanterBottomLeft", 1952, 800, 192, 64, color=(0.5, 0.2, 0.2)),
    s("DinerPlanterBottomRight", 1184, 800, 192, 64, color=(0.5, 0.2, 0.2)),
    dict(name="MenuBoard", pos=(2816, 96), size=(120, 56), disp="Café Menu Board", color=(0.2, 0.25, 0.22),
         extra={"opens": "cafe_menu"}),
    s("CafePlant", 2528, 96, 64, 64, color=(0.3, 0.5, 0.25)),
    s("Sofa", 2848, 288, 192, 64, color=(0.6, 0.2, 0.2)),
    s("LoungeTable", 2848, 160, 64, 64, color=(0.4, 0.25, 0.2)),
    s("Armchair", 3040, 192, 64, 128, color=(0.6, 0.2, 0.2)),
    s("Fountain", 3008, 512, 128, 128, color=(0.3, 0.5, 0.75)),
    s("SidewalkPlantersLeft", 2240, 800, 256, 64, color=(0.5, 0.2, 0.2)),
    s("SidewalkPlantersRight", 2912, 800, 320, 64, color=(0.5, 0.2, 0.2)),
]
PATIO = {"art": "patio_table", "chair": "patio_chair"}
tables = [((1952, 160), {}), ((1760, 160), {}), ((1440, 160), {}), ((1248, 160), {}),
          ((1920, 416), {"family": True}), ((1344, 416), {"family": True}),
          ((1952, 672), {}), ((1760, 672), {}), ((1440, 672), {}), ((1248, 672), {}),
          ((2272, 544), PATIO), ((2624, 512), PATIO), ((2432, 704), PATIO), ((2880, 672), PATIO)]
floors = [("EntranceFloor", (1536, 896, 1664, 928))]
spawns = [("ManagerSpawn", (1600, 860)), ("StaffSpawn1", (544, 256)), ("StaffSpawn2", (672, 256)),
          ("StaffSpawn3", (800, 256))]
rooms = [("Kitchen", (0, 0, 1088, 896)), ("Diner", (1088, 0, 2112, 896)), ("Cafe", (2112, 0, 3136, 896))]
write("/home/claude/bnb/scenes/restaurant/levels/L5_GrandRestaurant.tscn", "L5_GrandRestaurant", "Grand Restaurant",
      (49, 14), "res://assets/design/l5/outside/L5_outside_day_1104x432.png", (-576, -256),
      floors, walls, stations, [], decor, tables, spawns, rooms=rooms)
print("ok")
