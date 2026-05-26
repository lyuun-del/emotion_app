import math
import random
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "models" / "high_fidelity_island.glb"


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def material(name, color, roughness=0.78, metallic=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Alpha"].default_value = alpha
    if alpha < 1.0:
        mat.blend_method = "BLEND"
        mat.use_screen_refraction = True
        mat.show_transparent_back = True
    return mat


MAT = {}


def make_materials():
    MAT.update(
        grass=material("soft lime grass", (0.58, 0.82, 0.26, 1)),
        grass_dark=material("darker moss patches", (0.28, 0.56, 0.24, 1)),
        cliff=material("faceted gray beige rock", (0.58, 0.57, 0.52, 1)),
        cliff_light=material("sunlit cliff facets", (0.76, 0.71, 0.62, 1)),
        water=material("transparent turquoise water", (0.04, 0.78, 0.86, 0.58), 0.18, alpha=0.58),
        foam=material("soft shoreline foam", (0.96, 1.0, 0.96, 0.86), 0.45, alpha=0.86),
        path=material("pale curved stone path", (0.78, 0.72, 0.59, 1)),
        wall=material("warm cream cottage wall", (0.82, 0.72, 0.58, 1)),
        wall_blue=material("sage blue cottage wall", (0.46, 0.62, 0.60, 1)),
        roof=material("terracotta roof", (0.92, 0.35, 0.11, 1), 0.66),
        roof_gold=material("golden roof accent", (0.96, 0.62, 0.22, 1), 0.62),
        wood=material("dark timber", (0.29, 0.18, 0.10, 1)),
        window=material("warm glowing window", (1.0, 0.78, 0.32, 1), 0.35),
        leaf=material("rounded green foliage", (0.27, 0.55, 0.25, 1)),
        leaf_mint=material("mint teal foliage", (0.22, 0.64, 0.55, 1)),
        leaf_gold=material("golden foliage", (0.72, 0.60, 0.24, 1)),
        trunk=material("tree trunk", (0.34, 0.22, 0.12, 1)),
        link=material("clickable warm main house", (0.98, 0.70, 0.32, 1), 0.45),
    )


def terrain_height(x, z):
    rx, rz = 2.42, 1.78
    r = max(
        0,
        (x / rx) ** 2
        + (z / rz) ** 2
        - 0.06 * math.sin(3.0 * x + 1.1) * math.cos(4.0 * z),
    )
    plateau = max(0, 1 - r**1.42) * 0.32
    hill = 1.02 * math.exp(-((x + 0.46) ** 2 / 0.54 + (z + 0.66) ** 2 / 0.42))
    back = 0.34 * math.exp(-((x + 0.98) ** 2 / 0.82 + (z + 0.18) ** 2 / 0.72))
    shelf = 0.18 * math.exp(-((x - 1.10) ** 2 / 0.72 + (z - 0.12) ** 2 / 0.42))
    front_lagoon_cut = 0.22 * math.exp(-((x - 0.78) ** 2 / 0.45 + (z - 0.72) ** 2 / 0.22))
    shore = max(0, r - 0.76) * 0.38
    detail = 0.018 * math.sin(9 * x) * math.cos(8 * z)
    return plateau + hill + back + shelf - front_lagoon_cut - shore + detail


def add_bevel(obj, amount=0.025, segments=1):
    mod = obj.modifiers.new("soft bevels", "BEVEL")
    mod.width = amount
    mod.segments = segments
    mod.affect = "EDGES"
    obj.modifiers.new("weighted normals", "WEIGHTED_NORMAL")


def create_terrain():
    n = 118
    rx, rz = 2.42, 1.78
    verts = []
    faces = []
    for j in range(n + 1):
        z = (j / n - 0.5) * 2 * rz
        for i in range(n + 1):
            x = (i / n - 0.5) * 2 * rx
            verts.append((x, terrain_height(x, z), z))
    for j in range(n):
        for i in range(n):
            a = j * (n + 1) + i
            faces.append((a, a + n + 1, a + 1))
            faces.append((a + 1, a + n + 1, a + n + 2))
    mesh = bpy.data.meshes.new("high resolution rounded island grass mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("high resolution rounded island grass", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(MAT["grass"])
    obj.modifiers.new("smooth island normals", "WEIGHTED_NORMAL")
    return obj


def create_cliffs():
    rx, rz = 2.42, 1.78
    for k in range(76):
        a1 = 2 * math.pi * k / 76
        a2 = 2 * math.pi * (k + 1) / 76
        mid = (a1 + a2) * 0.5
        top_mid = (
            math.cos(mid) * rx * 0.80,
            terrain_height(math.cos(mid) * rx * 0.80, math.sin(mid) * rz * 0.80) - 0.02,
            math.sin(mid) * rz * 0.80,
        )
        p1 = (
            math.cos(a1) * rx * 0.98,
            terrain_height(math.cos(a1) * rx * 0.91, math.sin(a1) * rz * 0.91) - 0.08,
            math.sin(a1) * rz * 0.98,
        )
        p2 = (
            math.cos(a2) * rx * 0.98,
            terrain_height(math.cos(a2) * rx * 0.91, math.sin(a2) * rz * 0.91) - 0.08,
            math.sin(a2) * rz * 0.98,
        )
        low1 = (p1[0] * 0.95, p1[1] - 0.46 - 0.08 * math.sin(k), p1[2] * 0.95)
        low2 = (p2[0] * 0.95, p2[1] - 0.42 - 0.08 * math.cos(k), p2[2] * 0.95)
        mesh = bpy.data.meshes.new("shore cliff facet mesh")
        mesh.from_pydata([top_mid, p1, low1, low2, p2], [], [(0, 1, 2), (0, 2, 3), (0, 3, 4)])
        mesh.update()
        obj = bpy.data.objects.new("faceted shoreline cliff", mesh)
        bpy.context.collection.objects.link(obj)
        obj.data.materials.append(MAT["cliff_light" if k % 4 == 0 else "cliff"])
        obj.modifiers.new("weighted cliff normals", "WEIGHTED_NORMAL")


def add_cube(name, loc, scale, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    add_bevel(obj, min(scale) * 0.08, 1)
    return obj


def add_roof(name, x, y, z, sx, sy, sz, mat):
    verts = [
        (-sx, -sy, -sz),
        (sx, -sy, -sz),
        (sx, -sy, sz),
        (-sx, -sy, sz),
        (0, sy, -sz * 1.13),
        (0, sy, sz * 1.13),
    ]
    faces = [(0, 1, 4), (3, 5, 2), (0, 4, 5, 3), (1, 2, 5, 4), (0, 3, 2, 1)]
    mesh = bpy.data.meshes.new(name + " mesh")
    mesh.from_pydata([(x + a, y + b, z + c) for a, b, c in verts], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    add_bevel(obj, 0.018, 1)
    return obj


def add_house(name, x, z, w, d, h, main=False, tower=False):
    y = terrain_height(x, z) + 0.08
    add_cube(name + " body", (x, y + h, z), (w * 2, h * 2, d * 2), MAT["link" if main else ("wall_blue" if name.endswith("blue") else "wall")])
    add_roof(name + " terracotta roof", x, y + h * 2.2, z, w * 1.26, h * 0.90, d * 1.28, MAT["roof_gold" if main else "roof"])
    add_cube(name + " door", (x + w * 0.35, y + h * 0.58, z + d + 0.012), (w * 0.26, h * 0.72, 0.018), MAT["wood"])
    add_cube(name + " warm front window", (x - w * 0.45, y + h * 1.05, z + d + 0.014), (w * 0.22, h * 0.28, 0.016), MAT["window"])
    add_cube(name + " side window", (x + w + 0.014, y + h * 1.05, z - d * 0.20), (0.016, h * 0.25, d * 0.25), MAT["window"])
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=w * 0.08, depth=h * 0.68, location=(x + w * 0.62, y + h * 2.45, z - d * 0.35))
    chimney = bpy.context.object
    chimney.name = name + " chimney"
    chimney.data.materials.append(MAT["cliff"])
    add_bevel(chimney, 0.01, 1)
    if tower:
        add_cube(name + " upper tower", (x + w * 0.18, y + h * 2.85, z - d * 0.10), (w * 0.86, h * 1.05, d * 0.78), MAT["wall"])
        add_roof(name + " upper tower roof", x + w * 0.18, y + h * 3.55, z - d * 0.10, w * 0.58, h * 0.60, d * 0.56, MAT["roof"])


def add_round_main_building(name, x, z):
    y = terrain_height(x, z) + 0.08
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=0.34, depth=0.42, location=(x, y + 0.21, z))
    body = bpy.context.object
    body.name = name + " round cream body"
    body.data.materials.append(MAT["link"])
    add_bevel(body, 0.018, 1)
    bpy.ops.mesh.primitive_cone_add(vertices=40, radius1=0.44, radius2=0.08, depth=0.34, location=(x, y + 0.58, z))
    roof = bpy.context.object
    roof.name = name + " red conical roof"
    roof.data.materials.append(MAT["roof"])
    add_bevel(roof, 0.012, 1)
    add_cube(name + " front stair platform", (x + 0.32, y + 0.05, z + 0.38), (0.30, 0.035, 0.16), MAT["path"])
    for i in range(5):
        add_cube(name + " front small stair", (x + 0.52 + i * 0.055, y - 0.03 + i * 0.018, z + 0.45 + i * 0.06), (0.12, 0.014, 0.045), MAT["path"])
    for dx, dz in [(-0.20, 0.34), (0.18, 0.34), (-0.31, 0.02), (0.31, 0.02)]:
        add_cube(name + " warm arched window", (x + dx, y + 0.28, z + dz), (0.06, 0.10, 0.012), MAT["window"])


def add_lighthouse(name, x, z):
    y = terrain_height(x, z) + 0.06
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.16, depth=0.48, location=(x, y + 0.24, z))
    tower = bpy.context.object
    tower.name = name + " pale round tower"
    tower.data.materials.append(MAT["wall"])
    add_bevel(tower, 0.012, 1)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.20, depth=0.08, location=(x, y + 0.52, z))
    cap = bpy.context.object
    cap.name = name + " stone tower cap"
    cap.data.materials.append(MAT["cliff"])
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=0.18, radius2=0.05, depth=0.18, location=(x, y + 0.65, z))
    roof_obj = bpy.context.object
    roof_obj.name = name + " small terracotta cap roof"
    roof_obj.data.materials.append(MAT["roof"])


def add_flat_water_ellipse(name, x, z, sx, sz, y_offset=0.035):
    y = terrain_height(x, z) + y_offset
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=1, depth=0.012, location=(x, y, z))
    obj = bpy.context.object
    obj.name = name
    obj.scale = (sx, sz, 1)
    obj.data.materials.append(MAT["water"])


def make_ribbon(name, points, width, mat, height_offset=0.045):
    verts = []
    faces = []
    for i, (x, z) in enumerate(points):
        y = terrain_height(x, z) + height_offset
        if i < len(points) - 1:
            dx = points[i + 1][0] - x
            dz = points[i + 1][1] - z
        else:
            dx = x - points[i - 1][0]
            dz = z - points[i - 1][1]
        length = math.hypot(dx, dz) or 1
        nx, nz = -dz / length, dx / length
        verts.append((x + nx * width, y, z + nz * width))
        verts.append((x - nx * width, y, z - nz * width))
    for i in range(len(points) - 1):
        a = i * 2
        faces.append((a, a + 1, a + 2))
        faces.append((a + 1, a + 3, a + 2))
    mesh = bpy.data.meshes.new(name + " mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    obj.modifiers.new("ribbon normals", "WEIGHTED_NORMAL")
    return obj


def add_tree(x, z, scale=1.0, foliage="leaf"):
    y = terrain_height(x, z) + 0.05
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.032 * scale, depth=0.34 * scale, location=(x, y + 0.17 * scale, z))
    trunk = bpy.context.object
    trunk.name = "slim tree trunk"
    trunk.data.materials.append(MAT["trunk"])
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.18 * scale, location=(x, y + 0.40 * scale, z))
    crown = bpy.context.object
    crown.name = "rounded stylized tree crown"
    crown.scale.z = 0.95
    crown.data.materials.append(MAT[foliage])
    crown.modifiers.new("soft crown normals", "WEIGHTED_NORMAL")
    for dx, dz, s in [(-0.09, 0.02, 0.70), (0.08, -0.04, 0.66), (0.03, 0.09, 0.55)]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=0.15 * scale * s, location=(x + dx * scale, y + 0.39 * scale, z + dz * scale))
        clump = bpy.context.object
        clump.name = "small tree crown clump"
        clump.data.materials.append(MAT[foliage])


def add_water_and_foam():
    bpy.ops.mesh.primitive_cylinder_add(vertices=128, radius=1, depth=0.01, location=(0, -0.36, 0))
    water = bpy.context.object
    water.name = "single turquoise water disk around island"
    water.scale = (3.05, 2.34, 1)
    water.data.materials.append(MAT["water"])
    for k in range(0, 76, 2):
        a = 2 * math.pi * k / 76
        x = math.cos(a) * 2.62
        z = math.sin(a) * 1.90
        add_cube("small white shoreline foam", (x, -0.315, z), (0.16, 0.012, 0.026), MAT["foam"]).rotation_euler[1] = -a
    for i in range(11):
        add_cube("subtle water reflection dash", (-1.55 + i * 0.30, -0.348, 1.98 + 0.04 * math.sin(i)), (0.18, 0.01, 0.018), MAT["foam"])


def add_props():
    make_ribbon(
        "front curved pale path matching reference",
        [(-1.56, 0.66), (-0.98, 0.50), (-0.34, 0.36), (0.24, 0.28), (0.86, 0.12), (1.40, -0.05)],
        0.052,
        MAT["path"],
    )
    make_ribbon(
        "left staircase climbing the hill",
        [(-0.96, 0.54), (-0.80, 0.26), (-0.66, -0.04), (-0.52, -0.34)],
        0.04,
        MAT["path"],
    )
    make_ribbon(
        "right staircase climbing the hill",
        [(0.70, 0.28), (0.58, 0.02), (0.44, -0.26), (0.32, -0.52)],
        0.04,
        MAT["path"],
    )
    make_ribbon(
        "short path to dock on right",
        [(1.05, 0.06), (1.38, 0.18), (1.68, 0.34)],
        0.04,
        MAT["path"],
    )
    make_ribbon(
        "left blue inlet matching reference",
        [(-1.62, -0.12), (-1.20, -0.08), (-0.82, -0.08), (-0.42, 0.06), (0.10, 0.22)],
        0.070,
        MAT["water"],
        0.055,
    )
    add_flat_water_ellipse("front right turquoise lagoon", 0.82, 0.78, 0.58, 0.34)
    add_flat_water_ellipse("left turquoise cove", -1.38, -0.04, 0.42, 0.25)
    add_round_main_building("CLICKABLE_PORTAL_main_hill_house", -0.44, -0.70)
    add_house("small white red roof house below main", -0.18, 0.02, 0.29, 0.19, 0.15)
    add_lighthouse("right side lighthouse tower", 1.34, -0.20)
    add_house("right dock hut", 1.56, 0.18, 0.18, 0.14, 0.12)
    add_cube("small red roof dock deck", (1.74, terrain_height(1.74, 0.35) - 0.09, 0.35), (0.58, 0.06, 0.30), MAT["wood"])
    for x, z in [(-0.96, 0.54), (0.70, 0.28), (0.32, -0.52), (-1.42, 0.18), (1.18, 0.16)]:
        for i in range(4):
            add_cube("short individual stair plank", (x + 0.07 * i, terrain_height(x, z) + 0.045 + 0.025 * i, z - 0.04 * i), (0.10, 0.018, 0.36), MAT["path"])
    tree_spots = [
        (-1.78, -0.15, "leaf_mint"),
        (-1.55, 0.70, "leaf_gold"),
        (-1.28, -0.52, "leaf_mint"),
        (-0.96, 0.96, "leaf_mint"),
        (-0.92, -0.78, "leaf"),
        (-0.64, -1.00, "leaf_gold"),
        (-0.30, -1.02, "leaf"),
        (-0.46, 0.86, "leaf"),
        (-0.24, -0.82, "leaf"),
        (0.34, -1.02, "leaf_gold"),
        (0.62, -0.58, "leaf"),
        (0.82, 0.50, "leaf_mint"),
        (1.28, 0.42, "leaf"),
        (1.72, 0.10, "leaf_gold"),
        (1.30, -0.48, "leaf"),
        (1.72, -0.40, "leaf"),
        (0.40, 1.10, "leaf_mint"),
        (-0.12, 1.16, "leaf"),
        (-1.88, 0.34, "leaf_mint"),
        (1.90, 0.58, "leaf"),
        (0.04, -0.40, "leaf_gold"),
    ]
    for i, (x, z, f) in enumerate(tree_spots):
        add_tree(x, z, 0.75 + (i % 4) * 0.08, f)
    random.seed(8)
    for i in range(42):
        a = i * 2.399
        radius = 0.28 + (i * 37 % 100) / 100 * 1.45
        x = math.cos(a) * radius
        z = math.sin(a) * radius * 0.72
        if (x / 2.3) ** 2 + (z / 1.7) ** 2 < 0.92:
            bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=5, radius=0.045 + 0.012 * (i % 3), location=(x, terrain_height(x, z) + 0.055, z))
            shrub = bpy.context.object
            shrub.name = "tiny rounded shrub"
            shrub.scale.z = 0.62
            shrub.data.materials.append(MAT["leaf_gold" if i % 5 == 0 else "grass_dark"])


def setup_scene():
    bpy.ops.object.light_add(type="AREA", location=(-3.6, 5.2, 5.4))
    key = bpy.context.object
    key.name = "large softbox key light"
    key.data.energy = 600
    key.data.size = 5.5
    bpy.ops.object.light_add(type="POINT", location=(3.0, -2.6, 2.0))
    fill = bpy.context.object
    fill.name = "warm fill light"
    fill.data.energy = 80
    bpy.context.scene.render.engine = "CYCLES"
    bpy.context.scene.cycles.samples = 96
    bpy.context.scene.view_settings.view_transform = "Filmic"
    bpy.context.scene.view_settings.look = "Medium High Contrast"


def export_glb():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(OUT),
        export_format="GLB",
        export_apply=True,
        export_materials="EXPORT",
        export_yup=True,
    )


clear_scene()
make_materials()
create_terrain()
create_cliffs()
add_water_and_foam()
add_props()
setup_scene()
export_glb()
