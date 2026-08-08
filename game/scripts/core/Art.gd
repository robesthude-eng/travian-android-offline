extends RefCounted

## Maps game ids to the PNGs that already live in Assets/Art, including the
## three visual tiers (thatch / wood / stone) the artwork was cut for.

const T := preload("res://game/scripts/core/Tables.gd")

const BUILDINGS_DIR := "res://Assets/Art/Buildings/"
const UNITS_DIR := "res://Assets/Art/Units/"
const UI_DIR := "res://Assets/Art/UI/"
const MAP_DIR := "res://Assets/Art/Map/"
const HERO_DIR := "res://Assets/Art/Hero/"

const LOD_SUFFIX := ["_LOD1_1-5_Thatch", "_LOD2_6-15_Wood", "_LOD3_16-20_Stone"]

static var _cache := {}

static func _try_load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var r := ResourceLoader.load(path)
		if r is Texture2D:
			tex = r
	_cache[path] = tex
	return tex

static func lod_index(level: int) -> int:
	if level <= 5:
		return 0
	if level <= 15:
		return 1
	return 2

## Building sprite for a level, falling back through LOD -> base -> null.
static func building(building_id: String, level: int) -> Texture2D:
	var b: Dictionary = T.building(building_id)
	var base: String = b.get("art", "")
	if base == "":
		return null
	var lod: String = LOD_SUFFIX[lod_index(maxi(1, level))]
	var tex := _try_load(BUILDINGS_DIR + base + lod + ".png")
	if tex != null:
		return tex
	return _try_load(BUILDINGS_DIR + base + ".png")

static func unit(unit_id: String) -> Texture2D:
	var u: Dictionary = T.unit(unit_id)
	var base: String = u.get("art", "")
	if base == "":
		return null
	return _try_load(UNITS_DIR + base + ".png")

static func construction_site() -> Texture2D:
	return _try_load(BUILDINGS_DIR + "25_Construction_Site.png")

static func robber_camp() -> Texture2D:
	return _try_load(MAP_DIR + "robber_camp_tents.png")

static func oasis() -> Texture2D:
	return _try_load(MAP_DIR + "oasis_bonus.png")

static func hero_portrait() -> Texture2D:
	return _try_load(HERO_DIR + "hero_roman_with_gear.png")

static func app_icon() -> Texture2D:
	return _try_load(UI_DIR + "app_icon_512.png")

static func loading_cover() -> Texture2D:
	return _try_load(UI_DIR + "loading_screen_cover_1080x1920.png")

# --- New helpers for beautiful UI — all from sliced assets ---

const ICONS_DIR := "res://game/assets/icons/"
const HERO_ASSETS_DIR := "res://game/assets/hero/"

static func village_center_bg() -> Texture2D:
	var tex := _try_load(BUILDINGS_DIR + "village_center_authentic_travian.png")
	if tex: return tex
	return _try_load(BUILDINGS_DIR + "village_center_filled_buildings.png")

static func resource_fields_bg() -> Texture2D:
	return _try_load(BUILDINGS_DIR + "resource_fields_authentic_travian.png")

static func field_icon(res: int) -> Texture2D:
	match res:
		0: return _try_load(BUILDINGS_DIR + "11_Sawmill.png")
		1: return _try_load(BUILDINGS_DIR + "12_Brickyard.png")
		2: return _try_load(BUILDINGS_DIR + "13_Iron_Foundry.png")
		3: return _try_load(BUILDINGS_DIR + "14_Grain_Mill.png")
		_: return null

# Sliced circular icons from promo_icon_set_resources.png (128x128)
static func resource_icon(res: int) -> Texture2D:
	var path := ICONS_DIR + "res_%d.png" % res
	var tex := _try_load(path)
	if tex: return tex
	# fallback to old field icon if sliced not yet generated
	return field_icon(res)

static func resource_big_icon(res: int) -> Texture2D:
	return resource_icon(res)

static func merchant_cart_icon() -> Texture2D:
	return _try_load(ICONS_DIR + "merchant_cart.png")

static func battle_report_icon() -> Texture2D:
	return _try_load(ICONS_DIR + "battle_report_win_lose.png")

static func nature_troops_icon() -> Texture2D:
	return _try_load(ICONS_DIR + "nature_troops_rats_spiders.png")

static func oasis_icon_small() -> Texture2D:
	return _try_load(ICONS_DIR + "oasis_bonus.png")

static func hero_equip_icon(slot: String) -> Texture2D:
	var map := {"helmet":0, "armor":1, "weapon":2, "shield":3, "boots":4, "horse":5}
	var idx: int = map.get(slot, -1)
	if idx < 0: return null
	return _try_load(HERO_ASSETS_DIR + "equip_%d.png" % idx)

static func hero_equip_icon_by_id(item_id: String) -> Texture2D:
	# Map item_id to slot-equivalent icon via T.HERO_ITEMS
	var it: Dictionary = T.HERO_ITEMS.get(item_id, {})
	var slot: String = String(it.get("slot", ""))
	if slot != "":
		return hero_equip_icon(slot)
	return null

static func map_tile_for(kind: String) -> Texture2D:
	match kind:
		"camp": return robber_camp()
		"oasis": return oasis()
		"player_village": return _try_load(BUILDINGS_DIR + "01_Main_Building.png")
		"bot": return _try_load(BUILDINGS_DIR + "10_City_Wall.png")
		_: return null

static func ui_background() -> Texture2D:
	return loading_cover()
