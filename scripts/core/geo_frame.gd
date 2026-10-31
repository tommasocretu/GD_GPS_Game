class_name GeoFrame
extends RefCounted

## Local ellipsoidal tangent plane anchored at (lat0, lon0).
## 1 unit = 1 metre. Lat/lon are always 64-bit floats; never store them in Vector2.

const A := 6378137.0
const F := 1.0 / 298.257223563
const E2 := 2.0 * F - F * F
const MAX_MERCATOR_LAT := 85.05112878

var lat0: float
var lon0: float
var m0: float
var n0: float
var east_scale: float
var north_scale: float


func _init(lat: float = 0.0, lon: float = 0.0) -> void:
	set_anchor(lat, lon)


func set_anchor(lat: float, lon: float) -> void:
	lat0 = lat
	lon0 = lon
	var phi := deg_to_rad(lat)
	var s := sin(phi)
	var w := sqrt(1.0 - E2 * s * s)
	m0 = A * (1.0 - E2) / (w * w * w)
	n0 = A / w
	east_scale = n0 * cos(phi)
	north_scale = m0


func frame_e(lat: float, lon: float) -> float:
	var dlon := deg_to_rad(wrapf(lon - lon0, -180.0, 180.0))
	return east_scale * dlon


func frame_n(lat: float, _lon: float = 0.0) -> float:
	var dlat := deg_to_rad(lat - lat0)
	return north_scale * dlat


## Converts a geodetic point to the local world frame, already relative to the
## render origin. Godot axes: +X east, +Y up, -Z north.
func to_world(lat: float, lon: float, alt: float, origin_e: float, origin_n: float) -> Vector3:
	var e := frame_e(lat, lon) - origin_e
	var n := frame_n(lat, lon) - origin_n
	return Vector3(e, alt, -n)


## Inverse of to_world. Returns PackedFloat64Array([lat, lon]) to keep 64-bit
## precision (Vector2 is 32-bit).
func from_world(p: Vector3, origin_e: float, origin_n: float) -> PackedFloat64Array:
	var e := p.x + origin_e
	var n := -p.z + origin_n
	var lat := lat0 + rad_to_deg(n / m0)
	var lon := lon0 + rad_to_deg(e / east_scale)
	return PackedFloat64Array([lat, lon])


static func lonlat_to_tile(lat: float, lon: float, z: int) -> Vector2i:
	var clamped_lat := clampf(lat, -MAX_MERCATOR_LAT, MAX_MERCATOR_LAT)
	var n := 1 << z
	var x := int(floor((lon + 180.0) / 360.0 * n))
	var lat_rad := deg_to_rad(clamped_lat)
	var y := int(floor((1.0 - asinh(tan(lat_rad)) / PI) / 2.0 * n))
	return Vector2i(clampi(x, 0, n - 1), clampi(y, 0, n - 1))


static func tile_lon_w(x: int, z: int) -> float:
	var n := float(1 << z)
	return x / n * 360.0 - 180.0


static func tile_lat_n(y: int, z: int) -> float:
	var n := float(1 << z)
	return rad_to_deg(atan(sinh(PI * (1.0 - 2.0 * y / n))))


## World-space rectangle of an XYZ tile, relative to the render origin.
## Returns Rect2(x, z, width, height) with south = +Z.
func tile_world_rect(z: int, x: int, y: int, origin_e: float, origin_n: float) -> Rect2:
	var lon_w := tile_lon_w(x, z)
	var lon_e := tile_lon_w(x + 1, z)
	var lat_n := tile_lat_n(y, z)
	var lat_s := tile_lat_n(y + 1, z)

	var e0 := frame_e(lat_n, lon_w)
	var n0 := frame_n(lat_n, lon_w)
	var e1 := frame_e(lat_s, lon_e)
	var n1 := frame_n(lat_s, lon_e)

	var p0 := Vector2(e0 - origin_e, -(n0 - origin_n))
	var p1 := Vector2(e1 - origin_e, -(n1 - origin_n))
	return Rect2(p0, p1 - p0)
