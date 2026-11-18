extends RefCounted

const Catalog := preload("res://workshop_catalog.gd")

var wheel_in_hands: MeshInstance3D
var wheel_rest := Vector3.ZERO
var last_stance := Transform3D.IDENTITY
var last_arms: Array[Transform3D] = []
var last_prop: Node3D
var last_prop_pose := Transform3D.IDENTITY
var release := 0.0

func restore_wheel() -> void:
	if is_instance_valid(wheel_in_hands):
		wheel_in_hands.position = wheel_rest
	wheel_in_hands = null

func apply(workshop, dt: float) -> bool:
	var visual = workshop.game.player_visual
	var action: Dictionary = workshop.action
	var applied := false
	if action.has("bay"):
		var bay: Dictionary = workshop.site.bays[action.bay]
		var elapsed: float = workshop.progress
		var amount := clampf(elapsed/maxf(0.01,action.seconds),0,1)
		var blend := smoothstep(0.0,minf(0.19,action.seconds*0.36),elapsed)
		if action.id in Catalog.HOOD_ACTIONS:
			hood_pose(visual,bay,action.id,elapsed,blend,workshop.item_prop)
			applied = true
		elif action.id=="wheel":
			var stage: int = bay.order.wheels[action.wheel]
			if stage!=2:
				wheel_pose(visual,bay,action.wheel,stage,amount,elapsed,blend,workshop.item_prop)
				applied = true
	if applied:
		last_stance = visual.model.transform
		last_arms.clear()
		for bone in visual.bones.values():
			last_arms.append(visual.skeleton.get_bone_pose(bone))
		last_prop = workshop.item_prop
		if is_instance_valid(last_prop): last_prop_pose = last_prop.transform
		release = 1.0
		return true
	restore_wheel()
	release = move_toward(release,0.0,dt*6.0)
	if release>0.0:
		visual.model.transform = visual.model.transform.interpolate_with(last_stance,release)
		var arms: Array = visual.bones.values()
		for i in range(arms.size()):
			var current: Transform3D = visual.skeleton.get_bone_pose(arms[i])
			visual.skeleton.set_bone_pose(arms[i],current.interpolate_with(last_arms[i],release))
		if is_instance_valid(last_prop) and workshop.item_prop==last_prop:
			last_prop.transform = last_prop.transform.interpolate_with(last_prop_pose,release)
	elif action.is_empty() and is_instance_valid(workshop.item_prop):
		if workshop.held=="tires":
			wrench_grips(visual,workshop.item_prop,1.0)
		elif workshop.held in ["new_tire","used_tire","repair_wheel"]:
			carry_tire(visual,workshop.item_prop)
	return false

func stand(visual, contact: Vector3, outward: Vector3, distance: float, lean: float, weight: float) -> void:
	var avatar: Node3D = visual.avatar
	var toward := -outward
	var desired := contact+outward*distance
	desired.y = avatar.global_position.y
	var feet := avatar.global_position+(desired-avatar.global_position).limit_length(1.42)
	var facing := Basis(Vector3.UP,atan2(toward.x,toward.z))
	var stance := Transform3D((facing*Basis(Vector3.RIGHT,lean)).scaled(Vector3.ONE*0.50),feet)
	visual.model.transform = visual.model.transform.interpolate_with(avatar.global_transform.affine_inverse()*stance,weight)

func hood_pose(visual, bay: Dictionary, job: String, elapsed: float, weight: float, prop: Node3D) -> void:
	var hood: MeshInstance3D = bay.hood
	var car: Node3D = bay.car
	var outward := car.global_basis.z.normalized()
	var edge := hood.get_aabb()
	var parent: Node3D = hood.get_parent()
	var closed_edge := parent.to_global(hood.position+Vector3(0,0,edge.end.z))
	var lifting := smoothstep(0.12,0.36,elapsed)
	var working := smoothstep(0.38,0.60,elapsed)
	stand(visual,closed_edge,outward,lerpf(0.46,0.33,lifting),lerpf(0.10,0.22,lifting),weight)
	var points := hood_lip(hood)
	var lip_normal := hood.global_basis.y.normalized()
	var lip_forward := hood.global_basis.z.normalized()
	var engine_anchor := "BatteryGrip" if job in ["remove_battery","install_battery"] else "EngineGrip"
	var component := parent.get_node(engine_anchor) as Marker3D
	for side in range(2):
		var point := hood.to_global(points[side])-lip_normal*0.022+lip_forward*0.022
		var tangent := -lip_forward
		var palm := lip_normal
		if side==1:
			point = point.lerp(component.global_position+Vector3.UP*0.026,working)
			tangent = tangent.lerp(-outward,working).normalized()
			palm = palm.lerp(Vector3.DOWN,working).normalized()
		visual.repair_grip(side,point,tangent,palm,weight)
	if is_instance_valid(prop):
		var wrist: Vector3 = visual.avatar.to_global(visual.hand_position(1))
		var forward: Vector3 = (visual.finger_tip(1)-wrist).normalized()
		prop.global_position = prop.global_position.lerp(wrist+forward*0.075,weight)

func hood_lip(hood: MeshInstance3D) -> Array[Vector3]:
	if hood.has_meta("repair_lip"): return hood.get_meta("repair_lip")
	var edge := hood.get_aabb()
	var mesh := TriangleMesh.new()
	mesh.create_from_faces(hood.mesh.get_faces())
	var points: Array[Vector3] = []
	for side in [-1.0,1.0]:
		var center := Vector3(side*edge.size.x*0.27,edge.get_center().y,edge.end.z-0.038)
		var hit := mesh.intersect_segment(center+Vector3.UP*0.18,center+Vector3.DOWN*0.18)
		points.append(hit.get("position",center))
	hood.set_meta("repair_lip",points)
	return points

func wheel_pose(visual, bay: Dictionary, index: int, stage: int, amount: float, elapsed: float, weight: float, prop: Node3D) -> void:
	var tire: MeshInstance3D = bay.tires[index]
	var car: Node3D = bay.car
	var side := signf(car.to_local(tire.global_position).x)
	var outward := car.global_basis.x.normalized()*side
	var bounds := tire.get_aabb()
	var face := bounds.get_center()
	face.x = bounds.end.x if side>0.0 else bounds.position.x
	if stage==1:
		if wheel_in_hands!=tire:
			restore_wheel()
			wheel_in_hands = tire
			wheel_rest = tire.position
		var parent: Node3D = tire.get_parent()
		var pulled := smoothstep(0.23,0.95,amount)
		var displacement := outward*(pulled*0.29)+Vector3.UP*(sin(pulled*PI)*0.045-pulled*0.12)
		tire.position = wheel_rest+parent.global_basis.inverse()*displacement
		var rest_hub := tire.to_global(face)-displacement
		stand(visual,rest_hub,outward,0.49+pulled*0.16,0.12,weight)
		wheel_grips(visual,tire,face,side,outward,weight)
	elif is_instance_valid(prop):
		var hub := tire.to_global(wheel_face(tire,face,side))
		stand(visual,hub,outward,0.73,0.12,weight)
		use_wrench(visual,prop,hub,outward,elapsed,weight,stage==3)

func wheel_surface(tire: MeshInstance3D) -> TriangleMesh:
	if tire.has_meta("repair_surface"): return tire.get_meta("repair_surface")
	var mesh := TriangleMesh.new()
	mesh.create_from_faces(tire.mesh.get_faces())
	tire.set_meta("repair_surface",mesh)
	return mesh

func wheel_face(tire: MeshInstance3D, center: Vector3, side: float) -> Vector3:
	var mesh := wheel_surface(tire)
	var hit := mesh.intersect_segment(center+Vector3.RIGHT*side*0.08,center-Vector3.RIGHT*side*0.40)
	return hit.get("position",center)

func wheel_grips(visual, tire: MeshInstance3D, face: Vector3, side: float, outward: Vector3, weight: float) -> void:
	var bounds := tire.get_aabb()
	# The same rim points follow the mesh throughout the pull.
	var points: Array[Vector3] = []
	if tire.has_meta("repair_grips"):
		points = tire.get_meta("repair_grips")
	else:
		for hand in [1.0,-1.0]:
			var near := face+Vector3(0,bounds.size.y*0.18,hand*side*bounds.size.z*0.37)
			points.append(wheel_face(tire,near,side))
		tire.set_meta("repair_grips",points)
	var across := outward.cross(Vector3.UP)
	for hand in range(2):
		var inward := across if hand==1 else -across
		var point := tire.to_global(points[hand])+outward*0.025
		visual.repair_grip(hand,point,(inward+Vector3.DOWN*0.26).normalized(),-outward,weight)

func use_wrench(visual, prop: Node3D, hub: Vector3, outward: Vector3, elapsed: float, weight: float, tightening: bool) -> void:
	var socket := prop.find_child("SocketTip",true,false) as Marker3D
	var roll := sin(elapsed*TAU*7.0)*0.054
	if tightening: roll = -roll
	var basis := Basis.looking_at(outward,Vector3.UP).rotated(outward,roll)
	var offset := prop.to_local(socket.global_position)
	var on_hub := Transform3D(basis,hub+outward*(0.010+absf(roll)*0.13)-basis*offset)
	prop.global_transform = prop.global_transform.interpolate_with(on_hub,weight)
	wrench_grips(visual,prop,weight)

func wrench_grips(visual, prop: Node3D, weight: float) -> void:
	var forward := prop.global_basis.z.normalized()
	var across := prop.global_basis.x.normalized()
	var motor := prop.find_child("MotorGrip",true,false) as Marker3D
	var handle := prop.find_child("HandleGrip",true,false) as Marker3D
	visual.repair_grip(0,motor.global_position+across*0.012,forward,-across,weight)
	visual.repair_grip(1,handle.global_position-across*0.014,forward,across,weight)

func carry_tire(visual, prop: Node3D) -> void:
	var forward := prop.global_basis.z.normalized()
	for hand in range(2):
		var x := 0.235 if hand==0 else -0.235
		var point := prop.to_global(Vector3(x,-0.082,-0.10))
		visual.repair_grip(hand,point,forward,Vector3.UP,1.0)
