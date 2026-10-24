## Builds res://scenes/mall.tscn from the models in res://models.
## Run:  Godot --headless --path godot --script res://tools/build_mall.gd
## WARNING: re-running overwrites mall.tscn (and any edits you made to it). Edit the scene in the
## editor afterwards instead, or change this script and rebuild.
extends SceneTree

const W := 60
const H := 32
const C := 2.0
const WH := 4.0
enum { FLOOR, WALL, GLASS, PROP, GATE }

var grid := PackedByteArray()
var stores: Array = []
var rng := RandomNumberGenerator.new()
var mall: Node3D
var nav: NavigationRegion3D
var groups := {}
var models := {}

func _init() -> void:
	rng.seed = 1989
	grid.resize(W * H); grid.fill(WALL)
	layout()
	mall = Node3D.new(); mall.name = "Mall"
	nav = NavigationRegion3D.new(); nav.name = "Navigation"
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1 | 2
	nm.agent_radius = 0.5; nm.agent_height = 2.0; nm.agent_max_climb = 0.25
	nm.cell_size = 0.25; nm.cell_height = 0.25
	nav.navigation_mesh = nm
	add(mall, nav)
	for g in ["Structure", "Storefronts", "Props", "Decor", "Mannequins", "Items", "Lights", "Signs", "Events", "Markers", "Stores"]:
		var n := Node3D.new(); n.name = g
		add(nav if g in ["Structure", "Storefronts", "Props", "Mannequins"] else mall, n)
		groups[g] = n
	build_structure()
	build_storefronts()
	furnish_stores()
	build_story_items()
	build_atrium()
	build_decor()
	build_department_store()
	build_hiding()
	build_events()
	build_lights()
	build_polish()
	build_occluders()
	build_markers()
	var ps := PackedScene.new()
	var err := ps.pack(mall)
	if err != OK: push_error("pack failed %d" % err)
	err = ResourceSaver.save(ps, "res://scenes/mall.tscn")
	print("saved mall.tscn: ", err)
	quit()

# ------------------------------------------------------------------ layout (same grid as the web version)
func gget(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W or y >= H: return WALL
	return grid[y * W + x]
func gset(x: int, y: int, v: int) -> void: grid[y * W + x] = v
func rect(x0: int, y0: int, x1: int, y1: int, v: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1): gset(x, y, v)
func cx(x: float) -> float: return x * C + C / 2.0
func cz(y: float) -> float: return y * C + C / 2.0

func layout() -> void:
	rect(2, 8, 41, 23, FLOOR)
	rect(6, 12, 11, 19, WALL); rect(32, 12, 37, 19, WALL)
	var top := [["SECURITY", "office", "#9fb4c8"], ["PETAL & PINE", "florist", "#9fd8a0"], ["LUMEN DISPLAY CO.", "display", "#f2e6c8"],
		["HALVORSEN SHOES", "shoes", "#e0b070"], ["ORBIT ARCADE", "arcade", "#c58cff"], ["SWEET STREET", "candy", "#ff8fb8"]]
	var bot := [["MAINTENANCE", "maint", "#d0c060"], ["BIJOU JEWELERS", "jewel", "#8fe0ff"], ["VELVET ROSE", "boutique", "#ff6070"],
		["PAPER MOON BOOKS", "books", "#e8d8a0"], ["MODE ATELIER", "boutique2", "#f4f4f4"], ["MR. PRETZEL", "food", "#ffb040"]]
	for i in 6:
		var x0 := 2 + i * 7
		rect(x0, 1, x0 + 5, 6, FLOOR)
		for x in range(x0, x0 + 6): gset(x, 7, GLASS)
		gset(x0 + 2, 7, FLOOR); gset(x0 + 3, 7, FLOOR)
		stores.append(make_store(top[i], x0, 1, x0 + 5, 6, "s"))
		rect(x0, 25, x0 + 5, 30, FLOOR)
		for x in range(x0, x0 + 6): gset(x, 24, GLASS)
		gset(x0 + 2, 24, FLOOR); gset(x0 + 3, 24, FLOOR)
		stores.append(make_store(bot[i], x0, 25, x0 + 5, 30, "n"))
	rect(7, 13, 10, 18, FLOOR)
	for y in range(13, 19): gset(11, y, GLASS)
	gset(11, 15, FLOOR); gset(11, 16, FLOOR)
	stores.append(make_store(["THE ATRIUM WINDOW", "window", "#ff5050"], 7, 13, 10, 18, "e"))
	rect(33, 13, 36, 18, FLOOR)
	for y in range(13, 19): gset(32, y, GLASS)
	gset(32, 15, FLOOR); gset(32, 16, FLOOR)
	stores.append(make_store(["PHOTO HUT", "photo", "#80ffd0"], 33, 13, 36, 18, "w"))
	for y in range(14, 18): gset(1, y, GATE)
	rect(43, 4, 58, 27, FLOOR)
	for y in [15, 16]: gset(42, y, GATE)
	rect(13, 12, 16, 12, PROP); rect(27, 19, 30, 19, PROP)
	rect(20, 14, 23, 17, PROP)
	for c in [[13, 9], [30, 9], [13, 22], [30, 22], [16, 13], [27, 18], [16, 18], [27, 13], [18, 12], [25, 19], [17, 16], [26, 15],
		[10, 9], [34, 22], [3, 20], [3, 11], [14, 17], [29, 14], [2, 18], [2, 13], [19, 18], [41, 13], [41, 18]]:
		gset(c[0], c[1], PROP)

func make_store(d: Array, x0: int, y0: int, x1: int, y1: int, face: String) -> Dictionary:
	var ns := face == "s" or face == "n"
	var s := {"name": d[0], "kind": d[1], "color": Color(d[2]), "x0": x0, "y0": y0, "x1": x1, "y1": y1, "face": face}
	s.U = (x1 - x0) if ns else (y1 - y0)
	s.V = (y1 - y0) if ns else (x1 - x0)
	s.fwd = {"s": Vector2i(0, 1), "n": Vector2i(0, -1), "e": Vector2i(1, 0), "w": Vector2i(-1, 0)}[face]
	s.udir = Vector2i(1, 0) if ns else Vector2i(0, 1)
	s.item = cell(s, 2, s.V - 1)
	return s

func cell(s: Dictionary, u: int, v: int) -> Vector2i:
	match s.face:
		"s": return Vector2i(s.x0 + u, s.y1 - v)
		"n": return Vector2i(s.x0 + u, s.y0 + v)
		"e": return Vector2i(s.x1 - v, s.y0 + u)
	return Vector2i(s.x0 + v, s.y0 + u)

func store(kind: String) -> Dictionary:
	for s in stores:
		if s.kind == kind: return s
	return {}

# ------------------------------------------------------------------ scene helpers
func add(parent: Node, n: Node, nm := "") -> Node:
	if nm != "": n.name = nm
	parent.add_child(n, true)
	n.owner = mall
	return n

func model(name: String) -> PackedScene:
	if not models.has(name):
		models[name] = load("res://models/%s.glb" % name)
		if models[name] == null: push_error("missing model " + name)
	return models[name]

func aabb_of(n: Node3D) -> AABB:
	var box := AABB(); var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D(); var p: Node = mi
		while p and p != n:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b: AABB = xf * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b); first = false
	return box

## Add a model instance. collide: 0 none, 1 world layer, 2 glass layer.
func inst(name: String, pos: Vector3, rot_y := 0.0, parent: Node = null, collide := 1, node_name := "") -> Node3D:
	var n := model(name).instantiate() as Node3D
	add(parent if parent else groups.Props, n, node_name if node_name != "" else name)
	n.position = pos; n.rotation.y = rot_y
	if collide > 0: add_box_collider(n, aabb_of(n), collide)
	return n

func add_box_collider(n: Node3D, b: AABB, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new(); body.name = "Collision"
	body.collision_layer = layer; body.collision_mask = 0
	add(n, body)
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new()
	sh.size = b.size.max(Vector3(0.05, 0.05, 0.05)); cs.shape = sh; cs.position = b.get_center()
	add(body, cs)
	return body

func box_body(parent: Node, nm: String, size: Vector3, pos: Vector3, layer := 1) -> StaticBody3D:
	var body := StaticBody3D.new(); body.collision_layer = layer; body.collision_mask = 0
	add(parent, body, nm); body.position = pos
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; cs.shape = sh
	add(body, cs)
	return body

func tex_mat(tex: String, uv: Vector2, tint := Color.WHITE, rough := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/%s.png" % tex); m.albedo_color = tint
	m.uv1_scale = Vector3(uv.x, uv.y, 1); m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func plane(parent: Node, nm: String, size: Vector2, pos: Vector3, mat: Material, down := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = size; mi.mesh = pm
	mi.material_override = mat
	add(parent, mi, nm); mi.position = pos
	if down: mi.rotation.x = PI
	return mi

func label(text: String, color: Color, pos: Vector3, rot_y: float, size := 64, parent: Node = null) -> Label3D:
	var l := Label3D.new(); l.text = text; l.modulate = color; l.font_size = size; l.pixel_size = 0.005
	l.outline_size = 0; l.shaded = false; l.double_sided = false
	l.font = load("res://fonts/Oswald.ttf") if ResourceLoader.exists("res://fonts/Oswald.ttf") else null
	add(parent if parent else groups.Signs, l, "Sign")
	l.position = pos; l.rotation.y = rot_y
	l.add_to_group("sign", true)
	return l

func mannequin(pos: Vector3, rot_y: float, pose := "", dress := Color(0, 0, 0, 0), stand := true, parent: Node = null, nm := "Mannequin") -> Node3D:
	var w := Node3D.new(); w.set_script(load("res://scripts/mannequin.gd"))
	add(parent if parent else groups.Mannequins, w, nm)
	w.position = pos; w.rotation.y = rot_y
	var m := model("mannequin").instantiate()
	add(w, m, "Model")
	w.set("pose", pose if pose != "" else ["idle", "idle", "point", "tilt", "stride", "wave"][rng.randi() % 6])
	w.set("dress_color", dress if dress.a > 0 or rng.randf() > 0.45 else [Color("2b3540"), Color("4a4238"), Color("1d1d22"), Color("5a4a5a"), Color("324a3a")][rng.randi() % 5])
	w.set("show_stand", stand)
	var body := StaticBody3D.new(); body.collision_layer = 1; body.collision_mask = 0
	add(w, body, "Collision")
	var cs := CollisionShape3D.new(); var sh := CylinderShape3D.new(); sh.radius = 0.3; sh.height = 1.8; cs.shape = sh; cs.position.y = 0.9
	add(body, cs)
	return w

func item(kind: String, model_name: String, pos: Vector3, rot_y := 0.0, props := {}) -> Node3D:
	var w := Node3D.new(); w.set_script(load("res://scripts/interactable.gd"))
	add(groups.Items, w, props.get("name", kind.capitalize()))
	w.position = pos; w.rotation.y = rot_y
	w.set("kind", kind)
	for k in props:
		if k != "name": w.set(k, props[k])
	if model_name != "": add(w, model(model_name).instantiate(), "Model")
	return w

func rot_for(d: Vector2i) -> float: return atan2(float(d.x), float(d.y))

# ------------------------------------------------------------------ structure
func build_structure() -> void:
	var S: Node3D = groups.Structure
	var fm := tex_mat("floor", Vector2(W * C / 2.0, H * C / 2.0), Color.WHITE, 1.0)
	fm.roughness_texture = load("res://textures/floor_rough.png"); fm.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED; fm.metallic = 0.05
	plane(S, "Floor", Vector2(W * C, H * C), Vector3(W * C / 2.0, 0, H * C / 2.0), fm)
	box_body(S, "FloorCollision", Vector3(W * C, 0.2, H * C), Vector3(W * C / 2.0, -0.1, H * C / 2.0))
	# ceiling with an opening over the atrium (x 26..62, z 24..40)
	for r in [[0, W * C, 0, 24], [0, W * C, 40, H * C], [0, 26, 24, 40], [62, W * C, 24, 40]]:
		var sz := Vector2(r[1] - r[0], r[3] - r[2])
		plane(S, "Ceiling", sz, Vector3((r[0] + r[1]) / 2.0, WH, (r[2] + r[3]) / 2.0), tex_mat("ceiling", sz / 2.0), true)
	inst("upper_level", Vector3.ZERO, 0, S, 0, "UpperLevel")
	# walls: a GridMap you can paint in the editor
	var lib := MeshLibrary.new()
	var wall := model("wall").instantiate()
	var mi := wall.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	lib.create_item(0); lib.set_item_name(0, "wall")
	lib.set_item_mesh(0, mi.mesh); lib.set_item_mesh_transform(0, mi.transform)
	var bs := BoxShape3D.new(); bs.size = Vector3(2, 4, 2)
	lib.set_item_shapes(0, [bs, Transform3D(Basis(), Vector3(0, 2, 0))])
	ResourceSaver.save(lib, "res://scenes/mall_walls.tres")
	var gm := GridMap.new(); gm.mesh_library = load("res://scenes/mall_walls.tres")
	gm.cell_size = Vector3(2, 4, 2); gm.cell_center_y = false
	gm.collision_layer = 1; gm.collision_mask = 0
	add(S, gm, "Walls")
	for y in H:
		for x in W:
			if gget(x, y) != WALL: continue
			if gget(x - 1, y) != WALL or gget(x + 1, y) != WALL or gget(x, y - 1) != WALL or gget(x, y + 1) != WALL:
				gm.set_cell_item(Vector3i(x, 0, y), 0)
	# store carpets
	for s in stores:
		var sz := Vector2((s.x1 - s.x0 + 1) * C, (s.y1 - s.y0 + 1) * C)
		var m := tex_mat("carpet", sz / 2.0, (s.color as Color) * 0.45)
		plane(S, "Carpet", sz, Vector3((s.x0 + s.x1 + 1) / 2.0 * C, 0.005, (s.y0 + s.y1 + 1) / 2.0 * C), m)
	# main gate, the outside, the exit sign
	var gate := inst("gate_shutter", Vector3(2 * C + 0.02, 0, 16 * C), PI / 2, S, 0, "GateShutter")
	box_body(gate, "Collision", Vector3(8, 4, 0.4), Vector3(0, 2, 0))
	inst("outside_view", Vector3(C + 0.05, 0, 16 * C), PI / 2, S, 0, "Outside")
	label("EXIT", Color(1, 0.16, 0.12), Vector3(2 * C + 0.25, WH - 0.35, 16 * C), PI / 2, 80)
	# the department store grille (Night 1)
	var gr := inst("grille", Vector3(42 * C + 0.15, 0, 16 * C), 0, S, 0, "Grille")
	box_body(gr, "Collision", Vector3(0.3, 3, 4), Vector3(0, 1.5, 0))
	# escalators
	for e in [[Vector3(34, 0, 25), 0.0], [Vector3(54, 0, 39), PI]]:
		var es := inst("escalator", e[0], e[1], S, 0, "Escalator")
		box_body(es, "Collision", Vector3(9, 4.4, 1.6), Vector3(-3.9, 2.2, 0))

func build_storefronts() -> void:
	for s in stores:
		var ns: bool = s.face == "s" or s.face == "n"
		for u in range(s.U + 1):
			var c := cell(s, u, 0) + (s.fwd as Vector2i)
			var pos := Vector3(cx(c.x), 0, cz(c.y))
			if gget(c.x, c.y) == GLASS:
				var g := inst("storefront_glass", pos, 0.0 if ns else PI / 2, groups.Storefronts, 0, "Glass")
				box_body(g, "Collision", Vector3(2, 3, 0.2), Vector3(0, 1.5, 0), 2)
			else:
				inst("storefront_door", pos, 0.0 if ns else PI / 2, groups.Storefronts, 0, "Door")
		# sign over the door, on the hall side
		var mid := cell(s, 2, 0)
		var f: Vector2i = s.fwd
		var sp: Vector3
		if ns: sp = Vector3((mid.x + 1) * C, WH - 0.5, (mid.y + f.y + 0.5) * C + f.y * 0.21)
		else: sp = Vector3((mid.x + f.x + 0.5) * C + f.x * 0.21, WH - 0.5, (mid.y + 1) * C)
		var l := label(s.name, s.color, sp, rot_for(f), 72)
		l.set_meta("flicker", rng.randf() < 0.35)
		var meta := Node3D.new(); add(groups.Stores, meta, s.kind)
		for k in ["x0", "y0", "x1", "y1", "face"]: meta.set_meta(k, s[k])
		meta.set_meta("title", s.name)

# ------------------------------------------------------------------ shop interiors
const KIND := {
	"office": {"edge": ["lockers", "shelf_goods"]},
	"florist": {"edge": ["flower_buckets", "shelf_goods"], "front": "flower_buckets"},
	"display": {"edge": ["shelf_heads", "shelf_goods"], "decoys": 4, "front_decoys": true},
	"shoes": {"edge": ["shelf_goods"], "front": "candy_bins"},
	"arcade": {"edge": ["arcade_cabinet"], "front": "arcade_cabinet"},
	"candy": {"edge": ["candy_bins", "shelf_goods"], "front": "candy_bins"},
	"maint": {"edge": ["pipes", "shelf_goods"]},
	"jewel": {"edge": ["glass_case"], "front": "glass_case"},
	"boutique": {"edge": ["clothes_rack", "shelf_goods"], "decoys": 2, "front_decoys": true},
	"books": {"edge": ["shelf_books"]},
	"boutique2": {"edge": ["clothes_rack"], "decoys": 3, "front_decoys": true},
	"food": {"edge": ["food_counter"], "inner": "cafe_table"},
	"window": {"edge": []},
	"photo": {"edge": ["shelf_goods", "counter"]},
}
func reserved(s: Dictionary) -> Array:
	var r: Array = [s.item]
	if s.kind in ["boutique", "boutique2", "maint"]: r.append(cell(s, 4, s.V - 1))
	return r

func furnish_stores() -> void:
	for s in stores:
		var k: Dictionary = KIND[s.kind]
		var res := reserved(s)
		for u in range(s.U + 1):
			for v in range(1, s.V + 1):
				var c := cell(s, u, v)
				if c in res: continue
				var edge: bool = v == s.V or u == 0 or u == s.U
				if not edge or k.edge.is_empty() or rng.randf() > 0.75: continue
				var d: Vector2i = s.fwd if v == s.V else (s.udir if u == 0 else -(s.udir as Vector2i))
				inst(k.edge[rng.randi() % k.edge.size()], Vector3(cx(c.x), 0, cz(c.y)), rot_for(d))
				gset(c.x, c.y, PROP)
		for u in [0, 1, s.U - 1, s.U]:
			var c := cell(s, u, 0)
			if k.get("front_decoys", false):
				mannequin(Vector3(cx(c.x), 0, cz(c.y)), rot_for(s.fwd)); gset(c.x, c.y, PROP)
			elif k.has("front") and rng.randf() < 0.5:
				inst(k.front, Vector3(cx(c.x), 0, cz(c.y)), rot_for(-(s.fwd as Vector2i))); gset(c.x, c.y, PROP)
		var n: int = k.get("decoys", 0)
		for v in range(1, s.V):
			for u in [1, s.U - 1]:
				if n <= 0: break
				var c := cell(s, u, v)
				if gget(c.x, c.y) != FLOOR or c in res: continue
				mannequin(Vector3(cx(c.x) + rng.randf_range(-0.2, 0.2), 0, cz(c.y) + rng.randf_range(-0.2, 0.2)), rot_for(s.fwd) + rng.randf_range(-0.8, 0.8))
				gset(c.x, c.y, PROP); n -= 1
		if k.has("inner"):
			for uv in [[1, 2], [4, 2]]:
				var c := cell(s, uv[0], uv[1])
				if gget(c.x, c.y) == FLOOR and not c in res:
					inst(k.inner, Vector3(cx(c.x), 0, cz(c.y)), 0); gset(c.x, c.y, PROP)

func table_at(s: Dictionary, mdl := "item_table") -> Vector3:
	var c: Vector2i = s.item
	gset(c.x, c.y, PROP)
	inst(mdl, Vector3(cx(c.x), 0, cz(c.y)), rot_for(s.fwd))
	return Vector3(cx(c.x), 0.94, cz(c.y))

func build_story_items() -> void:
	var p := table_at(store("office"), "security_desk")
	item("note", "note_paper", p, 0.3, {"note_id": "dale1", "night": 1, "name": "Note_dale1"})
	for kn in [["florist", "janitor"], ["display", "lumen"], ["boutique", "poster"], ["books", "father"]]:
		item("note", "note_paper", table_at(store(kn[0])), rng.randf_range(-0.4, 0.4), {"note_id": kn[1], "night": 1, "name": "Note_" + kn[1]})
	for k in ["shoes", "arcade", "boutique2"]:
		item("fuse", "fuse", table_at(store(k), "item_table_dark"), 0, {"store_kind": k, "night": 1, "name": "Fuse_" + k})
	for k in ["candy", "jewel", "food", "photo"]:
		item("battery", "battery", table_at(store(k)), 0, {"store_kind": k, "name": "Battery_" + k})
	var m := store("maint"); var c: Vector2i = m.item
	gset(c.x, c.y, PROP)
	var b := item("breaker", "", Vector3(cx(c.x), 0, cz(c.y)), rot_for(m.fwd), {"night": 1, "name": "Breaker", "reach": 2.6})
	var cab := model("breaker_cabinet").instantiate() as Node3D; add(b, cab, "Model")
	add_box_collider(b, aabb_of(cab), 1)
	var w := store("window"); c = w.item
	inst("pedestal", Vector3(cx(c.x), 0, cz(c.y)), 0, groups.Props, 1, "Pedestal")
	inst("velvet_backdrop", Vector3(cx(7) - 0.9, 0, cz(15) + 1), 0, groups.Props, 0, "Backdrop")
	item("note", "note_paper", Vector3(cx(c.x) + 0.15, 0.3, cz(c.y) + 0.15), 0.4, {"note_id": "dale2", "night": 1, "name": "Note_dale2"})
	item("pedestal", "", Vector3(cx(c.x), 0.9, cz(c.y) - 0.25), 0, {"night": 1, "name": "PedestalSpot"})
	# Night 2 notes
	item("note", "note_paper", Vector3(cx(3) + 0.4, 0.02, 16 * C - 2.6), 0.2, {"note_id": "rule2", "night": 2, "name": "Note_rule2"})
	item("note", "note_paper", Vector3(cx(56) + 0.3, 0.02, cz(15) + 1.7), -0.3, {"note_id": "dale3", "night": 2, "name": "Note_dale3"})
	item("gate", "", Vector3(2 * C + 0.6, 1.4, 16 * C), 0, {"reach": 3.4, "name": "MainGate"})

# ------------------------------------------------------------------ atrium & halls
func build_atrium() -> void:
	inst("fountain", Vector3(22 * C, 0, 16 * C), 0, groups.Props, 1, "Fountain")
	for c in [[13, 9], [30, 9], [13, 22], [30, 22]]: inst("kiosk", Vector3(cx(c[0]), 0, cz(c[1])), 0, groups.Props, 1, "Kiosk")
	for c in [[16, 13], [27, 18], [16, 18], [27, 13]]: inst("bench", Vector3(cx(c[0]), 0, cz(c[1])), 0, groups.Props, 1, "Bench")
	for c in [[18, 12], [25, 19]]: inst("planter", Vector3(cx(c[0]), 0, cz(c[1])), 0)
	for c in [[17, 16, -PI / 2], [26, 15, PI / 2]]:
		inst("display_platform", Vector3(cx(c[0]), 0, cz(c[1])), 0)
		mannequin(Vector3(cx(c[0]), 0.25, cz(c[1])), c[2], "idle")
	for c in [[10, 9], [34, 22], [3, 20]]: inst("trash_bin", Vector3(cx(c[0]), 0, cz(c[1])), 0)
	inst("directory_board", Vector3(cx(3), 0, cz(11)), 0, groups.Props, 1, "Directory")
	var lines := "DIRECTORY\n"
	for s in stores: lines += s.name + "\n"
	var l := label(lines + "\nYOU ARE HERE", Color(0.85, 0.81, 0.74), Vector3(cx(3), 1.25, cz(11) + 0.07), 0, 22)
	l.set_meta("base", 0.6)

func build_decor() -> void:
	var D: Node3D = groups.Decor
	for s in stores:
		if s.face != "s" and s.face != "n": continue
		var z := cz(8) - 0.5 if s.face == "s" else cz(23) + 0.5
		for x in [cx(s.x0 + 1), cx(s.x0 + 4)]:
			if rng.randf() < 0.35: continue
			inst("pumpkin", Vector3(x + rng.randf_range(-0.3, 0.3), 0, z), (-PI / 2 if s.face == "s" else PI / 2) + rng.randf_range(-0.4, 0.4), D, 0, "Pumpkin")
		if rng.randf() < 0.6:
			var u: int = [0, 1, 4, 5][rng.randi() % 4]
			var pz := cz(7) + 0.03 if s.face == "s" else cz(24) - 0.03
			var p := inst("poster_closing", Vector3(cx(s.x0 + u), 1.6, pz), 0.0 if s.face == "s" else PI, D, 0, "ClosingPoster")
			p.rotation.z = rng.randf_range(-0.08, 0.08)
	for b in [[15 * C, 12 * C + 0.3, 0.0], [29 * C, 20 * C - 0.3, PI], [22 * C, 9.5 * C, 0.04]]:
		inst("banner_sale", Vector3(b[0], 3.15, b[1]), b[2], D, 0, "Banner")
	inst("kiddie_ride", Vector3(cx(14), 0, cz(17)), 0.6, groups.Props, 1, "KiddieRide")
	inst("play_slide", Vector3(cx(29), 0, cz(14)), -0.4, groups.Props, 1, "PlaySlide")
	inst("christmas_tree", Vector3(cx(19), 0, cz(18)), 0, groups.Props, 1, "ChristmasTree")
	inst("stroller", Vector3(cx(24), 0, cz(22) + 0.4), 0.8, D, 0, "Stroller")
	var ws := inst("wet_floor_sign", Vector3(cx(24), 0.25, cz(10)), 0, D, 0, "WetFloor"); ws.rotation = Vector3(PI / 2, 0, 0.6)
	for y in [13, 18]:
		item("phone", "payphone", Vector3(2 * C + 0.18, 0, cz(y)), PI / 2, {"name": "Payphone"})
		inst("vending_red" if y == 13 else "vending_blue", Vector3(42 * C - 0.45, 0, cz(y)), -PI / 2)
	for f in [[cx(31) + 0.5, cz(10), 0.4], [cx(8), cz(21) + 0.4, 2.2], [cx(36), cz(8) + 0.3, -1.2]]:
		var m := mannequin(Vector3(f[0], 0.14, f[1]), f[2], ["reach", "stride", "tilt"][rng.randi() % 3], Color(0, 0, 0, 0), false, D, "FallenFigure")
		m.rotation.x = -PI / 2
	for p in [[cx(18), cz(8)], [cx(26), cz(23)], [cx(10), cz(16)]]: inst("glass_shards", Vector3(p[0], 0, p[1]), rng.randf() * TAU, D, 0, "Shards")
	for p in [[cx(12), cz(10), 1.2], [cx(33), cz(21), 1.6], [cx(4), cz(16), 1.0], [cx(25), cz(9), 0.9], [cx(38), cz(15), 1.3]]:
		var pd := inst("puddle", Vector3(p[0], 0, p[1]), rng.randf() * TAU, D, 0, "Puddle"); pd.scale = Vector3(p[2], 1, p[2] * rng.randf_range(0.5, 0.8))
		pd.add_to_group("puddle", true)
	for p in [[2.5 * C, 8.5 * C], [41.5 * C, 8.5 * C], [2.5 * C, 23.5 * C], [41.5 * C, 23.5 * C], [13.5 * C, 11.5 * C], [31.5 * C, 20.5 * C]]:
		var cam := inst("security_camera", Vector3(p[0], WH - 0.25, p[1]), 0, D, 0, "SecurityCamera"); cam.add_to_group("security_camera", true)
	# upstairs shop signs, long dead
	var names := ["CINEMA 4", "FOOD TERRACE", "KIDS WORLD", "RADIO HUT", "GLAMOUR SHOTS", "HALVORSEN & CO.  LEVEL 2"]
	var si := 0
	for e in [[22, 20, 66, 20, 0, 1], [22, 44, 66, 44, 0, -1], [22, 20, 22, 44, 1, 0], [66, 20, 66, 44, -1, 0]]:
		var along_x: bool = e[1] == e[3]
		var ln: float = abs(e[2] - e[0]) if along_x else abs(e[3] - e[1])
		var k := 3.5
		while k < ln - 2:
			var px: float = e[0] + k if along_x else e[0] + e[4] * 0.23
			var pz: float = e[1] + e[5] * 0.23 if along_x else e[1] + k
			var ul := label(names[si % names.size()], [Color("e8d8a0"), Color("ff8fb8"), Color("8fe0ff"), Color("c58cff")][si % 4], Vector3(px, 4.35 + 3.3, pz), atan2(float(e[4]), float(e[5])), 72)
			ul.set_meta("base", 0.1); si += 1; k += 7.5

func build_department_store() -> void:
	var sz := Vector2((58 - 43 + 1) * C, (27 - 4 + 1) * C)
	plane(groups.Structure, "Carpet_DeptStore", sz, Vector3((43 + 58 + 1) / 2.0 * C, 0.005, (4 + 27 + 1) / 2.0 * C), tex_mat("carpet", sz / 2.0, Color("5a1d24")))
	label("HALVORSEN & CO.", Color("f4e2b0"), Vector3(42 * C - 0.21, WH - 0.5, 16 * C), -PI / 2, 80).set_meta("flicker", true)
	for y in [12, 19]:
		inst("glass_case", Vector3(cx(44), 0, cz(y)), PI / 2); gset(44, y, PROP)
	for y in [6, 8, 10, 12, 19, 21, 23, 25]:
		for x in [46, 48, 52, 54, 56]:
			if gget(x, y) != FLOOR: continue
			var r := rng.randf()
			if r < 0.42: mannequin(Vector3(cx(x) + rng.randf_range(-0.3, 0.3), 0, cz(y) + rng.randf_range(-0.3, 0.3)), -PI / 2 + rng.randf_range(-1.2, 1.2))
			elif r < 0.75: inst("clothes_rack", Vector3(cx(x), 0, cz(y)), 0)
			elif r < 0.85: inst("cafe_table", Vector3(cx(x), 0, cz(y)), 0)
			else: continue
			gset(x, y, PROP)
	for y in range(4, 28, 2):
		if rng.randf() < 0.7: inst("shelf_goods", Vector3(cx(58), 0, cz(y)), -PI / 2); gset(58, y, PROP)
	inst("display_platform", Vector3(cx(57), 0.05, cz(15) + 1), 0)
	var dale := mannequin(Vector3(cx(57), 0.3, cz(15) + 1), -PI / 2, "idle", Color(0, 0, 0, 0), false, groups.Events, "Dale")
	dale.set("uniform", true)

func build_hiding() -> void:
	var hides := Node3D.new(); add(groups.Items, hides, "HidingSpots")
	for k in [[13, 9, 10], [30, 9, 10], [13, 22, 21], [30, 22, 21]]:
		var face := 1 if k[2] > k[1] else -1
		hide_spot(hides, "", Vector3(cx(k[0]), 0, cz(k[1])), Vector3(0, 0.75, 0), Vector3(0, 0, face), Vector3(cx(k[0]), 0, cz(k[2])))
	for kc in [["boutique", "fitting_booth"], ["boutique2", "fitting_booth"], ["maint", "supply_closet"]]:
		var s := store(kc[0]); var c := cell(s, 4, s.V - 1); var e := cell(s, 4, s.V - 2)
		if gget(c.x, c.y) != FLOOR: continue
		var f: Vector2i = s.fwd
		hide_spot(hides, kc[1], Vector3(cx(c.x), 0, cz(c.y)), Vector3(0, 1.5, 0), Vector3(f.x, 0, f.y), Vector3(cx(e.x), 0, cz(e.y)))
		gset(c.x, c.y, PROP)
	for k in [[44, 6, 1, 45], [57, 25, -1, 56]]:
		if gget(k[0], k[1]) != FLOOR: continue
		hide_spot(hides, "fitting_booth", Vector3(cx(k[0]), 0, cz(k[1])), Vector3(0, 1.5, 0), Vector3(k[2], 0, 0), Vector3(cx(k[3]), 0, cz(k[1])))
		gset(k[0], k[1], PROP)

func hide_spot(parent: Node, mdl: String, pos: Vector3, eye: Vector3, facing: Vector3, exit_pos: Vector3) -> void:
	var w := Node3D.new(); w.set_script(load("res://scripts/interactable.gd"))
	add(parent, w, "Hide"); w.position = pos + Vector3(0, max(eye.y, 0.9), 0)
	w.set("kind", "hide")
	if mdl != "":
		var m := model(mdl).instantiate() as Node3D; add(w, m, "Model")
		m.position = Vector3(0, -max(eye.y, 0.9), 0); m.rotation.y = atan2(facing.x, facing.z)
		var b := aabb_of(m)
		# three walls so you can't walk through, open at the curtain side
		var body := StaticBody3D.new(); body.collision_layer = 1; body.collision_mask = 0; add(m, body, "Collision")
		for part in [[Vector3(1.6, 2.3, 0.1), Vector3(0, 1.15, -0.75)], [Vector3(0.1, 2.3, 1.5), Vector3(-0.78, 1.15, 0)], [Vector3(0.1, 2.3, 1.5), Vector3(0.78, 1.15, 0)], [Vector3(1.6, 2.1, 0.1), Vector3(0, 1.05, 0.74)]]:
			var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = part[0]; cs.shape = sh; cs.position = part[1]; add(body, cs)
	var sp := Marker3D.new(); add(w, sp, "Spot"); sp.position = Vector3(0, eye.y - max(eye.y, 0.9), 0); sp.rotation.y = atan2(-facing.x, -facing.z)
	var ex := Marker3D.new(); add(w, ex, "Exit");
	ex.position = exit_pos - w.position + Vector3(0, 0, 0)

# ------------------------------------------------------------------ scripted-scare props (hidden until used)
func build_events() -> void:
	var E: Node3D = groups.Events
	var shade_mat := StandardMaterial3D.new(); shade_mat.albedo_color = Color(0.047, 0.043, 0.043); shade_mat.roughness = 0.85
	var shade := mannequin(Vector3(cx(21) + 11, 0, 21 * C + 0.5), -PI / 2, "tilt", Color(0, 0, 0, 0), false, E, "Shade")
	shade.set("skin_material", shade_mat); shade.scale = Vector3(0.95, 1.25, 0.95); shade.visible = false
	var iris_mat := StandardMaterial3D.new(); iris_mat.albedo_color = Color("ebe5da"); iris_mat.roughness = 0.22
	var ghost := mannequin(Vector3(40, 4.35, 22.8), 0, "idle", Color("5c0b12"), false, E, "Ghost")
	ghost.set("skin_material", iris_mat); ghost.visible = false
	for n in [shade, ghost]:   # staged figures: no collision, they only exist to be seen
		var col: Node = n.get_node("Collision"); n.remove_child(col); col.free()
	var lamps := Node3D.new(); add(E, lamps, "LampCorridor")
	for i in 5:
		var l := OmniLight3D.new(); add(lamps, l, "Lamp%d" % i)
		l.position = Vector3(cx(21) + i * 3, WH - 0.3, 21 * C + 0.5); l.light_energy = 0; l.omni_range = 9; l.light_color = Color("fff0d8")
		var pm := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(1.4, 0.06, 0.5); pm.mesh = bm
		var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.13, 0.13, 0.13); mat.emission_enabled = true; mat.emission = Color("fff4e0"); mat.emission_energy_multiplier = 0
		pm.material_override = mat; add(l, pm, "Panel"); pm.position = Vector3(0, 0.26, 0)
	var hands := Node3D.new(); add(E, hands, "Hands"); hands.visible = false
	for h in [[13, 1.5], [14, 1.2], [17, 1.6], [18, 1.35]]:
		var d := inst("hands_decal", Vector3(cx(11) + 0.05, h[1], cz(h[0]) + rng.randf_range(-0.3, 0.3)), PI / 2, hands, 0, "Handprints")
		d.rotation.z = rng.randf_range(-0.3, 0.3)

func build_lights() -> void:
	var L: Node3D = groups.Lights
	var panels := Node3D.new(); add(L, panels, "CeilingPanels")
	var spots: Array = []
	for y in range(8, 24):
		for x in range(2, 42):
			if gget(x, y) != WALL and x % 3 == 0 and y % 3 == 1 and not (x >= 13 and x <= 30 and y >= 12 and y <= 19): spots.append(Vector2i(x, y))
	for s in stores:
		for uv in [[2, 2], [2, 4]]: spots.append(cell(s, uv[0], uv[1]))
	for y in range(5, 27, 3):
		for x in range(44, 58, 3): spots.append(Vector2i(x, y))
	for c in spots: inst("ceiling_panel", Vector3(cx(c.x), WH, cz(c.y)), 0, panels, 0, "Panel")
	var hall := Node3D.new(); add(L, hall, "HallLights")
	for p in [[8, 9.5], [21, 9.5], [34, 9.5], [8, 21.5], [21, 21.5], [34, 21.5], [3.5, 15.5], [21.5, 15.5], [47, 10], [52, 20]]:
		var atrium: bool = p[0] > 13 and p[0] < 31 and p[1] > 12 and p[1] < 20
		var l := OmniLight3D.new(); add(hall, l, "HallLight")
		l.position = Vector3(p[0] * C, 8.0 if atrium else WH - 0.4, p[1] * C); l.omni_range = 22.0 if atrium else 15.0
		l.light_color = Color("dfe8ff"); l.light_energy = 0.0; l.add_to_group("hall_light", true)
		l.set_meta("flicker", rng.randf() < 0.4)
	var em := Node3D.new(); add(L, em, "Emergency")
	for p in [[cx(2) + 0.1, 3.2, 16 * C], [cx(4), 3.3, cz(26)], [cx(41) - 0.2, 3.2, 16 * C], [21 * C, 3.6, cz(8)]]:
		var l := OmniLight3D.new(); add(em, l, "EmergencyLight"); l.position = Vector3(p[0], p[1], p[2])
		l.light_color = Color("ff2a18"); l.light_energy = 0.8; l.omni_range = 9; l.add_to_group("emergency_light", true)
		inst("emergency_light", Vector3(p[0], p[1] + 0.2, p[2]), 0, em, 0, "Fixture")
	var moon := SpotLight3D.new(); add(L, moon, "Moonlight"); moon.position = Vector3(22 * C, 8.3, 16 * C); moon.rotation.x = -PI / 2
	moon.light_color = Color("6f86b8"); moon.light_energy = 2.0; moon.spot_range = 22; moon.spot_angle = 50
	var w := store("window"); var c: Vector2i = w.item
	var red := SpotLight3D.new(); add(L, red, "PedestalLight"); red.position = Vector3(cx(c.x), WH - 0.1, cz(c.y)); red.rotation.x = -PI / 2
	red.light_color = Color("ff3a30"); red.light_energy = 2.0; red.spot_range = 8; red.spot_angle = 26
	var ds := SpotLight3D.new(); add(L, ds, "DaleLight"); ds.position = Vector3(cx(57), WH - 0.1, cz(15) + 1); ds.rotation.x = -PI / 2
	ds.light_color = Color("fff0d0"); ds.light_energy = 3.0; ds.spot_range = 10; ds.spot_angle = 23

func build_markers() -> void:
	var M: Node3D = groups.Markers
	for m in [["Spawn", Vector3(cx(3) + 0.5, 0, 16 * C), 0.0], ["Respawn", Vector3(cx(4), 0, cz(4)), 0.0], ["IrisStart", Vector3(cx(40), 0, cz(28)), 0.0], ["IrisStartNight2", Vector3(cx(50), 0, cz(8)), 0.0]]:
		var mk := Marker3D.new(); add(M, mk, m[0]); mk.position = m[1]; mk.rotation.y = m[2]
	var pr := Marker3D.new(); add(M, pr, "PedestalTop"); pr.position = Vector3(cx(store("window").item.x), 0.3, cz(store("window").item.y)); pr.rotation.y = PI / 2

# ------------------------------------------------------------------ polish: 80s neon trim, shop lights
func build_polish() -> void:
	var neon := Node3D.new(); add(groups.Decor, neon, "HallNeon")
	for t in [[7 * C + C / 2.0 + 0.23, Color("2ae6d4")], [24 * C + C / 2.0 - 0.23, Color("ff4fa8")]]:
		var m := StandardMaterial3D.new(); m.resource_name = "hall_neon"; m.albedo_color = Color(0.07, 0.07, 0.07)
		m.emission_enabled = true; m.emission = t[1]; m.emission_energy_multiplier = 0.1
		var cm := CylinderMesh.new(); cm.top_radius = 0.025; cm.bottom_radius = 0.025; cm.height = 39 * C; cm.radial_segments = 8; cm.material = m
		var mi := MeshInstance3D.new(); mi.mesh = cm; add(neon, mi, "Tube")
		mi.position = Vector3(22 * C, WH - 1.03, t[0]); mi.rotation.z = PI / 2
	var shop := Node3D.new(); add(groups.Lights, shop, "ShopLights")
	for s in stores:
		var l := OmniLight3D.new(); add(shop, l, "ShopLight")
		l.position = Vector3((s.x0 + s.x1 + 1) / 2.0 * C, WH - 0.5, (s.y0 + s.y1 + 1) / 2.0 * C)
		l.light_color = (s.color as Color).lerp(Color.WHITE, 0.6); l.light_energy = 0.0; l.omni_range = 7.0
		l.add_to_group("shop_light", true)

# ------------------------------------------------------------------ occlusion: box occluders over runs of wall cells
func build_occluders() -> void:
	var occ := Node3D.new(); add(groups.Structure, occ, "Occluders")
	for y in H:
		var x := 0
		while x < W:
			if gget(x, y) != WALL: x += 1; continue
			var x0 := x
			while x < W and gget(x, y) == WALL: x += 1
			var n := x - x0
			if n < 2: continue
			var oi := OccluderInstance3D.new(); var bo := BoxOccluder3D.new(); bo.size = Vector3(n * C, WH, C)
			oi.occluder = bo; add(occ, oi, "Occluder"); oi.position = Vector3(x0 * C + n * C / 2.0, WH / 2.0, cz(y))
