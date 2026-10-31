class_name GpsFix
extends RefCounted

## One location sample. Lat/lon stay 64-bit; world is the projected position in
## the current render frame and is filled in by the main scene.

var latitude: float
var longitude: float
var accuracy: float
var altitude: float
var speed: float = -1.0
var bearing: float = -1.0
var time_ms: int
var elapsed_ns: int
var received_ns: int
var age_ms: float
var is_mock: bool
var world := Vector3.ZERO


static func from_dictionary(data: Dictionary, now_ns: int) -> GpsFix:
	var fix := GpsFix.new()
	fix.latitude = float(data.get("latitude", 0.0))
	fix.longitude = float(data.get("longitude", 0.0))
	fix.accuracy = float(data.get("accuracy", 999.0))
	fix.altitude = float(data.get("altitude", 0.0))
	fix.speed = float(data.get("speed", -1.0))
	fix.bearing = float(data.get("bearing", -1.0))
	fix.time_ms = int(data.get("time_ms", 0))
	fix.elapsed_ns = int(data.get("elapsed_ns", 0))
	fix.received_ns = now_ns
	fix.age_ms = float(data.get("age_ms", 0.0))
	fix.is_mock = bool(data.get("is_mock", false))
	return fix


func has_speed() -> bool:
	return speed >= 0.0


func age_ns(now_ns: int) -> int:
	return maxi(0, now_ns - received_ns) + int(age_ms * 1_000_000.0)
