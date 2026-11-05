import sys
sys.path.insert(0, '/home/claude/l3work')
from gen_tscn import write

T = 64


def w(name, x0, y0, x1, y1, **k):
    return dict(name=name, pos=((x0 + x1) / 2, (y0 + y1) / 2), size=(x1 - x0, y1 - y0), **k)


def t(name, tx, ty, tw, th, **k):
    """Station by tile rect (README grid)."""
    return dict(name=name, pos=((tx + tw / 2) * T, (ty + th / 2) * T), size=(tw * T - 8, th * T - 8), **k)


walls = [
    w("WallTop", 0, 0, 1408, 64),
    w("WallLeft", 0, 64, 64, 1152),
    w("WallRightUpper", 1344, 0, 1408, 128),
    w("BackDoor", 1344, 128, 1408, 192, sid="BACK_DOOR", disp="Back Door", color=(0.35, 0.55, 0.35),
      info="Back door: the delivery truck parks at the loading dock outside."),
    w("WallRightLower", 1344, 192, 1408, 1152),
    w("DeliveryWallLeft", 1088, 64, 1152, 192),
    w("WallBottomLeft", 64, 1088, 512, 1152),
    w("WallBottomRight", 896, 1088, 1344, 1152),
    # courtyard: walls on columns 8 and 13 (side doors at rows 12-13), row 9 beside the entrance
    w("CourtWallLeftUpper", 512, 576, 576, 768),
    w("CourtWallLeftLower", 512, 896, 576, 1152),
    w("CourtWallRightUpper", 832, 576, 896, 768),
    w("CourtWallRightLower", 832, 896, 896, 1152),
    w("CourtWallTopLeft", 576, 576, 640, 640),
    w("CourtWallTopRight", 768, 576, 832, 640),
]
stations = [
    t("Sink", 1, 1, 2, 1, sid="SINK", disp="Sink", color=(0.6, 0.7, 0.8), info="Sink: wash plates and vegetables."),
    t("Trash", 3, 1, 1, 1, sid="TRASH", disp="Trash", color=(0.3, 0.4, 0.3), info="Trash: throw away burnt food."),
    t("Grill", 5, 1, 2, 1, sid="GRILL", disp="Grill", color=(0.35, 0.35, 0.38), info="Grill: cooks patties and meat."),
    t("Fryer", 7, 1, 2, 1, sid="FRYER", disp="Fryer", color=(0.75, 0.6, 0.25), info="Fryer: makes fries."),
    t("Stove", 9, 1, 2, 1, sid="STOVE", disp="Stove", color=(0.4, 0.3, 0.3), info="Stove: boil and stir-fry."),
    t("RiceCooker", 11, 1, 1, 1, sid="RICE_COOKER", disp="Rice", color=(0.92, 0.92, 0.85),
      info="Rice Cooker: the only place to cook rice."),
    t("Fridge", 16, 1, 1, 1, sid="FRIDGE", disp="Fridge", color=(0.75, 0.82, 0.88), info="Fridge: staff take ingredients from here."),
    dict(name="DeliveryRoom", pos=(1248, 160), size=(184, 184), sid="RECEIVING", disp="Deliveries",
         color=(0.95, 0.8, 0.3), solid=False,
         info="Delivery room: the truck drops the crates here. Buy ingredients from the store first."),
    t("Assembly", 4, 4, 10, 1, sid="ASSEMBLY", disp="Assembly", color=(0.8, 0.7, 0.5),
      info="Assembly: combine components into a dish."),
    t("PrepBoard", 14, 4, 2, 1, sid="PREP_BOARD", disp="Prep", color=(0.72, 0.55, 0.35),
      info="Prep Board: chop and prepare ingredients."),
    t("ServingCounter", 3, 7, 16, 1, sid="SERVING_COUNTER", disp="Serving Counter", color=(0.85, 0.62, 0.35),
      info="Serving Counter: finished dishes go here."),
]
stools = [((x, 544), "up") for x in (288, 416, 544, 864, 992, 1120)]
decor = [
    t("Shelves", 12, 1, 4, 1, color=(0.45, 0.3, 0.2)),
    t("WaitingBench", 9, 10, 1, 2, color=(0.5, 0.35, 0.2)),
    dict(name="Pond", pos=(784, 932), size=(80, 104), color=(0.3, 0.45, 0.7)),
    dict(name="Chalkboard", pos=(800, 716), size=(44, 56), disp="Stone Lantern", color=(0.55, 0.55, 0.6),
         extra={"opens": "upgrades"}),
    t("PlanterLeft", 9, 16, 1, 1, color=(0.3, 0.5, 0.25)),
    t("PlanterRight", 12, 16, 1, 1, color=(0.3, 0.5, 0.25)),
    t("PlantLeft", 1, 16, 1, 1, color=(0.3, 0.5, 0.25)),
    t("PlantRight", 20, 16, 1, 1, color=(0.3, 0.5, 0.25)),
]
tables = [((160, 704), {}), ((384, 704), {}), ((160, 928), {}), ((384, 928), {}),
          ((992, 704), {}), ((1216, 704), {}), ((992, 928), {}), ((1216, 928), {}),
          ((704, 832), {"art": "parasol_table"})]
floors = [("EntranceFloor", (576, 1152, 832, 1184))]
spawns = [("ManagerSpawn", (704, 1100)), ("StaffSpawn1", (384, 192)), ("StaffSpawn2", (640, 192)),
          ("StaffSpawn3", (896, 192))]
write("/home/claude/bnb/scenes/restaurant/levels/L4_BusyEatery.tscn", "L4_BusyEatery", "Busy Eatery",
      (22, 18), "res://assets/design/l4/outside/L4_outside_day_768x432.png", (-800, -176),
      floors, walls, stations, stools, decor, tables, spawns)
print("ok")
