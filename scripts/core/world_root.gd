class_name WorldRoot
extends Node3D

## Owns the projection anchor and the render origin. Children are shifted on
## rebase so that local coordinates stay small (ticket 04).

const REBASE_RADIUS_M := 2048.0
const ZONE_RADIUS_M := 4096.0

var frame: GeoFrame = null
var origin_e := 0.0
var origin_n := 0.0


func set_anchor(lat: float, lon: float) -> void:
	frame = GeoFrame.new(lat, lon)
	origin_e = 0.0
	origin_n = 0.0


func has_anchor() -> bool:
	return frame != null


func to_world(lat: float, lon: float, alt: float = 0.0) -> Vector3:
	if frame == null:
		return Vector3.ZERO
	return frame.to_world(lat, lon, alt, origin_e, origin_n)


func to_latlon(world_position: Vector3) -> PackedFloat64Array:
	if frame == null:
		return PackedFloat64Array([0.0, 0.0])
	return frame.from_world(world_position, origin_e, origin_n)


## Returns the world-space shift applied to children, or Vector3.ZERO.
func rebase_if_needed(lat: float, lon: float) -> Vector3:
	if frame == null:
		return Vector3.ZERO
	var e := frame.frame_e(lat, lon)
	var n := frame.frame_n(lat, lon)
	var de := e - origin_e
	var dn := n - origin_n
	if absf(de) < REBASE_RADIUS_M and absf(dn) < REBASE_RADIUS_M:
		return Vector3.ZERO

	var shift := Vector3(de, 0.0, -dn)
	for child in get_children():
		if child is Node3D:
			child.position -= shift
	origin_e += de
	origin_n += dn
	reset_physics_interpolation()
	return shift


func distance_from_anchor(lat: float, lon: float) -> float:
	if frame == null:
		return 0.0
	var e := frame.frame_e(lat, lon)
	var n := frame.frame_n(lat, lon)
	return sqrt(e * e + n * n)
