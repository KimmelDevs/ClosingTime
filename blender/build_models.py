"""
Build every model for Closing Time in Blender and export it for Godot.

Run:  blender -b -P blender/build_models.py
Out:  blender/models/<name>.blend   (edit these)
      godot/models/<name>.glb       (what Godot uses; re-export after editing: File > Export > glTF 2.0 (.glb))

Geometry is written in the game's coordinates (Y up, +Z = the model's front) and converted to
Blender's Z-up frame, so the exported glTF lands back in game coordinates with clean node transforms.
"""
import bpy, bmesh, os, math, random
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TEX = os.path.join(ROOT, 'godot', 'textures')
GLB = os.path.join(ROOT, 'godot', 'models')
BLEND = os.path.join(HERE, 'models')
os.makedirs(GLB, exist_ok=True); os.makedirs(BLEND, exist_ok=True)
rng = random.Random(1989)

P = Matrix.Rotation(math.radians(90), 4, 'X')   # game (x, y, z) -> Blender (x, -z, y)
PI = P.inverted()

# ---------------------------------------------------------------- materials
_mats = {}
def mat(name, color=(0.8, 0.8, 0.8), rough=0.6, metal=0.0, tex=None, emit=None, emit_strength=0.0, emit_tex=False, alpha=1.0):
    if name in _mats: return _mats[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if tex:
        img = bpy.data.images.load(os.path.join(TEX, tex + '.png'), check_existing=True)
        n = nt.nodes.new('ShaderNodeTexImage'); n.image = img
        nt.links.new(n.outputs['Color'], b.inputs['Base Color'])
        if alpha < 1 or tex in ('hands',):
            nt.links.new(n.outputs['Alpha'], b.inputs['Alpha'])
        if emit_tex:
            nt.links.new(n.outputs['Color'], b.inputs['Emission Color'])
            b.inputs['Emission Strength'].default_value = emit_strength
    if emit is not None:
        b.inputs['Emission Color'].default_value = (*emit, 1)
        b.inputs['Emission Strength'].default_value = emit_strength
    if alpha < 1:
        b.inputs['Alpha'].default_value = alpha
    if alpha < 1 or tex == 'hands':
        for attr, val in (('surface_render_method', 'BLENDED'), ('blend_method', 'BLEND')):
            if hasattr(m, attr):
                try: setattr(m, attr, val)
                except Exception: pass
    _mats[name] = m
    return m

def MATS():
    return dict(
        wall=mat('wall', (0.85, 0.82, 0.76), 0.88, tex='wall'),
        laminate=mat('laminate', (0.79, 0.75, 0.68), 0.5),
        dark=mat('dark', (0.09, 0.086, 0.1), 0.8),
        wood=mat('wood', (0.35, 0.24, 0.16), 0.65),
        metal=mat('metal', (0.54, 0.55, 0.56), 0.35, 0.85),
        tile=mat('tile', (0.43, 0.48, 0.47), 0.35),
        glass=mat('glass', (0.62, 0.7, 0.74), 0.04, 0.6, alpha=0.16),
        header=mat('header', (0.14, 0.13, 0.12), 0.7),
        velvet=mat('velvet', (0.29, 0.04, 0.06), 1.0),
        plant=mat('dead_plant', (0.23, 0.19, 0.13), 0.95),
        skin=mat('mannequin_skin', (0.85, 0.82, 0.76), 0.32),
        socket=mat('mannequin_socket', (0.23, 0.2, 0.17), 0.7),
        screen=mat('screen', (0.02, 0.02, 0.02), 0.3, emit=(0.48, 0.63, 1.0), emit_strength=0.4),
        emerg=mat('emergency', (0.13, 0, 0), 0.5, emit=(1.0, 0.1, 0.06), emit_strength=3.0),
        water=mat('water', (0.02, 0.04, 0.05), 0.03, 0.9),
        navy=mat('navy', (0.1, 0.14, 0.2), 0.8),
        paper=mat('paper', (1, 1, 1), 0.9, tex='paper'),
    )

# ---------------------------------------------------------------- geometry helpers (game coordinates)
def scene_reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()

def set_xform(ob, pos=(0, 0, 0), rot=(0, 0, 0), parent=None):
    Mw = Matrix.Translation(Vector(pos)) @ Matrix.Rotation(rot[0], 4, 'X') @ Matrix.Rotation(rot[1], 4, 'Y') @ Matrix.Rotation(rot[2], 4, 'Z')
    ob.parent = parent
    ob.matrix_parent_inverse = Matrix.Identity(4)
    ob.matrix_basis = P @ Mw @ PI

def box_uv(bm, tu=1.0, tv=None):
    """project UVs by face normal; tu/tv are metres per texture repeat"""
    tv = tv or tu
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        for l in f.loops:
            co = l.vert.co
            if abs(n.z) >= abs(n.x) and abs(n.z) >= abs(n.y): u, v = co.x / tu, co.y / tu
            elif abs(n.x) >= abs(n.y): u, v = co.y / tu, co.z / tv
            else: u, v = co.x / tu, co.z / tv
            l[uv].uv = (u, v)

def make(name, bm, material, parent=None, pos=(0, 0, 0), rot=(0, 0, 0), uv=None, smooth=False):
    if uv: box_uv(bm, *uv)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    if material: me.materials.append(material)
    if smooth:
        for p in me.polygons: p.use_smooth = True
    ob = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(ob)
    set_xform(ob, pos, rot, parent)
    return ob

def empty(name, parent=None, pos=(0, 0, 0), rot=(0, 0, 0)):
    ob = bpy.data.objects.new(name, None); bpy.context.collection.objects.link(ob)
    ob.empty_display_size = 0.1
    set_xform(ob, pos, rot, parent)
    return ob

def bm_box(w, h, d):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=(w, d, h), verts=bm.verts)   # game (w, h, d) -> Blender (x, y, z) = (w, d, h)
    return bm
def bm_cyl(rt, rb, h, seg=20, caps=True):
    bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=seg, radius1=rb, radius2=rt, depth=h)
    return bm
def bm_sphere(sx, sy, sz, seg=20, rings=14):
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1, calc_uvs=True)
    bmesh.ops.scale(bm, vec=(sx, sz, sy), verts=bm.verts)
    return bm
def bm_capsule(r, length, seg=14):
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=10, radius=r)
    for v in bm.verts:
        if v.co.z > 1e-5: v.co.z += length / 2
        elif v.co.z < -1e-5: v.co.z -= length / 2
    return bm
def bm_plane(w, h):
    """game plane in XY facing +Z"""
    bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=0.5)
    bmesh.ops.scale(bm, vec=(w, h, 1), verts=bm.verts)
    bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, 'X'), verts=bm.verts)
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for l in f.loops: l[uv].uv = (l.vert.co.x / w + 0.5, l.vert.co.z / h + 0.5)
    return bm
def bm_torus(R, r, seg=32, rseg=8):
    """torus around the game Z axis (in the game XY plane)"""
    bm = bmesh.new(); rows = []
    for i in range(seg):
        a = 2 * math.pi * i / seg; row = []
        for j in range(rseg):
            b = 2 * math.pi * j / rseg
            x = (R + r * math.cos(b)) * math.cos(a); y = (R + r * math.cos(b)) * math.sin(a); z = r * math.sin(b)
            row.append(bm.verts.new((x, -z, y)))
        rows.append(row)
    for i in range(seg):
        for j in range(rseg):
            a, b = rows[i][j], rows[(i + 1) % seg][j]; c, d = rows[(i + 1) % seg][(j + 1) % rseg], rows[i][(j + 1) % rseg]
            bm.faces.new((a, b, c, d))
    return bm

def box(w, h, d, m, x, y, z, parent=None, name='box', rot=(0, 0, 0), uv=None):
    return make(name, bm_box(w, h, d), m, parent, (x, y, z), rot, uv)
def cyl(rt, rb, h, m, x, y, z, parent=None, name='cyl', rot=(0, 0, 0), seg=20, caps=True):
    return make(name, bm_cyl(rt, rb, h, seg, caps), m, parent, (x, y, z), rot, smooth=True)
def sph(sx, sy, sz, m, x, y, z, parent=None, name='sphere', rot=(0, 0, 0), seg=20):
    return make(name, bm_sphere(sx, sy, sz, seg), m, parent, (x, y, z), rot, smooth=True)
def plane(w, h, m, x, y, z, parent=None, name='plane', rot=(0, 0, 0)):
    return make(name, bm_plane(w, h), m, parent, (x, y, z), rot)

def join_by_material(root_name):
    """merge all mesh objects that share a parent and material so props import as a few clean meshes"""
    groups = {}
    for ob in list(bpy.context.scene.objects):
        if ob.type != 'MESH' or ob.get('keep'): continue
        key = (ob.parent.name if ob.parent else '', ob.active_material.name if ob.active_material else '')
        groups.setdefault(key, []).append(ob)
    for (par, mname), obs in groups.items():
        if len(obs) < 2: continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in obs: o.select_set(True)
        bpy.context.view_layer.objects.active = obs[0]
        bpy.ops.object.join()
        obs[0].name = (mname or 'mesh')

def finish(name, join=True):
    root = bpy.data.objects.get(name)
    if join: join_by_material(name)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND, name + '.blend'))
    bpy.ops.export_scene.gltf(filepath=os.path.join(GLB, name + '.glb'), export_format='GLB', export_apply=True, export_yup=True)
    print('built', name)

MODELS = {}
def model(fn):
    MODELS[fn.__name__] = fn
    return fn

def begin(name):
    scene_reset()
    root = empty(name)
    return root, MATS()

# ---------------------------------------------------------------- mall pieces
@model
def wall():
    r, M = begin('wall')
    box(2, 4, 2, M['wall'], 0, 2, 0, r, 'wall', uv=(2, 4))
    finish('wall')

@model
def storefront_glass():
    r, M = begin('storefront_glass')
    box(2, 1, 0.4, M['header'], 0, 3.5, 0, r, 'header')
    plane(2, 2.75, M['glass'], 0, 1.675, 0, r, 'glass')
    box(2, 0.3, 0.12, M['metal'], 0, 0.15, 0, r, 'frame')
    box(0.06, 2.75, 0.1, M['metal'], 0.97, 1.67, 0, r, 'frame')
    finish('storefront_glass')

@model
def storefront_door():
    r, M = begin('storefront_door')
    box(2, 1, 0.4, M['header'], 0, 3.5, 0, r, 'header')
    finish('storefront_door')

@model
def ceiling_panel():
    r, M = begin('ceiling_panel')
    pm = mat('light_panel', (0.13, 0.13, 0.13), 0.5, emit=(0.91, 0.94, 1.0), emit_strength=0.0)
    plane(1.2, 0.6, pm, 0, -0.01, 0, r, 'panel', rot=(math.pi / 2, 0, 0))
    finish('ceiling_panel')

@model
def emergency_light():
    r, M = begin('emergency_light')
    box(0.25, 0.12, 0.12, M['emerg'], 0, 0, 0, r, 'emergency')
    finish('emergency_light')

@model
def gate_shutter():
    r, M = begin('gate_shutter')
    sm = mat('shutter', (1, 1, 1), 0.55, 0.7, tex='shutter')
    make('shutter', bm_plane(8, 4), sm, r, (0, 2, 0))
    me = r.children[0].data
    for l in me.uv_layers.active.data: l.uv = (l.uv[0] * 4, l.uv[1] * 2)
    finish('gate_shutter')

@model
def outside_view():
    r, M = begin('outside_view')
    om = mat('outside', (0, 0, 0), 1.0, tex='outside', emit_tex=True, emit_strength=1.0)
    plane(8, 4, om, 0, 2, 0, r, 'outside')
    finish('outside_view')

@model
def grille():
    r, M = begin('grille')
    for k in range(27): cyl(0.018, 0.018, 3, M['metal'], 0, 1.5, -2 + k * 0.154, r, 'bars', seg=6)
    for y in (0.4, 1.5, 2.6): cyl(0.025, 0.025, 4, M['metal'], 0, y, 0, r, 'bars', rot=(math.pi / 2, 0, 0), seg=6)
    pm = mat('poster_renovation', (1, 1, 1), 0.9, tex='poster_renovation')
    plane(1.8, 0.45, pm, -0.05, 1.4, 0, r, 'poster', rot=(0, -math.pi / 2, 0))
    finish('grille')

# ---------------------------------------------------------------- props (front faces +Z)
def shelf(name, fill):
    r, M = begin(name)
    box(1.8, 2.0, 0.45, M['dark'], 0, 1.0, -0.7, r)
    shelf_mat = M['wood'] if fill == 'books' else M['laminate']
    spines = mat('spines', (1, 1, 1), 0.85, tex='spines')
    for i in range(4):
        box(1.76, 0.03, 0.42, shelf_mat, 0, 0.25 + i * 0.5, -0.66, r)
        if fill == 'books': box(1.7, 0.3, 0.2, spines, 0, 0.42 + i * 0.5, -0.66, r)
        elif fill == 'heads':
            for k in (-1, 0, 1): sph(0.09, 0.12, 0.1, M['skin'], k * 0.55, 0.38 + i * 0.5, -0.66, r)
        else:
            for k in range(4):
                if rng.random() < 0.7:
                    c = mat(f'goods_{rng.randrange(6)}', tuple(0.15 + rng.random() * 0.35 for _ in range(3)), 0.8)
                    hh = 0.12 + rng.random() * 0.18
                    box(0.28, hh, 0.28, c, -0.6 + k * 0.4, 0.27 + i * 0.5 + hh / 2, -0.64, r)
    finish(name)
@model
def shelf_goods(): shelf('shelf_goods', 'boxes')
@model
def shelf_books(): shelf('shelf_books', 'books')
@model
def shelf_heads(): shelf('shelf_heads', 'heads')

@model
def clothes_rack():
    r, M = begin('clothes_rack')
    for x in (-0.7, 0.7): cyl(0.02, 0.02, 1.5, M['metal'], x, 0.75, 0, r)
    cyl(0.015, 0.015, 1.4, M['metal'], 0, 1.48, 0, r, rot=(0, 0, math.pi / 2))
    for k in range(7):
        if rng.random() < 0.75:
            c = mat(f'cloth_{rng.randrange(6)}', tuple(0.1 + rng.random() * 0.3 for _ in range(3)), 0.95)
            box(0.06, 0.7 + rng.random() * 0.2, 0.45, c, -0.6 + k * 0.2, 1.08, 0, r)
    finish('clothes_rack')

@model
def arcade_cabinet():
    r, M = begin('arcade_cabinet')
    box(0.8, 1.8, 0.8, mat('arcade_body', (0.25, 0.08, 0.3), 0.6), 0, 0.9, -0.5, r)
    sc = plane(0.6, 0.45, M['screen'], 0, 1.35, -0.09, r, 'screen', rot=(-0.2, 0, 0)); sc['keep'] = True
    finish('arcade_cabinet')

@model
def counter():
    r, M = begin('counter')
    box(1.9, 1.0, 0.7, M['wood'], 0, 0.5, -0.4, r); box(1.95, 0.04, 0.75, M['laminate'], 0, 1.02, -0.4, r)
    finish('counter')

@model
def food_counter():
    r, M = begin('food_counter')
    box(1.9, 1.0, 0.7, M['tile'], 0, 0.5, -0.4, r); box(1.95, 0.04, 0.75, M['laminate'], 0, 1.02, -0.4, r)
    finish('food_counter')

@model
def glass_case():
    r, M = begin('glass_case')
    box(1.6, 0.8, 0.6, M['dark'], 0, 0.4, -0.3, r); box(1.6, 0.3, 0.6, M['glass'], 0, 0.95, -0.3, r)
    finish('glass_case')

@model
def flower_buckets():
    r, M = begin('flower_buckets')
    for k in (-1, 0, 1):
        cyl(0.18, 0.15, 0.4, M['metal'], k * 0.55, 0.2, -0.4, r)
        for f in range(5): sph(0.06, 0.06, 0.06, M['plant'], k * 0.55 + rng.uniform(-0.1, 0.1), 0.6 + rng.random() * 0.3, -0.4 + rng.uniform(-0.1, 0.1), r, seg=8)
    finish('flower_buckets')

@model
def lockers():
    r, M = begin('lockers')
    lm = mat('locker', (0.29, 0.33, 0.38), 0.5, 0.6)
    for k in range(4): box(0.42, 1.9, 0.5, lm, -0.66 + k * 0.44, 0.95, -0.7, r)
    finish('lockers')

@model
def candy_bins():
    r, M = begin('candy_bins')
    for k in (-1, 0, 1):
        box(0.5, 0.8, 0.5, M['wood'], k * 0.6, 0.4, -0.5, r)
        box(0.46, 0.06, 0.46, mat(f'candy_{k}', (0.8, 0.3 + k * 0.2, 0.5), 0.5), k * 0.6, 0.82, -0.5, r)
    finish('candy_bins')

@model
def pipes():
    r, M = begin('pipes')
    for k in range(3): cyl(0.08, 0.08, 1.9, M['metal'], 0, 0.8 + k * 0.6, -0.85, r, rot=(0, 0, math.pi / 2))
    cyl(0.3, 0.3, 0.9, mat('tank', (0.17, 0.23, 0.35), 0.5, 0.4), 0.4, 0.45, -0.2, r)
    finish('pipes')

@model
def cafe_table():
    r, M = begin('cafe_table')
    box(1.0, 0.04, 1.0, M['laminate'], 0, 0.75, 0, r); cyl(0.05, 0.05, 0.75, M['metal'], 0, 0.37, 0, r)
    for a in (-0.6, 0.6): box(0.42, 0.04, 0.42, M['dark'], a, 0.45, 0, r)
    finish('cafe_table')

def table(name, top):
    r, M = begin(name)
    box(1.3, 0.9, 0.75, M[top], 0, 0.45, 0, r); box(1.36, 0.04, 0.8, M['laminate'], 0, 0.92, 0, r)
    return r, M
@model
def item_table():
    r, M = table('item_table', 'wood'); finish('item_table')
@model
def item_table_dark():
    r, M = table('item_table_dark', 'dark'); finish('item_table_dark')
@model
def security_desk():
    r, M = table('security_desk', 'laminate')
    for a in (-0.4, 0.35):
        box(0.42, 0.36, 0.4, M['dark'], a, 1.12, -0.15, r)
        s = plane(0.34, 0.27, M['screen'], a, 1.13, 0.051, r, 'screen'); s['keep'] = True
    finish('security_desk')

@model
def breaker_cabinet():
    r, M = begin('breaker_cabinet')
    box(1.4, 2.0, 0.5, mat('breaker', (0.31, 0.35, 0.29), 0.5, 0.6), 0, 1.0, -0.2, r)
    lm = mat('breaker_lights', (0.13, 0, 0), 0.4, emit=(1.0, 0.13, 0.06), emit_strength=1.5)
    for i in range(3):
        o = sph(0.04, 0.04, 0.04, lm, -0.35 + i * 0.35, 1.5, 0.06, r, f'light_{i}', seg=10); o['keep'] = True
    finish('breaker_cabinet')

@model
def pedestal():
    r, M = begin('pedestal')
    cyl(0.5, 0.55, 0.3, M['velvet'], 0, 0.15, 0, r); cyl(0.014, 0.014, 0.95, M['metal'], 0, 0.77, 0, r)
    finish('pedestal')

@model
def velvet_backdrop():
    r, M = begin('velvet_backdrop')
    box(0.1, 3.4, 8, M['velvet'], 0, 1.7, 0, r)
    finish('velvet_backdrop')

@model
def kiosk():
    r, M = begin('kiosk')
    box(1.7, 1.05, 1.7, M['wood'], 0, 0.52, 0, r); box(1.8, 0.05, 1.8, M['laminate'], 0, 1.07, 0, r)
    for a, b in ((-0.8, -0.8), (0.8, -0.8), (-0.8, 0.8), (0.8, 0.8)): cyl(0.03, 0.03, 1.3, M['metal'], a, 1.7, b, r)
    box(1.9, 0.08, 1.9, M['dark'], 0, 2.38, 0, r)
    finish('kiosk')

@model
def bench():
    r, M = begin('bench')
    box(1.8, 0.08, 0.5, M['wood'], 0, 0.45, 0, r); box(1.8, 0.45, 0.06, M['wood'], 0, 0.75, -0.25, r)
    for a in (-0.8, 0.8): box(0.06, 0.45, 0.45, M['metal'], a, 0.22, 0, r)
    finish('bench')

@model
def planter():
    r, M = begin('planter')
    cyl(0.55, 0.45, 0.7, M['tile'], 0, 0.35, 0, r)
    for i in range(6): cyl(0.015, 0.02, 1.2, M['plant'], rng.uniform(-0.2, 0.2), 1.2, rng.uniform(-0.2, 0.2), r, rot=(rng.uniform(-0.4, 0.4), 0, rng.uniform(-0.4, 0.4)), seg=6)
    finish('planter')

@model
def display_platform():
    r, M = begin('display_platform')
    cyl(0.75, 0.8, 0.25, M['dark'], 0, 0.125, 0, r)
    finish('display_platform')

@model
def trash_bin():
    r, M = begin('trash_bin')
    cyl(0.3, 0.26, 0.9, M['metal'], 0, 0.45, 0, r)
    finish('trash_bin')

@model
def directory_board():
    r, M = begin('directory_board')
    box(0.9, 1.8, 0.12, M['dark'], 0, 1.2, 0, r)
    finish('directory_board')

@model
def fountain():
    r, M = begin('fountain')
    make('ring', bm_cyl(3.8, 3.9, 0.6, 48, caps=False), M['tile'], r, (0, 0.3, 0), smooth=True)
    make('rim', bm_torus(3.85, 0.12, 48), M['laminate'], r, (0, 0.6, 0), (math.pi / 2, 0, 0), smooth=True)
    bm = bmesh.new(); bmesh.ops.create_circle(bm, cap_ends=True, segments=48, radius=3.8)
    make('water', bm, M['water'], r, (0, 0.42, 0))
    cyl(0.5, 0.7, 1.4, M['tile'], 0, 0.7, 0, r); cyl(1.4, 1.2, 0.12, M['tile'], 0, 1.45, 0, r)
    cyl(0.2, 0.3, 0.9, M['tile'], 0, 1.9, 0, r); cyl(0.7, 0.6, 0.1, M['tile'], 0, 2.35, 0, r)
    coin = mat('coin', (0.79, 0.64, 0.23), 0.3, 1.0)
    for k in range(40):
        a, rr = rng.uniform(0, 6.28), rng.uniform(1.0, 3.5)
        cyl(0.03, 0.03, 0.004, coin, math.cos(a) * rr, 0.43, math.sin(a) * rr, r, seg=8)
    finish('fountain')

@model
def payphone():
    r, M = begin('payphone')
    box(0.5, 0.75, 0.25, M['metal'], 0, 1.35, 0, r); box(0.06, 0.22, 0.08, M['dark'], -0.18, 1.45, 0.15, r)
    box(0.62, 0.05, 0.4, M['metal'], 0, 1.0, 0.1, r); box(0.6, 0.1, 0.3, mat('bell_blue', (0.1, 0.23, 0.48), 0.5), 0, 1.9, 0.02, r)
    finish('payphone')

def vending(name, color):
    r, M = begin(name)
    box(1.0, 1.9, 0.8, mat('vending_body', color, 0.4, 0.3), 0, 0.95, 0, r)
    vm = mat('vending_glow', (0.07, 0.07, 0.07), 0.3, emit=(0.96, 0.94, 1.0), emit_strength=0.05)
    p = plane(0.6, 1.2, vm, -0.12, 1.15, 0.41, r, 'glow'); p['keep'] = True
    for row in range(4):
        for k in range(4): box(0.1, 0.16, 0.05, mat(f'can_{(row + k) % 5}', (rng.random(), rng.random(), rng.random()), 0.5), -0.34 + k * 0.15, 0.7 + row * 0.28, 0.37, r)
    finish(name)
@model
def vending_red(): vending('vending_red', (0.54, 0.1, 0.1))
@model
def vending_blue(): vending('vending_blue', (0.1, 0.23, 0.54))

@model
def kiddie_ride():
    r, M = begin('kiddie_ride')
    pink, teal = mat('pink', (0.91, 0.66, 0.77), 0.3), mat('teal', (0.25, 0.75, 0.69), 0.4)
    box(1.1, 0.25, 0.8, teal, 0, 0.125, 0, r)
    sph(0.45, 0.22, 0.2, pink, 0, 0.85, 0, r); sph(0.16, 0.12, 0.1, pink, 0.48, 1.18, 0, r, rot=(0, 0, -0.6))
    for a, b in ((0.28, 0.12), (0.28, -0.12), (-0.28, 0.12), (-0.28, -0.12)): cyl(0.04, 0.035, 0.6, pink, a, 0.5, b, r)
    cyl(0.03, 0.03, 0.6, M['metal'], 0, 0.45, 0, r); box(0.25, 0.4, 0.2, M['dark'], -0.45, 0.45, 0.32, r)
    finish('kiddie_ride')

@model
def play_slide():
    r, M = begin('play_slide')
    yel, red = mat('yellow', (0.85, 0.71, 0.16), 0.45), mat('red', (0.66, 0.16, 0.14), 0.45)
    box(0.8, 0.08, 0.8, red, -0.4, 1.1, 0, r)
    for a, b in ((-0.75, -0.35), (-0.75, 0.35), (-0.05, -0.35), (-0.05, 0.35)): cyl(0.04, 0.04, 1.1, M['metal'], a, 0.55, b, r)
    box(1.5, 0.05, 0.55, yel, 0.6, 0.6, 0, r, rot=(0, 0, -0.65))
    for k in range(4): box(0.05, 0.05, 0.6, M['metal'], -0.8, 0.25 + k * 0.25, 0, r)
    for k in range(14): sph(0.08, 0.08, 0.08, mat(f'ball_{k % 5}', (rng.random(), rng.random(), rng.random()), 0.4), rng.uniform(-1.2, 1.2), 0.08, rng.uniform(-1.2, 1.2), r, seg=10)
    finish('play_slide')

@model
def christmas_tree():
    r, M = begin('christmas_tree')
    cyl(0.25, 0.3, 0.4, M['wood'], 0, 0.2, 0, r)
    tm = mat('dead_pine', (0.17, 0.2, 0.13), 1.0)
    for k in range(4): make('tree', bm_cyl(0, 0.9 - k * 0.18, 0.8, 10), tm, r, (0, 0.75 + k * 0.45, 0))
    bulb = mat('tree_bulbs', (0.13, 0, 0), 0.4, emit=(1.0, 0.19, 0.12), emit_strength=1.5)
    for k in range(22):
        a, h = k * 1.3, 0.6 + k * 0.08; rr = 0.85 - h * 0.33
        sph(0.03, 0.03, 0.03, bulb, math.cos(a) * rr, h, math.sin(a) * rr, r, 'bulbs', seg=8)
    finish('christmas_tree')

@model
def stroller():
    r, M = begin('stroller')
    n = M['navy']
    box(0.45, 0.35, 0.75, n, 0, 0.55, 0, r); box(0.45, 0.35, 0.05, n, 0, 0.8, -0.35, r, rot=(-0.5, 0, 0))
    for a, b in ((0.22, 0.3), (-0.22, 0.3), (0.22, -0.3), (-0.22, -0.3)): make('wheel', bm_torus(0.09, 0.02, 16, 6), M['dark'], r, (a, 0.1, b), (0, math.pi / 2, 0))
    cyl(0.015, 0.015, 0.45, M['metal'], 0, 1.0, -0.5, r, rot=(0, 0, math.pi / 2))
    finish('stroller')

@model
def wet_floor_sign():
    r, M = begin('wet_floor_sign')
    make('sign', bm_cyl(0, 0.3, 0.7, 4), mat('wet_yellow', (0.85, 0.72, 0.13), 0.5), r, (0, 0.35, 0))
    finish('wet_floor_sign')

@model
def pumpkin():
    r, M = begin('pumpkin')
    pm = mat('pumpkin', (1, 1, 1), 0.7, tex='pumpkin')
    nt = pm.node_tree; b = nt.nodes['Principled BSDF']
    g = nt.nodes.new('ShaderNodeTexImage'); g.image = bpy.data.images.load(os.path.join(TEX, 'pumpkin_glow.png'), check_existing=True)
    nt.links.new(g.outputs['Color'], b.inputs['Emission Color']); b.inputs['Emission Strength'].default_value = 1.0
    sph(0.26, 0.21, 0.26, pm, 0, 0.2, 0, r, 'pumpkin', rot=(0, -math.pi / 2, 0))
    cyl(0.02, 0.03, 0.08, M['plant'], 0, 0.43, 0, r)
    finish('pumpkin')

@model
def security_camera():
    r, M = begin('security_camera')
    cyl(0.03, 0.03, 0.25, M['metal'], 0, 0.12, 0, r)
    head = empty('head', r)
    b = box(0.16, 0.14, 0.34, mat('camera_body', (0.85, 0.83, 0.8), 0.5), 0, 0, 0, head, 'body'); b['keep'] = True
    led = sph(0.015, 0.015, 0.015, mat('camera_led', (0.13, 0, 0), 0.4, emit=(1, 0, 0), emit_strength=2), 0.05, 0.05, 0.17, head, 'led', seg=8); led['keep'] = True
    finish('security_camera')

def booth(name, curtain):
    r, M = begin(name)
    box(1.6, 2.3, 0.06, M['laminate'], 0, 1.15, -0.75, r)
    for sx in (-0.78, 0.78): box(0.06, 2.3, 1.5, M['laminate'], sx, 1.15, 0, r)
    box(1.6, 0.06, 1.5, M['laminate'], 0, 2.3, 0, r)
    for sx in (-0.45, 0.45): box(0.62, 2.1, 0.03, M[curtain], sx, 1.1, 0.74, r)
    finish(name)
@model
def fitting_booth(): booth('fitting_booth', 'velvet')
@model
def supply_closet(): booth('supply_closet', 'dark')

@model
def escalator():
    """dead escalator; foot at the origin, rising 4.35 m toward -X over 7.8 m, chained off at the foot"""
    r, M = begin('escalator')
    ln, rise = 7.8, 4.35; slope, ang = math.hypot(ln, rise), math.atan2(rise, ln)
    g = empty('run', r, (-ln / 2, rise / 2, 0), (0, 0, -ang))
    steps = mat('escalator_steps', (1, 1, 1), 0.5, 0.6, tex='escalator_steps')
    s = box(slope, 0.25, 1.1, steps, 0, 0, 0, g, 'steps')
    box(slope, 0.6, 1.05, M['dark'], 0, -0.42, 0, g)
    for sz in (-0.62, 0.62):
        box(slope, 0.9, 0.1, M['laminate'], 0, 0.55, sz, g)
        cyl(0.05, 0.05, slope + 0.6, M['dark'], 0, 1.03, sz, g, rot=(0, 0, math.pi / 2))
    for sz in (-0.7, 0.7): cyl(0.03, 0.05, 1.0, M['metal'], 0.7, 0.5, sz, r)
    for k in range(8): make('chain', bm_torus(0.05, 0.012, 10, 6), M['metal'], r, (0.7, 0.8 - math.sin(k / 7 * math.pi) * 0.12, -0.7 + k * 0.2), (0, (math.pi / 2) if k % 2 else 0, 0))
    om = mat('out_of_order', (1, 1, 1), 0.6, tex='out_of_order')
    plane(0.7, 0.26, om, 0.72, 0.62, 0, r, 'sign', rot=(0, math.pi / 2, 0))
    finish('escalator')

# ---------------------------------------------------------------- small items & decals
@model
def fuse():
    r, M = begin('fuse')
    glow = mat('fuse_glow', (0.33, 0.2, 0), 0.2, emit=(1.0, 0.63, 0.19), emit_strength=1.2)
    cyl(0.035, 0.035, 0.16, glow, 0, 0.04, 0, r, 'glow', rot=(0, 0, math.pi / 2), seg=12)
    for sx in (-1, 1): cyl(0.04, 0.04, 0.04, M['metal'], sx * 0.09, 0.04, 0, r, rot=(0, 0, math.pi / 2), seg=12)
    finish('fuse')

@model
def battery():
    r, M = begin('battery')
    cyl(0.03, 0.03, 0.13, mat('battery_body', (0.1, 0.1, 0.1), 0.4, 0.5), 0, 0.03, 0, r, rot=(0, 0, math.pi / 2), seg=12)
    cyl(0.031, 0.031, 0.04, mat('battery_band', (0.07, 0.2, 0), 0.4, emit=(0.38, 1.0, 0.25), emit_strength=0.9), 0, 0.03, 0, r, rot=(0, 0, math.pi / 2), seg=12)
    finish('battery')

@model
def note_paper():
    r, M = begin('note_paper')
    nm = mat('note', (1, 1, 1), 0.9, tex='paper', emit=(1.0, 0.95, 0.8), emit_strength=0.12)
    plane(0.28, 0.36, nm, 0, 0.006, 0, r, 'note', rot=(-math.pi / 2, 0, 0))
    finish('note_paper')

@model
def puddle():
    r, M = begin('puddle')
    bm = bmesh.new(); bmesh.ops.create_circle(bm, cap_ends=True, segments=24, radius=1)
    make('puddle', bm, mat('puddle', (0.04, 0.05, 0.055), 0.02, 0.6), r, (0, 0.008, 0))
    finish('puddle')

@model
def glass_shards():
    r, M = begin('glass_shards')
    sm = mat('shards', (0.72, 0.82, 0.85), 0.05, 0.8, alpha=0.5)
    for k in range(18):
        bm = bmesh.new(); bmesh.ops.create_circle(bm, cap_ends=True, segments=3, radius=0.06 * rng.uniform(0.5, 2))
        make('shard', bm, sm, r, (rng.uniform(-0.9, 0.9), 0.006, rng.uniform(-0.7, 0.7)), (0, rng.uniform(0, 6.28), 0))
    finish('glass_shards')

def decal(name, tex, w, h, alpha=1.0):
    r, M = begin(name)
    plane(w, h, mat(name, (1, 1, 1), 0.7, tex=tex, alpha=alpha), 0, 0, 0, r, name)
    finish(name)
@model
def hands_decal(): decal('hands_decal', 'hands', 0.95, 0.95, 0.99)
@model
def banner_sale(): decal('banner_sale', 'banner_sale', 5, 1.25)
@model
def poster_closing(): decal('poster_closing', 'poster_closing', 1.3, 0.33)

# ---------------------------------------------------------------- the jointed mannequin
@model
def mannequin():
    """A display figure with named joints (hips, spine, neck, head, lS/lE/lH/lK, rS/rE/rH/rK) that the game poses.
    Optional parts the game toggles: dress, uniform, stand."""
    r, M = begin('mannequin')
    skin, sock = M['skin'], M['socket']
    hips = empty('hips', r, (0, 0.95, 0))
    sph(0.17, 0.12, 0.11, skin, 0, 0, 0, hips, 'pelvis')
    spine = empty('spine', hips, (0, 0.06, 0))
    make('torso', bm_capsule(0.15, 0.32), skin, spine, (0, 0.24, 0), smooth=True).scale = (1.05, 0.68, 1)
    sph(0.19, 0.11, 0.115, skin, 0, 0.42, 0.01, spine, 'chest')
    neck = empty('neck', spine, (0, 0.55, 0))
    cyl(0.04, 0.048, 0.12, skin, 0, 0.05, 0, neck, 'neck_mesh', seg=12)
    head = empty('head', neck, (0, 0.1, 0))
    sph(0.095, 0.125, 0.11, skin, 0, 0.1, 0.005, head, 'skull')
    for sx in (0.034, -0.034): sph(0.022, 0.012, 0.02, sock, sx, 0.115, 0.088, head, 'socket', seg=10)
    sph(0.012, 0.025, 0.014, skin, 0, 0.085, 0.105, head, 'nose', seg=8)
    for side, k in ((1, 'l'), (-1, 'r')):
        sh = empty(k + 'S', spine, (0.2 * side, 0.46, 0))
        sph(0.055, 0.055, 0.055, skin, 0, 0, 0, sh, 'shoulder', seg=12)
        make('upper_arm', bm_capsule(0.045, 0.24), skin, sh, (0, -0.16, 0), smooth=True)
        el = empty(k + 'E', sh, (0, -0.31, 0))
        make('forearm', bm_capsule(0.038, 0.22), skin, el, (0, -0.14, 0), smooth=True)
        sph(0.035, 0.07, 0.02, skin, 0, -0.31, 0.01, el, 'hand', seg=10)
        hip = empty(k + 'H', hips, (0.09 * side, -0.04, 0))
        make('thigh', bm_capsule(0.068, 0.34), skin, hip, (0, -0.22, 0), smooth=True)
        kn = empty(k + 'K', hip, (0, -0.45, 0))
        make('shin', bm_capsule(0.05, 0.34), skin, kn, (0, -0.22, 0), smooth=True)
        sph(0.045, 0.03, 0.11, skin, 0, -0.45, 0.05, kn, 'foot', seg=10)
    # optional clothing (hidden/shown and recoloured by the game)
    dm = mat('dress', (0.36, 0.04, 0.07), 0.92)
    dress = empty('dress', hips)
    make('skirt', bm_cyl(0.17, 0.34, 0.72, 18, caps=False), dm, dress, (0, -0.3, 0), smooth=True)
    make('bodice', bm_cyl(0.16, 0.175, 0.42, 18), dm, spine, (0, 0.22, 0), smooth=True)
    bpy.data.objects['bodice'].scale = (1.08, 0.72, 1.0)
    bpy.data.objects['bodice'].parent = dress; bpy.data.objects['bodice'].matrix_parent_inverse = Matrix.Identity(4)
    set_xform(bpy.data.objects['bodice'], (0, 0.28, 0), parent=dress)
    uni = empty('uniform', spine)
    make('shirt', bm_cyl(0.16, 0.175, 0.42, 18), M['navy'], uni, (0, 0.22, 0), smooth=True)
    bpy.data.objects['shirt'].scale = (1.12, 0.78, 1.05)
    cap = empty('cap', head)
    cyl(0.1, 0.11, 0.07, M['navy'], 0, 0.21, 0.01, cap, 'cap_mesh', seg=16)
    box(0.16, 0.012, 0.08, M['navy'], 0, 0.18, 0.11, cap, 'bill')
    box(0.04, 0.05, 0.01, mat('badge', (0.79, 0.64, 0.23), 0.3, 1.0), 0.08, 0.32, 0.12, uni, 'badge')
    stand = empty('stand', r)
    cyl(0.014, 0.014, 0.95, M['metal'], 0, 0.47, -0.06, stand, 'rod', seg=8)
    cyl(0.22, 0.24, 0.03, M['metal'], 0, 0.015, -0.06, stand, 'base', seg=24)
    finish('mannequin', join=False)

# ---------------------------------------------------------------- the second floor (absolute coordinates)
@model
def upper_level():
    r, M = begin('upper_level')
    hx0, hx1, hz0, hz1, ox0, ox1, oz0, oz1, FL, TOP = 26, 62, 24, 40, 22, 66, 20, 44, 4.35, 8.6
    fl = mat('balcony_floor', (1, 1, 1), 0.5, tex='floor')
    ce = mat('upper_ceiling', (1, 1, 1), 1.0, tex='ceiling')
    def slab(x0, x1, z0, z1, m, y, down=False):
        o = plane(x1 - x0, z1 - z0, m, (x0 + x1) / 2, y, (z0 + z1) / 2, r, 'slab', rot=((math.pi / 2) if down else (-math.pi / 2), 0, 0))
        for l in o.data.uv_layers.active.data: l.uv = (l.uv[0] * (x1 - x0) / 2, l.uv[1] * (z1 - z0) / 2)
    for (x0, x1, z0, z1) in ((ox0, ox1, oz0, hz0), (ox0, ox1, hz1, oz1), (ox0, hx0, hz0, hz1), (hx1, ox1, hz0, hz1)):
        slab(x0, x1, z0, z1, fl, FL); slab(x0, x1, z0, z1, ce, TOP, down=True)
    neon = mat('balcony_neon', (0.07, 0.07, 0.07), 0.5, emit=(0.16, 0.9, 0.83), emit_strength=0.1)
    rail = mat('rail_glass', (0.62, 0.7, 0.74), 0.05, 0.5, alpha=0.18)
    for (x0, z0, x1, z1) in ((hx0, hz0, hx1, hz0), (hx0, hz1, hx1, hz1), (hx0, hz0, hx0, hz1), (hx1, hz0, hx1, hz1)):
        ln = math.hypot(x1 - x0, z1 - z0); mx, mz = (x0 + x1) / 2, (z0 + z1) / 2; along_x = z0 == z1
        box(ln + 0.3 if along_x else 0.3, 0.5, 0.3 if along_x else ln + 0.3, M['laminate'], mx, FL - 0.2, mz, r, 'fascia')
        cyl(0.025, 0.025, ln, neon, mx, FL - 0.42, mz, r, 'neon', rot=(0 if along_x else math.pi / 2, 0, math.pi / 2 if along_x else 0), seg=8)
        plane(ln, 1.0, rail, mx, FL + 0.55, mz, r, 'railing_glass', rot=(0, 0 if along_x else math.pi / 2, 0))
        cyl(0.03, 0.03, ln, M['metal'], mx, FL + 1.08, mz, r, 'rail', rot=(0 if along_x else math.pi / 2, 0, math.pi / 2 if along_x else 0), seg=10)
        k = 0.0
        while k <= ln:
            cyl(0.025, 0.025, 1.08, M['metal'], x0 + k if along_x else mx, FL + 0.54, mz if along_x else z0 + k, r, 'post', seg=8); k += 3
    hole = mat('dead_shop', (0.0, 0.0, 0.0), 1.0)
    wm = mat('upper_wall', (0.72, 0.68, 0.61), 0.9, tex='wall')
    for (x0, z0, x1, z1, nx, nz) in ((ox0, oz0, ox1, oz0, 0, 1), (ox0, oz1, ox1, oz1, 0, -1), (ox0, oz0, ox0, oz1, 1, 0), (ox1, oz0, ox1, oz1, -1, 0)):
        ln = math.hypot(x1 - x0, z1 - z0); mx, mz = (x0 + x1) / 2, (z0 + z1) / 2; along_x = z0 == z1
        box(ln if along_x else 0.4, TOP - FL, 0.4 if along_x else ln, wm, mx, (FL + TOP) / 2, mz, r, 'facade', uv=(2.5, 4))
        k = 3.5
        while k < ln - 2:
            px = x0 + k if along_x else mx + nx * 0.22; pz = mz + nz * 0.22 if along_x else z0 + k
            plane(4, 2.9, hole, px, FL + 1.45, pz, r, 'shop_opening', rot=(0, math.atan2(nx, nz), 0)); k += 7.5
    sk = mat('skylight', (0, 0, 0), 1.0, tex='skylight', emit_tex=True, emit_strength=0.45)
    plane(hx1 - hx0, hz1 - hz0, sk, (hx0 + hx1) / 2, TOP - 0.01, (hz0 + hz1) / 2, r, 'skylight', rot=(math.pi / 2, 0, 0))
    finish('upper_level')

if __name__ == '__main__':
    import sys
    only = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    for name, fn in MODELS.items():
        if only and name not in only: continue
        fn()
    print('DONE', len(MODELS), 'models')
