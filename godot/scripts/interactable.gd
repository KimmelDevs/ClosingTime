## Something the player can use with [E]: notes, fuses, batteries, the breaker, the gate,
## payphones, hiding spots and the pedestal. Move it anywhere in the mall scene.
extends Node3D
class_name Interactable

@export_enum("note", "fuse", "battery", "breaker", "gate", "phone", "hide", "pedestal") var kind := "note"
## Which note to open (dale1, lumen, poster, janitor, father, dale2, rule2, dale3).
@export var note_id := ""
## The shop it sits in (used by scripted scares, e.g. the arcade fuse).
@export var store_kind := ""
## 0 = both nights, 1 = Night 1 only, 2 = Night 2 only.
@export_range(0, 2) var night := 0
## How close you have to be to use it.
@export var reach := 2.4

var taken := false
var ring_time := 0.0   # payphones: seconds left ringing

func _ready() -> void:
	add_to_group("interactable")

## Where hiding puts your eyes (hide spots only).
func spot() -> Marker3D:
	return get_node_or_null("Spot") as Marker3D

## Where you step out to (hide spots only).
func exit_point() -> Marker3D:
	return get_node_or_null("Exit") as Marker3D

func take() -> void:
	taken = true
	visible = false
