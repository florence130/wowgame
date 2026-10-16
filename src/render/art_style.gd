class_name ArtStyle
extends RefCounted
## 全局美术色板：场景、天空、地形和后续建筑共用这一组低饱和暖冷对照色。
## 保留当前项目的统一颜色范围；新增资源使用这一色板协调颜色。

const SKY_TOP := Color("3b86d1")
const SKY_HORIZON := Color("d9e9ec")
const SKY_GROUND := Color("9bb6bd")
const SUN_DAY := Color("fff0d6")
const AMBIENT_DAY := Color("8fa7c4")
const FOG_DAY := Color("a9c6d0")

const TERRAIN_GRASS := Color("72a65a")
const TERRAIN_GRASS_DARK := Color("4c7c47")
const TERRAIN_DIRT := Color("b69565")
const TERRAIN_ROCK := Color("87837b")
const TERRAIN_SAND := Color("dec582")
const TERRAIN_COBBLE := Color("9a9b94")
const TERRAIN_FARM := Color("8b6742")
const TERRAIN_FLOWERS := Color("94b65c")
const TERRAIN_MOSS := Color("536b4b")

const BUILDING_PLASTER := Color("d3c6a4")
const BUILDING_TIMBER := Color("7d5538")
const BUILDING_STONE := Color("a8a28c")
const ROOF_SLATE := Color("68748a")
const ROOF_TILE := Color("b46a3e")
const ROOF_THATCH := Color("d4b66c")
const FOLIAGE := Color("5f984d")
const FOLIAGE_LIGHT := Color("82ae5a")
const WATER := Color("5f9da4")

const TERRAIN_COLORS := [
	TERRAIN_GRASS, TERRAIN_GRASS_DARK, TERRAIN_DIRT, TERRAIN_ROCK,
	TERRAIN_SAND, TERRAIN_COBBLE, TERRAIN_FARM, TERRAIN_FLOWERS, TERRAIN_MOSS,
]

static func warm_sun(dusk: float = 0.0) -> Color:
	return SUN_DAY.lerp(Color("e8a979"), clampf(dusk, 0.0, 1.0))

static func night_ambient(night: float = 1.0) -> Color:
	return AMBIENT_DAY.lerp(Color("2e4778"), clampf(night, 0.0, 1.0))

