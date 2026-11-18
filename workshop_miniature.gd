extends RefCounted

const Catalog := preload("res://workshop_catalog.gd")

const RUBBER := Color("#2d363c")
const DARK := Color("#293e46")
const SILVER := Color("#b9c6c6")
const OCHRE := Color("#ca9550")

static func material(color: Color, roughness := 0.60, metallic := 0.0) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.roughness = roughness
	surface.metallic = metallic
	return surface

static func outline(width: float, length: float, y: float, bevel: float) -> Array[Vector3]:
	var w := width/2
	var l := length/2
	return [Vector3(-w+bevel,y,-l),Vector3(w-bevel,y,-l),
		Vector3(w,y,-l+bevel),Vector3(w,y,l-bevel),
		Vector3(w-bevel,y,l),Vector3(-w+bevel,y,l),
		Vector3(-w,y,l-bevel),Vector3(-w,y,-l+bevel)]

static func polygon(surface: SurfaceTool, vertices: Array[Vector3], outward: Vector3) -> void:
	var normal := (vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).normalized()
	if normal.dot(outward)<0:
		vertices.reverse()
		normal = -normal
	for i in range(1,vertices.size()-1):
		for j in [0,i,i+1]:
			surface.set_normal(normal)
			surface.add_vertex(vertices[j])

static func bevel_box(parent: Node3D, size: Vector3, at: Vector3, color: Color,
		radius := 0.065, roughness := 0.60, metallic := 0.0) -> MeshInstance3D:
	var r := minf(radius,minf(size.x,minf(size.y,size.z))*0.42)
	var rings := [
		outline(size.x-r,size.z-r,-size.y/2,r),
		outline(size.x,size.z,-size.y/2+r,r*1.6),
		outline(size.x,size.z,size.y/2-r,r*1.6),
		outline(size.x-r,size.z-r,size.y/2,r),
	]
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in range(3):
		for i in range(8):
			var j := (i+1)%8
			var face: Array[Vector3] = [rings[layer][i],rings[layer][j],rings[layer+1][j],rings[layer+1][i]]
			var direction := (face[0]+face[1]+face[2]+face[3])/4.0
			polygon(mesh,face,direction)
	polygon(mesh,rings[0],Vector3.DOWN)
	polygon(mesh,rings[3],Vector3.UP)
	var node := MeshInstance3D.new()
	node.mesh = mesh.commit()
	node.material_override = material(color,roughness,metallic)
	node.position = at
	parent.add_child(node)
	return node

static func pane(parent: Node3D, corners: Array[Vector3], direction: Vector3, color: Color) -> void:
	var face := SurfaceTool.new()
	face.begin(Mesh.PRIMITIVE_TRIANGLES)
	polygon(face,corners,direction)
	var node := MeshInstance3D.new()
	node.mesh = face.commit()
	node.material_override = material(color,0.29,0.09)
	node.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	parent.add_child(node)

static func cylinder(parent: Node3D, radius: float, depth: float, at: Vector3, color: Color,
		segments := 20) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = depth
	shape.radial_segments = segments
	shape.rings = 0
	var result := MeshInstance3D.new()
	result.mesh = shape
	result.position = at
	result.material_override = material(color)
	parent.add_child(result)
	return result

static func trolley(parent: Node3D, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = at
	parent.add_child(root)
	bevel_box(root,Vector3(0.66,0.087,0.59),Vector3(0,0.213,0),OCHRE,0.034)
	bevel_box(root,Vector3(0.54,0.023,0.45),Vector3(0,0.266,0),RUBBER,0.010)
	for side in [-1,1]:
		bevel_box(root,Vector3(0.050,0.051,0.55),Vector3(side*0.302,0.267,0),OCHRE)
		bevel_box(root,Vector3(0.048,0.69,0.052),Vector3(side*0.265,0.593,-0.246),OCHRE)
		for z in [-0.223,0.22]:
			var caster := cylinder(root,0.066,0.049,Vector3(side*0.263,0.074,z),RUBBER,12)
			caster.rotation.z = PI/2
			cylinder(caster,0.028,0.064,Vector3.ZERO,SILVER,12)
			bevel_box(root,Vector3(0.09,0.067,0.09),Vector3(side*0.263,0.146,z),DARK,0.017)
	var handle := cylinder(root,0.028,0.582,Vector3(0,0.944,-0.246),DARK,14)
	handle.rotation.z = PI/2
	bevel_box(root,Vector3(0.27,0.063,0.021),Vector3(0,0.222,0.304),Color("#ebca89"),0.008)
	return root

static func lift_control(parent: Node3D, point: Vector2) -> Dictionary:
	var root := Node3D.new()
	root.position = Vector3(point.x,0.05,point.y)
	parent.add_child(root)
	bevel_box(root,Vector3(0.60,0.08,0.55),Vector3(0,0.04,0),DARK,0.032)
	bevel_box(root,Vector3(0.19,0.66,0.19),Vector3(0,0.38,0),DARK,0.026)
	bevel_box(root,Vector3(0.45,0.23,0.39),Vector3(0,0.78,0),OCHRE,0.050)
	bevel_box(root,Vector3(0.38,0.025,0.30),Vector3(0,0.897,0),DARK,0.009)
	var handle := Node3D.new()
	handle.position = Vector3(0.06,0.91,0.02)
	root.add_child(handle)
	cylinder(handle,0.023,0.16,Vector3(0,0.08,0),SILVER,12)
	bevel_box(handle,Vector3(0.139,0.062,0.070),Vector3(0,0.154,0),Color("#b85848"),0.023)
	var lamp := cylinder(root,0.046,0.016,Vector3(-0.12,0.918,0.043),SILVER,14)
	lamp.material_override.emission_enabled = true
	lamp.material_override.emission_energy_multiplier = 0.32
	var control := {"root":root,"handle":handle,"lamp":lamp}
	set_lift_control(control,false,false)
	return control

static func set_lift_control(control: Dictionary, raised: bool, moving: bool) -> void:
	control.handle.rotation.x = -0.52 if raised else 0.52
	var lamp_color := Color("#f7d189") if raised else Color("#96d2af")
	if moving: lamp_color = Color("#d99a60")
	control.lamp.material_override.albedo_color = lamp_color
	control.lamp.material_override.emission = lamp_color

static func repair_part(root: Node3D, kind: String) -> void:
	var color := Color("#7a736d") if kind=="old_muffler" else Color(Catalog.PARTS[kind][1])
	match kind:
		"new_muffler","old_muffler":
			bevel_box(root,Vector3(0.62,0.22,0.28),Vector3(0,0.13,0),color,0.056,0.65,0.14)
			var pipe := cylinder(root,0.06,0.24,Vector3(0.38,0.12,0),color.darkened(0.16),14)
			pipe.rotation.z = PI/2
		"brake_pads":
			for x in [-0.095,0.095]: bevel_box(root,Vector3(0.13,0.065,0.24),Vector3(x,0.055,0),color,0.022)
		"damper_part":
			var shaft := cylinder(root,0.04,0.46,Vector3(0,0.10,0),SILVER,14)
			shaft.rotation.x = PI/2
			for i in range(5):
				var ring := cylinder(root,0.09,0.027,Vector3(0,0.10,-0.12+i*0.048),color,14)
				ring.rotation.x = PI/2
		"shield_part":
			bevel_box(root,Vector3(0.49,0.065,0.33),Vector3(0,0.055,0),color,0.028)
			for x in [-0.15,0.0,0.15]: bevel_box(root,Vector3(0.04,0.035,0.22),Vector3(x,0.095,0),DARK,0.009)
		"bearing_part","belt_part":
			cylinder(root,0.135,0.062,Vector3(0,0.065,0),color,20)
			cylinder(root,0.083,0.014,Vector3(0,0.100,0),DARK,20)
		"lamp_front","lamp_rear":
			cylinder(root,0.04,0.08,Vector3(0,0.04,0),SILVER,12)
			cylinder(root,0.063,0.10,Vector3(0,0.12,0),color,16)
		"wiper_pair":
			for x in [-0.067,0.067]: bevel_box(root,Vector3(0.052,0.046,0.39),Vector3(x,0.058,0),color,0.009)
		_:
			bevel_box(root,Vector3(0.26,0.086,0.18),Vector3(0,0.058,0),color,0.023)
			bevel_box(root,Vector3(0.12,0.012,0.086),Vector3(0,0.103,0),Color("#e1c39f"),0.005)
