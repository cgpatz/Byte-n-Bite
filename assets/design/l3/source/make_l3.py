import sys
sys.path.insert(0, '/home/claude/l3work')
from gen_tscn import write

T = 64
WALL = (0.33, 0.23, 0.16)


def w(name, x0, y0, x1, y1, **k):
    return dict(name=name, pos=((x0 + x1) / 2, (y0 + y1) / 2), size=(x1 - x0, y1 - y0), **k)


walls = [
    w("WallTop", 0, 0, 1024, 64),
    w("WallLeft", 0, 64, 64, 1024),
    w("WallRightUpper", 960, 0, 1024, 128),
    w("BackDoor", 960, 128, 1024, 192, sid="BACK_DOOR", disp="Back Door", color=(0.35, 0.55, 0.35),
      info="Back door: the delivery truck parks outside on the service path."),
    w("WallRightLower", 960, 192, 1024, 1024),
    w("DeliveryWallLeft", 704, 64, 768, 192),
    w("HouseWallRight", 704, 448, 768, 704),
    w("HouseWallDeckTop", 768, 448, 960, 512),
    w("HouseWallBottomLeft", 64, 704, 256, 768),
    w("HouseWallBottomRight", 384, 704, 768, 768),
    w("DeckRailBottomLeft", 64, 936, 328, 1024),
    w("DeckRailBottomRight", 632, 936, 960, 1024),
]

stations = [
    # cook line painted on the back wall (baked into the room picture)
    dict(name="Fryer", pos=(544, 96), size=(56, 56), sid="FRYER", disp="Fryer", color=(0.75, 0.6, 0.25),
         info="Fryer: makes fries."),
    dict(name="Grill", pos=(608, 128), size=(56, 120), sid="GRILL", disp="Grill", color=(0.35, 0.35, 0.38),
         info="Grill: cooks patties and meat."),
    dict(name="RiceCooker", pos=(672, 96), size=(56, 56), sid="RICE_COOKER", disp="Rice", color=(0.92, 0.92, 0.85),
         info="Rice Cooker: the only place to cook rice."),
    dict(name="DeliveryRoom", pos=(864, 128), size=(184, 120), sid="RECEIVING", disp="Deliveries",
         color=(0.95, 0.8, 0.3), solid=False,
         info="Delivery room: the truck drops the crates here. Buy ingredients from the store first."),
    dict(name="Fridge", pos=(928, 288), size=(56, 56), sid="FRIDGE", disp="Fridge", color=(0.75, 0.82, 0.88),
         info="Fridge: staff take ingredients from here."),
    dict(name="PrepBoard", pos=(832, 416), size=(120, 56), sid="PREP_BOARD", disp="Prep", color=(0.72, 0.55, 0.35),
         info="Prep Board: chop and prepare ingredients."),
    dict(name="Trash", pos=(672, 544), size=(56, 56), sid="TRASH", disp="Trash", color=(0.3, 0.4, 0.3),
         info="Trash: throw away burnt food."),
    dict(name="Assembly", pos=(576, 640), size=(248, 120), sid="ASSEMBLY", disp="Assembly", color=(0.8, 0.7, 0.5),
         info="Assembly: combine components into a dish."),
    dict(name="ServingCounter", pos=(416, 448), size=(56, 376), sid="SERVING_COUNTER", disp="Serving Counter",
         color=(0.85, 0.62, 0.35), info="Serving Counter: finished dishes go here."),
]
stools = [((352, 352 + 64 * i), "right") for i in range(4)]
decor = [
    dict(name="Shelves", pos=(928, 384), size=(56, 120), color=(0.45, 0.3, 0.2)),
    dict(name="PlantKitchen", pos=(480, 96), size=(48, 48), color=(0.3, 0.5, 0.25)),
    dict(name="PlantDining", pos=(96, 96), size=(48, 48), color=(0.3, 0.5, 0.25)),
    dict(name="PlantDeck", pos=(928, 912), size=(48, 48), color=(0.3, 0.5, 0.25)),
    dict(name="Chalkboard", pos=(352, 76), size=(160, 24), disp="Menu Board", color=(0.2, 0.25, 0.22),
         solid=False, extra={"opens": "upgrades"}),
]
tables = [
    ((160, 224), {}),
    ((160, 544), {}),
    ((192, 864), {"family": True}),
    ((544, 864), {"family": True, "art": "family_table_teal"}),
    ((864, 608), {"art": "umbrella_table"}),
    ((864, 864), {"art": "umbrella_table_teal"}),
]
floors = [
    ("DiningFloor", (64, 64, 384, 704)),
    ("KitchenFloor", (384, 64, 960, 448)),
    ("DeckFloor", (64, 768, 960, 936)),
    ("EntranceFloor", (328, 1024, 632, 1056)),
]
spawns = [("ManagerSpawn", (480, 1000)), ("StaffSpawn1", (544, 288)), ("StaffSpawn2", (672, 352)),
          ("StaffSpawn3", (800, 288))]

write("/home/claude/bnb/scenes/restaurant/levels/L3_NeighborhoodCafe.tscn", "L3_NeighborhoodCafe", "Neighborhood Cafe",
      (16, 16), "res://assets/design/l3/outside/L3_outside_day_960x540.png", (-1408, -352),
      floors, walls, stations, stools, decor, tables, spawns)
print("ok")
