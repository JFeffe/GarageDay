extends RefCounted

static func create() -> Node3D:
	var model: Node3D = load("res://assets/characters/characterMedium.fbx").instantiate()
	model.scale = Vector3.ONE*0.50
	var player := AnimationPlayer.new()
	player.name = "Locomotion"
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	model.add_child(player)
	var library := AnimationLibrary.new()
	for action in ["idle","run"]:
		var source: Node = load("res://assets/characters/"+action+".fbx").instantiate()
		var original: AnimationPlayer = source.find_children("*","AnimationPlayer",true,false)[0]
		for anim_name in original.get_animation_list():
			if "Targeting" in anim_name: continue
			var animation: Animation = original.get_animation(anim_name).duplicate()
			animation.loop_mode = Animation.LOOP_LINEAR
			library.add_animation(action,animation)
			break
		source.free()
	# Reduce stride, knee lift and bounce to adapt the run cycle to walking.
	var walk: Animation = library.get_animation("run").duplicate()
	var idle: Animation = library.get_animation("idle")
	for track in range(walk.get_track_count()):
		var type := walk.track_get_type(track)
		var rest_track := idle.find_track(walk.track_get_path(track),type)
		if rest_track<0 or idle.track_get_key_count(rest_track)==0: continue
		var rest = idle.track_get_key_value(rest_track,0)
		for key in range(walk.track_get_key_count(track)):
			var value = walk.track_get_key_value(track,key)
			if type == Animation.TYPE_ROTATION_3D:
				walk.track_set_key_value(track,key,rest.slerp(value,0.65))
			elif type == Animation.TYPE_POSITION_3D:
				walk.track_set_key_value(track,key,rest.lerp(value,0.65))
	library.add_animation("walk",walk)
	player.add_animation_library("",library)
	return model
