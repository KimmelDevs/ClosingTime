## A display figure built from mannequin.glb. Pick a pose, a dress colour, the stand and the
## security uniform in the Inspector; the game also re-poses them at runtime.
extends Node3D
class_name Mannequin

const JOINTS := ["hips", "spine", "neck", "head", "lS", "lE", "lH", "lK", "rS", "rE", "rH", "rK"]
## Joint rotations in radians (X, Y, Z), the same poses as the web version.
const POSES := {
	"idle": {"lS": [0, 0, 0.12], "rS": [0, 0, -0.12], "lE": [-0.15, 0, 0], "rE": [-0.15, 0, 0]},
	"reach": {"lS": [-1.45, 0, 0.05], "rS": [-1.35, 0, -0.05], "lE": [-0.1, 0, 0], "rE": [-0.25, 0, 0], "head": [0.15, 0, 0], "spine": [0.12, 0, 0]},
	"tilt": {"head": [0.1, 0, 0.7], "neck": [0, 0, 0.25], "lS": [0, 0, 0.08], "rS": [0, 0, -0.08], "lE": [-0.1, 0, 0], "rE": [-0.1, 0, 0]},
	"point": {"rS": [-1.6, 0.25, 0], "lS": [0, 0, 0.12], "head": [0, 0, -0.2]},
	"hunch": {"spine": [0.45, 0, 0], "head": [0.55, 0, 0.25], "lS": [-0.5, 0, 0.2], "rS": [-0.4, 0, -0.25], "lE": [-0.4, 0, 0], "rE": [-0.3, 0, 0]},
	"stride": {"lH": [-0.5, 0, 0], "rH": [0.35, 0, 0], "lK": [0.25, 0, 0], "rK": [0.5, 0, 0], "lS": [0.4, 0, 0.1], "rS": [-0.5, 0, -0.1], "rE": [-0.4, 0, 0], "spine": [0.08, 0, 0]},
	"face": {"lS": [-1.1, 0, 0.35], "lE": [-2.1, 0, 0], "rS": [-1.1, 0, -0.35], "rE": [-2.1, 0, 0], "head": [0.3, 0, 0]},
	"peek": {"spine": [0, 0, 0.3], "head": [0, 0.4, -0.65], "lS": [0, 0, 0.45], "rS": [0, 0, -0.2]},
	"wave": {"rS": [0, 0, -2.6], "rE": [0, 0, -0.5], "lS": [0, 0, 0.12], "head": [0, 0, 0.3]},
}

@export_enum("idle", "reach", "tilt", "point", "hunch", "stride", "face", "peek", "wave") var pose := "idle":
	set(v):
		pose = v
		if is_inside_tree(): set_pose(v)
## Alpha 0 = no dress.
@export var dress_color := Color(0, 0, 0, 0)
@export var show_stand := true
@export var uniform := false
## Optional material for the whole body (the black shadow figure, the porcelain girl).
@export var skin_material: Material

var joints := {}

func _ready() -> void:
	add_to_group("mannequin")
	var model := get_node_or_null("Model")
	if model == null: return
	for j in JOINTS:
		var n := model.find_child(j, true, false) as Node3D
		if n:
			n.rotation_order = EULER_ORDER_XYZ
			joints[j] = n
	_set_visible(model, "dress", dress_color.a > 0.0)
	_set_visible(model, "uniform", uniform)
	_set_visible(model, "cap", uniform)
	_set_visible(model, "stand", show_stand)
	if dress_color.a > 0.0:
		var dm := StandardMaterial3D.new(); dm.albedo_color = Color(dress_color, 1.0); dm.roughness = 0.92
		dm.cull_mode = BaseMaterial3D.CULL_DISABLED
		_paint(model.find_child("dress", true, false), dm)
	if skin_material:
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			if not _under(mi, "dress") and not _under(mi, "uniform") and not _under(mi, "cap"):
				(mi as MeshInstance3D).material_override = skin_material
	set_pose(pose)

func set_pose(p: String) -> void:
	var data: Dictionary = POSES.get(p, POSES["idle"])
	for j in joints:
		var r: Array = data.get(j, [0, 0, 0])
		joints[j].rotation = Vector3(r[0], r[1], r[2])

func random_pose(choices: Array = POSES.keys()) -> void:
	set_pose(choices.pick_random())

func _set_visible(model: Node, part: String, on: bool) -> void:
	var n := model.find_child(part, true, false) as Node3D
	if n: n.visible = on

func _paint(n: Node, m: Material) -> void:
	if n == null: return
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m
	if n is MeshInstance3D: (n as MeshInstance3D).material_override = m

func _under(n: Node, part: String) -> bool:
	var p := n
	while p and p != self:
		if p.name == part: return true
		p = p.get_parent()
	return false
