extends RefCounted

## Static game data: tribes, buildings, units, production/cost formulas.
##
## Resources are always a 4-element array [wood, clay, iron, crop] so that
## every economic loop is a plain `for r in range(4)`.

const W := 0
const C := 1
const I := 2
const CR := 3
const RES_NAMES := ["wood", "clay", "iron", "crop"]
const RES_ICONS := ["🪵", "🧱", "⛏️", "🌾"]
const RES_LABELS := ["Дерево", "Глина", "Железо", "Зерно"]

const TRIBE_ROMANS := "romans"
const TRIBE_GAULS := "gauls"
const TRIBE_GERMANS := "germans"

# ---------------------------------------------------------------------------
# Tribes
# ---------------------------------------------------------------------------

const TRIBES := {
	"romans": {
		"label": "Римляне",
		"blurb": "Баланс. Сильная пехота, две очереди строительства, крепкая стена.",
		"wall_id": "wall",
		"wall_label": "Городская стена",
		"wall_factor": 0.030,      # +3.0% defence per wall level
		"cranny_factor": 1.0,
		"merchant_carry": 500,
		"merchant_speed": 16.0,
		"raid_bonus": 0.0,         # extra loot fraction
		"ignores_cranny": false,
		"double_queue": true,      # can build a field and a centre building at once
	},
	"gauls": {
		"label": "Галлы",
		"blurb": "Оборона и скорость. Лучшие защитники, быстрые торговцы, большой тайник.",
		"wall_id": "palisade_gaul",
		"wall_label": "Земляной вал",
		"wall_factor": 0.025,
		"cranny_factor": 2.0,
		"merchant_carry": 750,
		"merchant_speed": 24.0,
		"raid_bonus": 0.0,
		"ignores_cranny": false,
		"double_queue": false,
	},
	"germans": {
		"label": "Германцы",
		"blurb": "Агрессия. Дешёвые войска, лучший грабёж, игнорируют вражеский тайник.",
		"wall_id": "palisade",
		"wall_label": "Частокол",
		"wall_factor": 0.020,
		"cranny_factor": 0.66,
		"merchant_carry": 400,
		"merchant_speed": 12.0,
		"raid_bonus": 0.10,
		"ignores_cranny": true,
		"double_queue": false,
	},
}

# Gauls get a 2x defensive wall bonus on top of the per-level factor.
const GAUL_WALL_DEF_MULT := 2.0

# ---------------------------------------------------------------------------
# Resource fields
# ---------------------------------------------------------------------------

## Hourly output per field level (index = level, 0..20).
const PROD_WCI := [2, 5, 12, 22, 35, 55, 85, 120, 165, 220, 300,
		390, 500, 630, 780, 960, 1160, 1380, 1620, 1880, 2160]
const PROD_CROP := [2, 5, 14, 26, 42, 65, 100, 145, 200, 270, 370,
		480, 620, 790, 980, 1210, 1470, 1750, 2060, 2390, 2750]

## Field upgrade cost at level 0 -> 1, indexed by resource; later levels scale
## by FIELD_COST_GROWTH. Indexed by W/C/I/CR, so the order here must match.
const FIELD_BASE_COST := [
	[40, 100, 50, 60],      # wood field
	[80, 40, 80, 50],       # clay pit
	[100, 80, 30, 60],      # iron mine
	[70, 90, 70, 20],       # cropland
]
const FIELD_COST_GROWTH := 1.67
const FIELD_BASE_TIME := 150.0     # seconds for level 0 -> 1
const FIELD_TIME_GROWTH := 1.6
const FIELD_POP := [0, 2, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 5]

## Classic 4-4-4-6 field layout, plus the polar coordinates used to draw the ring.
const FIELD_LAYOUT := [
	{"res": W, "ang": 250.0, "r": 0.78}, {"res": W, "ang": 272.0, "r": 0.90},
	{"res": W, "ang": 296.0, "r": 0.80}, {"res": W, "ang": 318.0, "r": 0.92},
	{"res": C, "ang": 340.0, "r": 0.80}, {"res": C, "ang": 3.0, "r": 0.92},
	{"res": C, "ang": 26.0, "r": 0.80}, {"res": C, "ang": 48.0, "r": 0.92},
	{"res": I, "ang": 152.0, "r": 0.92}, {"res": I, "ang": 174.0, "r": 0.80},
	{"res": I, "ang": 196.0, "r": 0.92}, {"res": I, "ang": 218.0, "r": 0.80},
	{"res": CR, "ang": 70.0, "r": 0.80}, {"res": CR, "ang": 90.0, "r": 0.92},
	{"res": CR, "ang": 110.0, "r": 0.80}, {"res": CR, "ang": 128.0, "r": 0.92},
	{"res": CR, "ang": 236.0, "r": 0.92}, {"res": CR, "ang": 60.0, "r": 0.62},
]

# ---------------------------------------------------------------------------
# Buildings
# ---------------------------------------------------------------------------
#
# cost      : level-1 cost, later levels scale by COST_GROWTH
# time       : level-1 build time in seconds, scales by TIME_GROWTH
# pop        : population (and therefore crop upkeep) added per level
# cp         : culture points per hour added per level
# max        : maximum level
# needs      : {building_id: required_level} prerequisites
# tribe      : restrict to a single tribe (optional)
# art        : sprite basename under Assets/Art/Buildings

const COST_GROWTH := 1.28
const TIME_GROWTH := 1.30
const MIN_BUILD_TIME := 20.0

const BUILDINGS := {
	"main": {
		"label": "Главное здание", "icon": "🏛️", "art": "01_Main_Building",
		"cost": [70, 40, 60, 20], "time": 80.0, "pop": 2, "cp": 2, "max": 20,
		"needs": {}, "desc": "Ускоряет всё строительство в деревне на 3% за уровень.",
	},
	"warehouse": {
		"label": "Склад", "icon": "📦", "art": "02_Warehouse",
		"cost": [130, 160, 90, 40], "time": 120.0, "pop": 1, "cp": 1, "max": 20,
		"needs": {}, "desc": "Хранит дерево, глину и железо. Без него ресурсы сгорают.",
	},
	"granary": {
		"label": "Амбар", "icon": "🌾", "art": "03_Granary",
		"cost": [80, 100, 70, 20], "time": 110.0, "pop": 1, "cp": 1, "max": 20,
		"needs": {}, "desc": "Хранит зерно.",
	},
	"cranny": {
		"label": "Тайник", "icon": "🕳️", "art": "22_Cranny_Trapper",
		"cost": [40, 50, 30, 10], "time": 60.0, "pop": 0, "cp": 1, "max": 20,
		"needs": {}, "desc": "Прячет ресурсы от грабежа.",
	},
	"marketplace": {
		"label": "Рынок", "icon": "🛒", "art": "07_Marketplace",
		"cost": [80, 70, 120, 70], "time": 180.0, "pop": 4, "cp": 3, "max": 20,
		"needs": {"main": 3, "warehouse": 1, "granary": 1},
		"desc": "Торговцы возят ресурсы между твоими деревнями.",
	},
	"embassy": {
		"label": "Посольство", "icon": "🏳️", "art": "16_Embassy",
		"cost": [180, 130, 150, 80], "time": 240.0, "pop": 3, "cp": 5, "max": 20,
		"needs": {"main": 1}, "desc": "Даёт культуру и открывает Ратушу.",
	},
	"residence": {
		"label": "Резиденция", "icon": "👑", "art": "08_Residence",
		"cost": [580, 460, 350, 180], "time": 800.0, "pop": 1, "cp": 2, "max": 20,
		"needs": {"main": 5}, "desc": "Защищает от захвата, готовит поселенцев. Ур.10 и 20 дают слот расширения.",
	},
	"palace": {
		"label": "Дворец", "icon": "🏯", "art": "09_TownHall_Palace",
		"cost": [550, 800, 750, 250], "time": 1400.0, "pop": 1, "cp": 6, "max": 20,
		"needs": {"main": 10, "embassy": 1},
		"desc": "Столица. Ур.10/15/20 дают слоты расширения. Только одна на игрока.",
	},
	"town_hall": {
		"label": "Ратуша", "icon": "🎪", "art": "09_TownHall_Palace",
		"cost": [1250, 1110, 1250, 600], "time": 2000.0, "pop": 4, "cp": 8, "max": 20,
		"needs": {"main": 10, "embassy": 1}, "desc": "Праздники дают большие разовые порции культуры.",
	},
	"trade_office": {
		"label": "Торговая палата", "icon": "⚖️", "art": "24_Treasury",
		"cost": [1400, 1330, 1200, 400], "time": 1800.0, "pop": 3, "cp": 3, "max": 20,
		"needs": {"marketplace": 10, "stable": 10}, "desc": "+10% скорости и вместимости торговцев за уровень.",
	},
	"treasury": {
		"label": "Сокровищница", "icon": "💎", "art": "24_Treasury",
		"cost": [2880, 2740, 2580, 990], "time": 3000.0, "pop": 4, "cp": 6, "max": 20,
		"needs": {"main": 10}, "desc": "Хранит трофеи. Даёт много культуры.",
	},
	# --- production bonuses ---
	"sawmill": {
		"label": "Лесопилка", "icon": "🪚", "art": "11_Sawmill",
		"cost": [520, 380, 290, 90], "time": 600.0, "pop": 4, "cp": 1, "max": 5,
		"needs": {"main": 5}, "needs_field": [W, 10], "bonus_res": W, "bonus_per_level": 0.05,
		"desc": "+5% к дереву за уровень (макс +25%). Нужны все лесные поля 10 ур.",
	},
	"brickyard": {
		"label": "Кирпичный завод", "icon": "🧱", "art": "12_Brickyard",
		"cost": [440, 480, 320, 50], "time": 600.0, "pop": 3, "cp": 1, "max": 5,
		"needs": {"main": 5}, "needs_field": [C, 10], "bonus_res": C, "bonus_per_level": 0.05,
		"desc": "+5% к глине за уровень (макс +25%).",
	},
	"iron_foundry": {
		"label": "Литейный завод", "icon": "⚙️", "art": "13_Iron_Foundry",
		"cost": [200, 450, 510, 120], "time": 700.0, "pop": 6, "cp": 1, "max": 5,
		"needs": {"main": 5}, "needs_field": [I, 10], "bonus_res": I, "bonus_per_level": 0.05,
		"desc": "+5% к железу за уровень (макс +25%).",
	},
	"grain_mill": {
		"label": "Мельница", "icon": "🌀", "art": "14_Grain_Mill",
		"cost": [500, 440, 380, 1240], "time": 700.0, "pop": 3, "cp": 1, "max": 5,
		"needs": {"main": 5}, "needs_field": [CR, 5], "bonus_res": CR, "bonus_per_level": 0.05,
		"desc": "+5% к зерну за уровень (макс +25%).",
	},
	"bakery": {
		"label": "Пекарня", "icon": "🍞", "art": "15_Bakery",
		"cost": [1200, 1480, 870, 1600], "time": 1400.0, "pop": 4, "cp": 2, "max": 5,
		"needs": {"main": 5, "grain_mill": 5}, "needs_field": [CR, 10],
		"bonus_res": CR, "bonus_per_level": 0.10,
		"desc": "+10% к зерну за уровень (макс +50%). Складывается с мельницей до +75%.",
	},
	# --- military ---
	"rally_point": {
		"label": "Пункт сбора", "icon": "⛺", "art": "19_Rally_Point",
		"cost": [110, 160, 90, 70], "time": 100.0, "pop": 0, "cp": 1, "max": 20,
		"needs": {}, "desc": "Отправка и приём войск. Без него армия никуда не пойдёт.",
	},
	"barracks": {
		"label": "Казарма", "icon": "🛡️", "art": "04_Barracks",
		"cost": [210, 140, 260, 120], "time": 300.0, "pop": 4, "cp": 1, "max": 20,
		"needs": {"main": 3, "rally_point": 1}, "trains": "barracks",
		"desc": "Пехота. Каждый уровень ускоряет обучение на 10%.",
	},
	"stable": {
		"label": "Конюшня", "icon": "🐴", "art": "05_Stable",
		"cost": [260, 140, 220, 100], "time": 500.0, "pop": 5, "cp": 2, "max": 20,
		"needs": {"academy": 5, "smithy": 3}, "trains": "stable",
		"desc": "Кавалерия и разведчики.",
	},
	"workshop": {
		"label": "Мастерская", "icon": "🏗️", "art": "06_Blacksmith_Workshop",
		"cost": [460, 510, 600, 320], "time": 1200.0, "pop": 3, "cp": 3, "max": 20,
		"needs": {"academy": 10, "main": 10}, "trains": "workshop",
		"desc": "Тараны и катапульты.",
	},
	"academy": {
		"label": "Академия", "icon": "📜", "art": "17_Smithy_Armoury",
		"cost": [220, 160, 90, 40], "time": 400.0, "pop": 4, "cp": 4, "max": 20,
		"needs": {"main": 3, "barracks": 3}, "desc": "Открывает доступ к продвинутым войскам.",
	},
	"smithy": {
		"label": "Кузница", "icon": "🔨", "art": "17_Smithy_Armoury",
		"cost": [170, 200, 380, 130], "time": 500.0, "pop": 4, "cp": 2, "max": 20,
		"needs": {"academy": 1, "main": 3}, "desc": "+1.5% атаки всем твоим войскам за уровень.",
	},
	"armoury": {
		"label": "Фабрика доспехов", "icon": "🦺", "art": "18_Armoury_Blacksmith",
		"cost": [130, 210, 410, 130], "time": 500.0, "pop": 4, "cp": 2, "max": 20,
		"needs": {"academy": 1, "main": 3}, "desc": "+1.5% защиты всем твоим войскам за уровень.",
	},
	"hero_mansion": {
		"label": "Двор героя", "icon": "🦸", "art": "20_Hero_Mansion",
		"cost": [700, 670, 700, 240], "time": 900.0, "pop": 2, "cp": 1, "max": 20,
		"needs": {"main": 3, "rally_point": 1}, "desc": "Лечит героя быстрее и даёт +10% опыта.",
	},
	"watchtower": {
		"label": "Дозорная башня", "icon": "🗼", "art": "21_Watchtower",
		"cost": [180, 130, 220, 40], "time": 400.0, "pop": 1, "cp": 1, "max": 20,
		"needs": {"rally_point": 1}, "desc": "Заранее предупреждает о входящих атаках.",
	},
	"trapper": {
		"label": "Ловушки", "icon": "🪤", "art": "22_Cranny_Trapper",
		"cost": [100, 100, 100, 50], "time": 300.0, "pop": 1, "cp": 1, "max": 20,
		"needs": {"rally_point": 1}, "tribe": "gauls",
		"desc": "Ловит вражеские войска: 10 ловушек за уровень.",
	},
	# --- walls (one per tribe, fixed slot) ---
	"wall": {
		"label": "Городская стена", "icon": "🧱", "art": "10_City_Wall",
		"cost": [70, 90, 170, 70], "time": 200.0, "pop": 0, "cp": 1, "max": 20,
		"needs": {}, "tribe": "romans", "is_wall": true, "desc": "+3% защиты деревни за уровень.",
	},
	"palisade_gaul": {
		"label": "Земляной вал", "icon": "🌿", "art": "10_City_Wall",
		"cost": [110, 160, 90, 70], "time": 190.0, "pop": 0, "cp": 1, "max": 20,
		"needs": {}, "tribe": "gauls", "is_wall": true, "desc": "+2.5% защиты за уровень, удвоенный эффект.",
	},
	"palisade": {
		"label": "Частокол", "icon": "🪵", "art": "10_City_Wall",
		"cost": [50, 80, 40, 30], "time": 150.0, "pop": 0, "cp": 1, "max": 20,
		"needs": {}, "tribe": "germans", "is_wall": true, "desc": "+2% защиты за уровень. Дешёвый.",
	},
}

## Slot 0 is always the main building, slot 1 the rally point, slot 21 the wall.
const SLOT_MAIN := 0
const SLOT_RALLY := 1
const SLOT_WALL := 21
const SLOT_COUNT := 22

## Polar placement of the 22 centre slots (angle degrees, radius fraction).
const SLOT_LAYOUT := [
	{"ang": 270.0, "r": 0.00},                                  # 0  main (centre)
	{"ang": 0.0, "r": 0.34}, {"ang": 90.0, "r": 0.34},          # 1 rally, 2
	{"ang": 180.0, "r": 0.34}, {"ang": 270.0, "r": 0.34},       # 3, 4
	{"ang": 250.0, "r": 0.68}, {"ang": 272.0, "r": 0.74},
	{"ang": 294.0, "r": 0.68}, {"ang": 316.0, "r": 0.74},
	{"ang": 338.0, "r": 0.68}, {"ang": 0.0, "r": 0.74},
	{"ang": 22.0, "r": 0.68}, {"ang": 44.0, "r": 0.74},
	{"ang": 66.0, "r": 0.68}, {"ang": 90.0, "r": 0.74},
	{"ang": 112.0, "r": 0.68}, {"ang": 134.0, "r": 0.74},
	{"ang": 158.0, "r": 0.68}, {"ang": 180.0, "r": 0.74},
	{"ang": 202.0, "r": 0.68}, {"ang": 226.0, "r": 0.74},
	{"ang": 270.0, "r": 0.99},                                  # 21 wall (ring)
]

# ---------------------------------------------------------------------------
# Units
# ---------------------------------------------------------------------------
#
# atk/di/dc : attack, defence vs infantry, defence vs cavalry
# spd        : map fields per hour
# carry      : loot capacity
# eat        : crop per hour
# cost/time  : training cost and base seconds per unit
# kind       : inf | cav | siege | admin | settler | scout
# from       : which building trains it
# needs      : prerequisites {building: level}

const UNITS := {
	# ---- Romans ----
	"legionnaire": {"tribe": "romans", "label": "Легионер", "art": "roman_01_Legionnaire",
		"atk": 40, "di": 35, "dc": 50, "spd": 6, "carry": 50, "eat": 1, "kind": "inf",
		"cost": [120, 100, 150, 30], "time": 120.0, "from": "barracks", "needs": {}},
	"praetorian": {"tribe": "romans", "label": "Преторианец", "art": "roman_02_Praetorian",
		"atk": 30, "di": 65, "dc": 35, "spd": 5, "carry": 20, "eat": 1, "kind": "inf",
		"cost": [100, 130, 160, 70], "time": 150.0, "from": "barracks", "needs": {"academy": 1}},
	"imperian": {"tribe": "romans", "label": "Имперец", "art": "roman_03_Imperian",
		"atk": 70, "di": 40, "dc": 25, "spd": 7, "carry": 50, "eat": 1, "kind": "inf",
		"cost": [150, 160, 210, 80], "time": 180.0, "from": "barracks", "needs": {"academy": 5, "smithy": 1}},
	"eq_legati": {"tribe": "romans", "label": "Конный разведчик", "art": "roman_04_Equites_Legati_Scout",
		"atk": 0, "di": 20, "dc": 10, "spd": 16, "carry": 0, "eat": 2, "kind": "scout",
		"cost": [140, 160, 20, 40], "time": 160.0, "from": "stable", "needs": {}},
	"eq_imperatoris": {"tribe": "romans", "label": "Императорская конница", "art": "roman_05_Equites_Imperatoris",
		"atk": 120, "di": 65, "dc": 50, "spd": 14, "carry": 100, "eat": 3, "kind": "cav",
		"cost": [550, 440, 550, 100], "time": 400.0, "from": "stable", "needs": {"academy": 5}},
	"eq_caesaris": {"tribe": "romans", "label": "Конница Цезаря", "art": "roman_06_Equites_Caesaris",
		"atk": 180, "di": 80, "dc": 105, "spd": 10, "carry": 70, "eat": 4, "kind": "cav",
		"cost": [550, 640, 800, 180], "time": 600.0, "from": "stable", "needs": {"academy": 15}},
	"ram_rome": {"tribe": "romans", "label": "Таран", "art": "roman_07_Battering_Ram",
		"atk": 60, "di": 30, "dc": 75, "spd": 4, "carry": 0, "eat": 3, "kind": "siege",
		"cost": [900, 360, 500, 70], "time": 900.0, "from": "workshop", "needs": {}, "ram": true},
	"fire_catapult": {"tribe": "romans", "label": "Огненная катапульта", "art": "roman_08_Fire_Catapult",
		"atk": 75, "di": 60, "dc": 10, "spd": 3, "carry": 0, "eat": 6, "kind": "siege",
		"cost": [950, 1350, 600, 90], "time": 1400.0, "from": "workshop", "needs": {"academy": 15}, "cata": true},
	"senator": {"tribe": "romans", "label": "Сенатор", "art": "roman_09_Senator",
		"atk": 50, "di": 40, "dc": 30, "spd": 4, "carry": 0, "eat": 5, "kind": "admin",
		"cost": [5000, 4000, 2800, 120], "time": 2400.0, "from": "residence", "needs": {"residence": 10}, "loyalty": 25},
	"settler_rome": {"tribe": "romans", "label": "Поселенец", "art": "roman_10_Settler",
		"atk": 0, "di": 10, "dc": 5, "spd": 5, "carry": 3000, "eat": 1, "kind": "settler",
		"cost": [5800, 4400, 4600, 5200], "time": 3000.0, "from": "residence", "needs": {"residence": 10}},

	# ---- Gauls ----
	"phalanx": {"tribe": "gauls", "label": "Фаланга", "art": "gaul_01_Phalanx",
		"atk": 40, "di": 50, "dc": 55, "spd": 7, "carry": 35, "eat": 1, "kind": "inf",
		"cost": [100, 130, 55, 30], "time": 110.0, "from": "barracks", "needs": {}},
	"swordsman": {"tribe": "gauls", "label": "Мечник", "art": "gaul_02_Swordsman",
		"atk": 65, "di": 35, "dc": 20, "spd": 6, "carry": 45, "eat": 1, "kind": "inf",
		"cost": [140, 150, 185, 60], "time": 150.0, "from": "barracks", "needs": {"academy": 1}},
	"pathfinder": {"tribe": "gauls", "label": "Следопыт", "art": "gaul_03_Pathfinder",
		"atk": 10, "di": 20, "dc": 10, "spd": 17, "carry": 0, "eat": 2, "kind": "scout",
		"cost": [170, 150, 20, 40], "time": 160.0, "from": "stable", "needs": {}},
	"theutates": {"tribe": "gauls", "label": "Тевтатский гром", "art": "gaul_04_Theutates_Thunder",
		"atk": 90, "di": 25, "dc": 40, "spd": 19, "carry": 75, "eat": 2, "kind": "cav",
		"cost": [350, 450, 230, 60], "time": 300.0, "from": "stable", "needs": {"academy": 5}},
	"druidrider": {"tribe": "gauls", "label": "Друид", "art": "gaul_05_Druidrider",
		"atk": 45, "di": 115, "dc": 55, "spd": 16, "carry": 35, "eat": 2, "kind": "cav",
		"cost": [360, 330, 280, 120], "time": 360.0, "from": "stable", "needs": {"academy": 5}},
	"haeduan": {"tribe": "gauls", "label": "Эдуй", "art": "gaul_06_Haeduan",
		"atk": 140, "di": 50, "dc": 165, "spd": 13, "carry": 65, "eat": 3, "kind": "cav",
		"cost": [500, 620, 675, 170], "time": 600.0, "from": "stable", "needs": {"academy": 15}},
	"ram_gaul": {"tribe": "gauls", "label": "Таран", "art": "gaul_07_Ram",
		"atk": 50, "di": 30, "dc": 105, "spd": 4, "carry": 0, "eat": 3, "kind": "siege",
		"cost": [700, 500, 400, 80], "time": 900.0, "from": "workshop", "needs": {}, "ram": true},
	"trebuchet": {"tribe": "gauls", "label": "Требюше", "art": "gaul_08_Trebuchet",
		"atk": 70, "di": 45, "dc": 10, "spd": 3, "carry": 0, "eat": 6, "kind": "siege",
		"cost": [900, 1200, 600, 90], "time": 1400.0, "from": "workshop", "needs": {"academy": 15}, "cata": true},
	"chieftain": {"tribe": "gauls", "label": "Вождь", "art": "gaul_09_Chieftain",
		"atk": 40, "di": 50, "dc": 50, "spd": 5, "carry": 0, "eat": 4, "kind": "admin",
		"cost": [5000, 4000, 2800, 120], "time": 2400.0, "from": "residence", "needs": {"residence": 10}, "loyalty": 20},
	"settler_gaul": {"tribe": "gauls", "label": "Поселенец", "art": "gaul_10_Settler",
		"atk": 0, "di": 10, "dc": 5, "spd": 5, "carry": 3000, "eat": 1, "kind": "settler",
		"cost": [5800, 4400, 4600, 5200], "time": 3000.0, "from": "residence", "needs": {"residence": 10}},

	# ---- Germans ----
	"clubswinger": {"tribe": "germans", "label": "Дубинщик", "art": "german_01_Clubswinger",
		"atk": 40, "di": 20, "dc": 5, "spd": 7, "carry": 60, "eat": 1, "kind": "inf",
		"cost": [95, 75, 40, 40], "time": 90.0, "from": "barracks", "needs": {}},
	"spearman": {"tribe": "germans", "label": "Копьеносец", "art": "german_02_Spearman",
		"atk": 10, "di": 35, "dc": 60, "spd": 7, "carry": 40, "eat": 1, "kind": "inf",
		"cost": [145, 70, 85, 40], "time": 130.0, "from": "barracks", "needs": {"academy": 1}},
	"axeman": {"tribe": "germans", "label": "Топорщик", "art": "german_03_Axeman",
		"atk": 60, "di": 30, "dc": 30, "spd": 6, "carry": 50, "eat": 1, "kind": "inf",
		"cost": [130, 120, 170, 70], "time": 150.0, "from": "barracks", "needs": {"academy": 3}},
	"scout_germ": {"tribe": "germans", "label": "Скаут", "art": "german_04_Scout",
		"atk": 0, "di": 10, "dc": 5, "spd": 9, "carry": 0, "eat": 1, "kind": "scout",
		"cost": [160, 100, 50, 20], "time": 140.0, "from": "barracks", "needs": {}},
	"paladin": {"tribe": "germans", "label": "Паладин", "art": "german_05_Paladin",
		"atk": 55, "di": 100, "dc": 40, "spd": 10, "carry": 110, "eat": 2, "kind": "cav",
		"cost": [370, 270, 290, 75], "time": 400.0, "from": "stable", "needs": {"academy": 5}},
	"teutonic_knight": {"tribe": "germans", "label": "Тевтонская конница", "art": "german_06_Teutonic_Knight",
		"atk": 150, "di": 50, "dc": 75, "spd": 9, "carry": 80, "eat": 3, "kind": "cav",
		"cost": [450, 515, 480, 80], "time": 500.0, "from": "stable", "needs": {"academy": 15}},
	"ram_germ": {"tribe": "germans", "label": "Таран", "art": "german_07_Ram",
		"atk": 65, "di": 30, "dc": 80, "spd": 4, "carry": 0, "eat": 3, "kind": "siege",
		"cost": [1000, 300, 350, 70], "time": 900.0, "from": "workshop", "needs": {}, "ram": true},
	"catapult_germ": {"tribe": "germans", "label": "Катапульта", "art": "german_08_Catapult",
		"atk": 75, "di": 50, "dc": 10, "spd": 3, "carry": 0, "eat": 6, "kind": "siege",
		"cost": [900, 1200, 600, 60], "time": 1400.0, "from": "workshop", "needs": {"academy": 15}, "cata": true},
	"chief": {"tribe": "germans", "label": "Старейшина", "art": "german_09_Chief",
		"atk": 40, "di": 60, "dc": 40, "spd": 4, "carry": 0, "eat": 4, "kind": "admin",
		"cost": [5000, 4000, 2800, 120], "time": 2400.0, "from": "residence", "needs": {"residence": 10}, "loyalty": 20},
	"settler_germ": {"tribe": "germans", "label": "Поселенец", "art": "german_10_Settler",
		"atk": 0, "di": 10, "dc": 5, "spd": 5, "carry": 3000, "eat": 1, "kind": "settler",
		"cost": [5800, 4400, 4600, 5200], "time": 3000.0, "from": "residence", "needs": {"residence": 10}},

	# ---- Nature (robber camps and oases; never trainable) ----
	"rat": {"tribe": "nature", "label": "Крыса", "art": "",
		"atk": 10, "di": 25, "dc": 20, "spd": 20, "carry": 0, "eat": 1, "kind": "inf", "cost": [0, 0, 0, 0], "time": 0.0, "from": "", "needs": {}},
	"spider": {"tribe": "nature", "label": "Паук", "art": "",
		"atk": 20, "di": 35, "dc": 40, "spd": 20, "carry": 0, "eat": 1, "kind": "inf", "cost": [0, 0, 0, 0], "time": 0.0, "from": "", "needs": {}},
	"snake": {"tribe": "nature", "label": "Змея", "art": "",
		"atk": 60, "di": 40, "dc": 60, "spd": 20, "carry": 0, "eat": 1, "kind": "inf", "cost": [0, 0, 0, 0], "time": 0.0, "from": "", "needs": {}},
	"bat": {"tribe": "nature", "label": "Летучая мышь", "art": "",
		"atk": 80, "di": 66, "dc": 50, "spd": 20, "carry": 0, "eat": 1, "kind": "inf", "cost": [0, 0, 0, 0], "time": 0.0, "from": "", "needs": {}},
	"boar": {"tribe": "nature", "label": "Кабан", "art": "",
		"atk": 50, "di": 70, "dc": 33, "spd": 20, "carry": 0, "eat": 1, "kind": "inf", "cost": [0, 0, 0, 0], "time": 0.0, "from": "", "needs": {}},
	"wolf": {"tribe": "nature", "label": "Волк", "art": "",
		"atk": 100, "di": 80, "dc": 70, "spd": 20, "carry": 0, "eat": 1, "kind": "inf", "cost": [0, 0, 0, 0], "time": 0.0, "from": "", "needs": {}},
	"bear": {"tribe": "nature", "label": "Медведь", "art": "",
		"atk": 250, "di": 140, "dc": 200, "spd": 20, "carry": 0, "eat": 1, "kind": "inf", "cost": [0, 0, 0, 0], "time": 0.0, "from": "", "needs": {}},
	"crocodile": {"tribe": "nature", "label": "Крокодил", "art": "",
		"atk": 450, "di": 380, "dc": 240, "spd": 20, "carry": 0, "eat": 1, "kind": "inf", "cost": [0, 0, 0, 0], "time": 0.0, "from": "", "needs": {}},
	"tiger": {"tribe": "nature", "label": "Тигр", "art": "",
		"atk": 200, "di": 170, "dc": 250, "spd": 20, "carry": 0, "eat": 1, "kind": "inf", "cost": [0, 0, 0, 0], "time": 0.0, "from": "", "needs": {}},
	"elephant": {"tribe": "nature", "label": "Слон", "art": "",
		"atk": 600, "di": 440, "dc": 520, "spd": 20, "carry": 0, "eat": 1, "kind": "inf", "cost": [0, 0, 0, 0], "time": 0.0, "from": "", "needs": {}},
	"robber": {"tribe": "nature", "label": "Разбойник", "art": "",
		"atk": 70, "di": 40, "dc": 35, "spd": 8, "carry": 40, "eat": 1, "kind": "inf", "cost": [0, 0, 0, 0], "time": 0.0, "from": "", "needs": {}},
	"robber_chief": {"tribe": "nature", "label": "Атаман", "art": "",
		"atk": 120, "di": 80, "dc": 70, "spd": 8, "carry": 60, "eat": 1, "kind": "inf", "cost": [0, 0, 0, 0], "time": 0.0, "from": "", "needs": {}},
}

# ---------------------------------------------------------------------------
# Culture points required for the Nth village
# ---------------------------------------------------------------------------

const CP_FOR_VILLAGE := [0, 0, 500, 2000, 7000, 18000, 40000, 85000]

const MERCHANTS_BY_LEVEL := [0, 1, 2, 2, 3, 4, 4, 5, 6, 6, 7, 8, 9, 10, 11, 12, 13, 15, 17, 18, 20]

# ---------------------------------------------------------------------------
# Hero
# ---------------------------------------------------------------------------

const HERO_EQUIP_SLOTS := ["helmet", "armor", "weapon", "shield", "boots", "horse"]

const HERO_ITEMS := {
	"helmet_bronze": {"slot": "helmet", "label": "Бронзовый шлем", "icon": "🪖", "xp": 0.15, "tier": 1},
	"helmet_legion": {"slot": "helmet", "label": "Шлем легата", "icon": "🪖", "atk": 0.10, "tier": 2},
	"armor_leather": {"slot": "armor", "label": "Кожаный доспех", "icon": "🦺", "def": 0.10, "tier": 1},
	"armor_lorica": {"slot": "armor", "label": "Лорика сегментата", "icon": "🦺", "def": 0.20, "tier": 2},
	"sword_gladius": {"slot": "weapon", "label": "Гладиус", "icon": "🗡️", "atk": 0.15, "tier": 1},
	"sword_spatha": {"slot": "weapon", "label": "Спата", "icon": "⚔️", "atk": 0.25, "tier": 2},
	"shield_scutum": {"slot": "shield", "label": "Скутум", "icon": "🛡️", "def": 0.15, "tier": 1},
	"boots_caligae": {"slot": "boots", "label": "Калиги", "icon": "👢", "speed": 0.20, "tier": 1},
	"horse_steppe": {"slot": "horse", "label": "Степной конь", "icon": "🐴", "speed": 0.35, "tier": 2},
	"bag_loot": {"slot": "helmet", "label": "Мешок добытчика", "icon": "🎒", "loot": 0.25, "tier": 1},
}

const HERO_XP_PER_LEVEL := 100      # xp needed = level * this
const HERO_POINTS_PER_LEVEL := 4

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func res_zero() -> Array:
	return [0.0, 0.0, 0.0, 0.0]


static func res_add(a: Array, b: Array) -> Array:
	return [a[0] + b[0], a[1] + b[1], a[2] + b[2], a[3] + b[3]]


static func res_sub(a: Array, b: Array) -> Array:
	return [a[0] - b[0], a[1] - b[1], a[2] - b[2], a[3] - b[3]]


static func res_scale(a: Array, k: float) -> Array:
	return [a[0] * k, a[1] * k, a[2] * k, a[3] * k]


static func res_sum(a: Array) -> float:
	return a[0] + a[1] + a[2] + a[3]


static func res_covers(have: Array, cost: Array) -> bool:
	for r in range(4):
		if have[r] < cost[r] - 0.001:
			return false
	return true


static func building(id: String) -> Dictionary:
	return BUILDINGS.get(id, {})


static func unit(id: String) -> Dictionary:
	return UNITS.get(id, {})


## Cost of raising `id` from its current level to level `level`.
static func building_cost(id: String, level: int) -> Array:
	var b: Dictionary = BUILDINGS.get(id, {})
	if b.is_empty():
		return res_zero()
	var mult := pow(COST_GROWTH, level - 1)
	var base: Array = b["cost"]
	var out := res_zero()
	for r in range(4):
		out[r] = round(base[r] * mult)
	return out


static func building_time(id: String, level: int, main_level: int, speed: float) -> float:
	var b: Dictionary = BUILDINGS.get(id, {})
	if b.is_empty():
		return MIN_BUILD_TIME
	var t: float = b["time"] * pow(TIME_GROWTH, level - 1)
	t /= (1.0 + main_level * 0.03)
	t /= max(speed, 0.001)
	return max(MIN_BUILD_TIME, t)


static func building_pop(id: String, level: int) -> int:
	var b: Dictionary = BUILDINGS.get(id, {})
	if b.is_empty():
		return 0
	return int(b["pop"]) * level


static func building_cp(id: String, level: int) -> float:
	var b: Dictionary = BUILDINGS.get(id, {})
	if b.is_empty():
		return 0.0
	return float(b["cp"]) * level


static func field_cost(res: int, level: int) -> Array:
	var base: Array = FIELD_BASE_COST[res]
	var mult := pow(FIELD_COST_GROWTH, level - 1)
	var out := res_zero()
	for r in range(4):
		out[r] = round(base[r] * mult)
	return out


static func field_time(level: int, main_level: int, speed: float) -> float:
	var t := FIELD_BASE_TIME * pow(FIELD_TIME_GROWTH, level - 1)
	t /= (1.0 + main_level * 0.03)
	t /= max(speed, 0.001)
	return max(MIN_BUILD_TIME, t)


static func field_production(res: int, level: int) -> float:
	var l := clampi(level, 0, 20)
	if res == CR:
		return float(PROD_CROP[l])
	return float(PROD_WCI[l])


static func field_pop_total(level: int) -> int:
	var total := 0
	for l in range(1, clampi(level, 0, 20) + 1):
		total += FIELD_POP[l]
	return total


static func storage_capacity(level: int) -> float:
	if level <= 0:
		return 800.0
	return round(1000.0 * pow(1.26, level - 1))


static func cranny_capacity(level: int, tribe_factor: float) -> float:
	if level <= 0:
		return 0.0
	return round(100.0 * pow(1.31, level - 1) * tribe_factor)


static func merchants_for_level(level: int) -> int:
	return MERCHANTS_BY_LEVEL[clampi(level, 0, 20)]


static func cp_needed(village_count: int) -> int:
	var idx := clampi(village_count + 1, 0, CP_FOR_VILLAGE.size() - 1)
	return CP_FOR_VILLAGE[idx]


## Every unit this tribe can train, in display order.
static func units_of_tribe(tribe: String) -> Array:
	var out: Array = []
	for id in UNITS:
		if UNITS[id]["tribe"] == tribe:
			out.append(id)
	return out


static func units_from_building(tribe: String, building_id: String) -> Array:
	var out: Array = []
	for id in UNITS:
		var u: Dictionary = UNITS[id]
		if u["tribe"] == tribe and u["from"] == building_id:
			out.append(id)
	return out


## Buildings this tribe may place in a free slot.
static func buildable_ids(tribe: String) -> Array:
	var out: Array = []
	for id in BUILDINGS:
		var b: Dictionary = BUILDINGS[id]
		if b.get("is_wall", false):
			continue
		var only: String = b.get("tribe", "")
		if only != "" and only != tribe:
			continue
		out.append(id)
	return out


static func wall_id_for(tribe: String) -> String:
	return TRIBES[tribe]["wall_id"]
