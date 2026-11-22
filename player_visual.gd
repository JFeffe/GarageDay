extends RefCounted

const WALK_SPEED := 4.9
const CARRY_SPEED := 4.0
const WALK_ACCELERATION := 30.0

var model: Node3D
var avatar: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var carry_weight := 0.0
var bones: Dictionary = {}
var hand_targets: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var pose_before_overlay: Array[Transform3D] = []
var last_pose := "idle"
var gesture := ""
var gesture_time := 0.0
var contact_targets: Array[Vector3] = []

func build(g: Node3D, root: Node3D) -> void:
	avatar = root
	model = preload("res://character_model.gd").create()
	root.add_child(model)
	skeleton = model.find_children("*","Skeleton3D",true,false)[0]
	animation = model.get_node("Locomotion")
	var material := StandardMaterial3D.new()
	material.albedo_texture = preload("res://assets/characters/skaterMaleA.png")
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.roughness = 0.85
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		mesh.material_override = material
	for side in ["Left","Right"]:
		for bone in ["Arm","ForeArm","Hand"]:
			bones[side+bone] = skeleton.find_bone(side+bone)
	animation.play("idle")
	animation.advance(0)
	capture_base()
	var arrow: MeshInstance3D = g.box(root,Vector3(0.08,0.018,0.28),Vector3(0,0.08,0.43),Color("#fff0b0"))
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func capture_base() -> void:
	pose_before_overlay.clear()
	for i in range(skeleton.get_bone_count()): pose_before_overlay.append(skeleton.get_bone_pose(i))

func restore_base() -> void:
	for i in range(pose_before_overlay.size()): skeleton.set_bone_pose(i,pose_before_overlay[i])

func animate(dt: float, speed: float, carrying: bool) -> void:
	contact_targets.clear()
	restore_base()
	model.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.5),Vector3.ZERO)
	var action := "walk" if speed>0.125 else "idle"
	if animation.current_animation != action: animation.play(action,0.18)
	animation.speed_scale = clampf(speed/3.875,0.25,1.0) if action == "walk" else 1.0
	animation.advance(dt)
	capture_base()
	carry_weight = move_toward(carry_weight,1.0 if carrying else 0.0,dt*7)
	last_pose = "carry" if carrying else action
	hand_targets = [Vector3(0.26,0.98,0.35),Vector3(-0.26,0.98,0.35)]
	if carry_weight>0:
		for i in range(2):
			reach(i,hand_targets[i],carry_weight)
	if gesture_time>0:
		gesture_time = maxf(0,gesture_time-dt)
		var weight := sin((1.0-gesture_time/0.4)*PI)
		for i in range(2):
			var target := Vector3(0.26 if i==0 else -0.26,0.75,0.43)
			if gesture=="rotate": target.y += 0.18 if i==0 else -0.08
			reach(i,target,weight)
		last_pose = gesture

func trigger(value: String) -> void:
	gesture = value
	gesture_time = 0.4

func sit_at(point: Vector2, yaw: float, blend: float) -> void:
	last_pose = "chair"
	var weight := smoothstep(0.0,1.0,blend)
	var desired := Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*0.5),Vector3(point.x,0.63,point.y))
	for side in ["Left","Right"]:
		var thigh := skeleton.find_bone(side+"UpLeg")
		var shin := skeleton.find_bone(side+"Leg")
		var foot := skeleton.find_bone(side+"Foot")
		if thigh<0 or shin<0 or foot<0: continue
		var thigh_position := skeleton.get_bone_global_pose(thigh).origin
		var knee := skeleton.get_bone_global_pose(shin).origin
		var body_basis := skeleton.global_basis.inverse()*model.global_basis
		aim_bone(thigh,knee-thigh_position,body_basis*Vector3(0,-0.1,1))
		knee = skeleton.get_bone_global_pose(shin).origin
		aim_bone(shin,skeleton.get_bone_global_pose(foot).origin-knee,body_basis*Vector3.DOWN)
	model.transform = model.transform.interpolate_with(avatar.global_transform.affine_inverse()*desired,weight)
	var seated_basis := model.global_basis.orthonormalized()
	for i in range(2):
		var palm := Vector3(0.18 if i==0 else -0.18,0.57,0.25)
		reach(i,avatar.to_local(model.global_position+seated_basis*palm),1.0)
		var local_basis := avatar.global_basis.inverse()*seated_basis
		orient_hand(i,local_basis*Vector3(0,-0.25,1),1.0,local_basis*Vector3.DOWN)
	for i in range(skeleton.get_bone_count()):
		skeleton.set_bone_pose(i,pose_before_overlay[i].interpolate_with(skeleton.get_bone_pose(i),weight))

func hand_position(side: int) -> Vector3:
	var name := "LeftHand" if side==0 else "RightHand"
	return avatar.to_local(skeleton.to_global(skeleton.get_bone_global_pose(bones[name]).origin))

func repair_grip(side: int, point: Vector3, tangent: Vector3, palm: Vector3, weight: float) -> void:
	var direction := (avatar.global_basis.inverse()*tangent).normalized()
	var normal := (avatar.global_basis.inverse()*palm).normalized()
	var tip := avatar.to_local(finger_tip(side))
	var grip_distance := hand_position(side).distance_to(tip)*0.46
	var wrist := avatar.to_local(point)-direction*grip_distance
	contact_targets.append(wrist)
	hand_targets[side] = wrist
	reach(side,wrist,weight)
	orient_hand(side,direction,weight,normal)

func finger_tip(side: int) -> Vector3:
	var prefix := "Left" if side==0 else "Right"
	var index := skeleton.find_bone(prefix+"HandIndex3_end")
	return skeleton.to_global(skeleton.get_bone_global_pose(index).origin)

func orient_hand(side: int, direction: Vector3, weight: float, palm_normal := Vector3.ZERO) -> void:
	var prefix := "Left" if side==0 else "Right"
	var hand: int = bones[prefix+"Hand"]
	var finger := skeleton.find_bone(prefix+"HandIndex3_end")
	if finger<0: return
	var wrist := skeleton.get_bone_global_pose(hand)
	var from := skeleton.get_bone_global_pose(finger).origin-wrist.origin
	var to := skeleton.global_basis.inverse()*avatar.global_basis*direction
	var original := skeleton.get_bone_pose(hand)
	aim_bone(hand,from,to)
	if palm_normal.length_squared()>0.001:
		var thumb := skeleton.find_bone(prefix+"HandThumb1")
		var palm := skeleton.get_bone_global_pose(hand)
		var fingers := skeleton.get_bone_global_pose(finger).origin-palm.origin
		var thumb_vector := skeleton.get_bone_global_pose(thumb).origin-palm.origin
		var normal := fingers.cross(thumb_vector).normalized()*(-1.0 if side==0 else 1.0)
		var axis := to.normalized()
		var desired := skeleton.global_basis.inverse()*avatar.global_basis*palm_normal
		desired = (desired-axis*desired.dot(axis)).normalized()
		normal = (normal-axis*normal.dot(axis)).normalized()
		var roll := atan2(axis.dot(normal.cross(desired)),normal.dot(desired))
		palm.basis = Basis(axis,roll)*palm.basis
		skeleton.set_bone_global_pose(hand,palm)
	skeleton.set_bone_pose(hand,original.interpolate_with(skeleton.get_bone_pose(hand),weight))

func reach(side: int, target_local: Vector3, weight: float) -> void:
	var prefix := "Left" if side==0 else "Right"
	var upper: int = bones[prefix+"Arm"]
	var lower: int = bones[prefix+"ForeArm"]
	var hand: int = bones[prefix+"Hand"]
	var a := skeleton.get_bone_global_pose(upper).origin
	var b := skeleton.get_bone_global_pose(lower).origin
	var c := skeleton.get_bone_global_pose(hand).origin
	var destination := skeleton.to_local(avatar.to_global(target_local))
	destination = c.lerp(destination,weight)
	var length_a := a.distance_to(b)
	var length_b := b.distance_to(c)
	var axis := (destination-a).normalized()
	var distance := clampf(a.distance_to(destination),absf(length_a-length_b)+0.00001,length_a+length_b-0.00001)
	destination = a+axis*distance
	var pole := skeleton.to_local(avatar.to_global(Vector3(0.6 if side==0 else -0.6,0.65,0.0)))-a
	var perpendicular := (pole-axis*pole.dot(axis)).normalized()
	var along := (length_a*length_a-length_b*length_b+distance*distance)/(2*distance)
	var elbow := a+axis*along+perpendicular*sqrt(maxf(0,length_a*length_a-along*along))
	aim_bone(upper,b-a,elbow-a)
	var elbow_now := skeleton.get_bone_global_pose(lower).origin
	var wrist_now := skeleton.get_bone_global_pose(hand).origin
	aim_bone(lower,wrist_now-elbow_now,destination-elbow_now)

func aim_bone(id: int, from: Vector3, to: Vector3) -> void:
	if from.length_squared()<0.000000001 or to.length_squared()<0.000000001: return
	var pose := skeleton.get_bone_global_pose(id)
	pose.basis = Basis(Quaternion(from.normalized(),to.normalized()))*pose.basis
	skeleton.set_bone_global_pose(id,pose)
