class_name GpsSource
extends Node

## Common contract for real (Android plugin) and fake (desktop) GPS sources.

signal fix_received(fix: GpsFix)
signal error_occurred(message: String)
signal permission_result(granted: bool)


func start() -> void:
	pass


func stop() -> void:
	pass


func requires_permission() -> bool:
	return false


func is_fake() -> bool:
	return false
