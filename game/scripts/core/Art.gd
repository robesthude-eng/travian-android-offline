extends RefCounted

## Maps game ids to PNGs — now via atlases (3.6M) + fallback to files.
## Atlases: game/assets/atlas/buildings.png (10x10 256) + units.png (6x5)

const T := preload("res://game/scripts/core/Tables.gd")

const BUILDINGS_DIR := "res://Assets/Art/Buildings/"
const UNITS_DIR := "res://Assets/Art/Units/"
const UI_DIR := "res://Assets/Art/UI/"
const MAP_DIR := "res://Assets/Art/Map/"
const HERO_DIR := "res://Assets/Art/Hero/"
const ICONS_DIR := "res://game/assets/icons/"
const HERO_ASSETS_DIR := "res://game/assets/hero/"
const ATLAS_DIR := "res://game/assets/atlas/"

const LOD_SUFFIX := ["_LOD1_1-5_Thatch", "_LOD2_6-15_Wood", "_LOD3_16-20_Stone"]

static var _cache := {}
static var _build_atlas: Texture2D
static var _build_map: Dictionary = {}
static var _unit_atlas: Texture2D
static var _unit_map: Dictionary = {}
static var _atlas_loaded: bool = false

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

static func _ensure_atlas() -> void:
	if _atlas_loaded:
		return
	_atlas_loaded = true
	# Load buildings atlas
	if ResourceLoader.exists(ATLAS_DIR + "buildings.png"):
		_build_atlas = _try_load(ATLAS_DIR + "buildings.png")
		var json_path := ATLAS_DIR + "buildings.json"
		if FileAccess.file_exists(json_path):
			var txt := FileAccess.get_file_as_string(json_path)
			var parsed := JSON.parse_string(txt)
			if parsed is Dictionary:
				_build_map = parsed
	# Load units atlas
	if ResourceLoader.exists(ATLAS_DIR + "units.png"):
		_unit_atlas = _try_load(ATLAS_DIR + "units.png")
		var json_path2 := ATLAS_DIR + "units.json"
		if FileAccess.file_exists(json_path2):
			var txt2 := FileAccess.get_file_as_string(json_path2)
			var parsed2 := JSON.parse_string(txt2)
			if parsed2 is Dictionary:
				_unit_map = parsed2

static func _atlas_texture(atlas: Texture2D, entry: Dictionary) -> Texture2D:
	var at := AtlasTexture.new()
	at.atlas = atlas
	at.region = Rect2(float(entry["x"]), float(entry["y"]), float(entry["w"]), float(entry["h"]))
	at.filter_clip = true
	return at

static func lod_index(level: int) -> int:
	if level <= 5:
		return 0
	if level <= 15:
		return 1
	return 2

## Building sprite — atlas first, then file fallback
static func building(building_id: String, level: int) -> Texture2D:
	_ensure_atlas()
	var b: Dictionary = T.building(building_id)
	var base: String = b.get("art", "")
	if base == "":
		return null
	var lod: String = LOD_SUFFIX[lod_index(maxi(1, level))]
	var fname_lod := base + lod + ".png"
	var fname_base := base + ".png"
	# Try atlas with LOD
	if _build_atlas and _build_map.has(fname_lod):
		return _atlas_texture(_build_atlas, _build_map[fname_lod])
	if _build_atlas and _build_map.has(fname_base):
		return _atlas_texture(_build_atlas, _build_map[fname_base])
	# Fallback to file (for backgrounds like village_center etc. that are not in atlas)
	var tex := _try_load(BUILDINGS_DIR + fname_lod)
	if tex != null:
		return tex
	return _try_load(BUILDINGS_DIR + fname_base)

static func unit(unit_id: String) -> Texture2D:
	_ensure_atlas()
	var u: Dictionary = T.unit(unit_id)
	var base: String = u.get("art", "")
	if base == "":
		return null
	var fname := base + ".png"
	if _unit_atlas and _unit_map.has(fname):
		return _atlas_texture(_unit_atlas, _unit_map[fname])
	return _try_load(UNITS_DIR + fname)

static func construction_site() -> Texture2D:
	_ensure_atlas()
	# 25_Construction_Site is also in atlas as 25_Construction_Site.png
	if _build_atlas and _build_map.has("25_Construction_Site.png"):
		return _atlas_texture(_build_atlas, _build_map["25_Construction_Site.png"])
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

# --- Sliced assets (promo etc.) ---

static func village_center_bg() -> Texture2D:
	# Keep as file (large background) — not in atlas (atlas is 256)
	var tex := _try_load(BUILDINGS_DIR + "village_center_authentic_travian.png")
	if tex: return tex
	return _try_load(BUILDINGS_DIR + "village_center_filled_buildings.png")

static func resource_fields_bg() -> Texture2D:
	return _try_load(BUILDINGS_DIR + "resource_fields_authentic_travian.png")

static func field_icon(res: int) -> Texture2D:
	# These are also buildings (Sawmill etc.) so atlas will serve them
	match res:
		0: return building("sawmill", 1)  # 11_Sawmill
		1: return building("brickyard", 1)
		2: return building("iron_foundry", 1)
		3: return building("grain_mill", 1)
		_: return null

static func resource_icon(res: int) -> Texture2D:
	var path := ICONS_DIR + "res_%d.png" % res
	var tex := _try_load(path)
	if tex: return tex
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
	var it: Dictionary = T.HERO_ITEMS.get(item_id, {})
	var slot: String = String(it.get("slot", ""))
	if slot != "":
		return hero_equip_icon(slot)
	return null

static func map_tile_for(kind: String) -> Texture2D:
	match kind:
		"camp": return robber_camp()
		"oasis": return oasis()
		"player_village": return building("main", 5)
		"bot": return building("wall", 3)
		_: return null

static func ui_background() -> Texture2D:
	return loading_cover()
