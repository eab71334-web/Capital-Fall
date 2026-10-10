extends Node3D
# Capital Fall - المرحلة 2: واجهة محسّنة + أنيميشن + طيارة

const WORLD_LIMIT := 195.0
const PLANE_START := Vector3(12, 1.0, -8)

var player: CharacterBody3D
var rig: Dictionary
var cam: Camera3D
var ui: Control
var plane: Node3D
var prop: Node3D

var yaw := 0.0
var pitch := 0.25
var hp := 100.0
var disp_hp := 100.0
var kills := 0
var kills_pop := 0.0
var ammo := 30
var reloading := false
var reload_t := 0.0
var next_fire := 0.0
var recoil := 0.0
var enemies: Array = []
var anim_t := 0.0

var in_plane := false
var p_yaw := 0.0
var p_pitch := 0.0
var p_roll := 0.0
var p_speed := 0.0

var move_id := -1
var look_id := -1
var fire_id := -1
var move_origin := Vector2.ZERO
var move_vec := Vector2.ZERO
var fire_anim := 0.0

var dmg_flash := 0.0
var shake := 0.0
var hit_marker := 0.0
var toast_text := ""
var toast_t := 0.0
var cam_pos := Vector3.ZERO


# ---------------------------------------------------------------- بناء العالم

func _ready() -> void:
	randomize()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.7, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.6)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	add_child(sun)

	_make_box(Vector3(0, -0.5, 0), Vector3(400, 1, 400), Color(0.25, 0.4, 0.2))
	for i in 25:
		var size := Vector3(randf_range(3, 8), 4, randf_range(3, 8))
		var pos := Vector3(randf_range(-80, 80), 2, randf_range(-80, 80))
		if pos.length() < 12.0 or pos.distance_to(PLANE_START) < 16.0:
			continue
		_make_box(pos, size, Color(0.5, 0.5, 0.5))

	# الجندي
	player = CharacterBody3D.new()
	player.position = Vector3(0, 1.1, 0)
	var pcol := CollisionShape3D.new()
	var pshape := CapsuleShape3D.new()
	pshape.radius = 0.4
	pshape.height = 1.8
	pcol.shape = pshape
	player.add_child(pcol)
	rig = _make_humanoid(Color(0.25, 0.4, 0.25), Color(0.2, 0.22, 0.28), true)
	player.add_child(rig["root"])
	add_child(player)

	_build_plane()

	cam = Camera3D.new()
	cam.far = 600.0
	add_child(cam)
	cam.current = true
	cam_pos = player.position + Vector3(0, 3, 5)

	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.draw.connect(_draw_ui)
	layer.add_child(ui)

	for i in 6:
		_spawn_enemy()


func _mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _add_box(parent: Node, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _add_sphere(parent: Node, rad: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = rad
	sm.height = rad * 2.0
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _make_box(pos: Vector3, size: Vector3, c: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	_add_box(body, size, Vector3.ZERO, _mat(c))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	add_child(body)


# جسم بشري من مكعبات، مع مفاصل للأنيميشن
func _make_humanoid(shirt: Color, pants: Color, with_gun: bool) -> Dictionary:
	var root := Node3D.new()
	var torso_mat := _mat(shirt)
	var skin := _mat(Color(0.9, 0.75, 0.6))
	var pant_mat := _mat(pants)
	_add_box(root, Vector3(0.5, 0.7, 0.3), Vector3(0, 0.25, 0), torso_mat)
	_add_sphere(root, 0.2, Vector3(0, 0.85, 0), skin)

	var leg_l := Node3D.new()
	leg_l.position = Vector3(-0.14, -0.1, 0)
	root.add_child(leg_l)
	_add_box(leg_l, Vector3(0.2, 0.8, 0.22), Vector3(0, -0.4, 0), pant_mat)
	var leg_r := Node3D.new()
	leg_r.position = Vector3(0.14, -0.1, 0)
	root.add_child(leg_r)
	_add_box(leg_r, Vector3(0.2, 0.8, 0.22), Vector3(0, -0.4, 0), pant_mat)

	var arm_l := Node3D.new()
	arm_l.position = Vector3(-0.35, 0.5, 0)
	root.add_child(arm_l)
	_add_box(arm_l, Vector3(0.16, 0.6, 0.16), Vector3(0, -0.3, 0), torso_mat)
	var arm_r := Node3D.new()
	arm_r.position = Vector3(0.35, 0.5, 0)
	root.add_child(arm_r)
	_add_box(arm_r, Vector3(0.16, 0.6, 0.16), Vector3(0, -0.3, 0), torso_mat)
	arm_l.rotation.x = 1.4
	arm_r.rotation.x = 1.4

	var muzzle: MeshInstance3D = null
	if with_gun:
		_add_box(arm_r, Vector3(0.09, 0.7, 0.12), Vector3(0, -0.55, 0), _mat(Color(0.05, 0.05, 0.05)))
		muzzle = _add_sphere(arm_r, 0.13, Vector3(0, -1.0, 0), _mat(Color(1, 0.9, 0.2), true))
		muzzle.visible = false

	return {
		"root": root, "leg_l": leg_l, "leg_r": leg_r,
		"arm_l": arm_l, "arm_r": arm_r, "muzzle": muzzle,
		"torso_mat": torso_mat, "base_color": shirt,
	}


func _animate_rig(r: Dictionary, t: float, spd: float, aiming: bool) -> void:
	var amp := clampf(spd / 6.0, 0.0, 1.0)
	var sw := sin(t * 10.0) * 0.7 * amp
	var ll: Node3D = r["leg_l"]
	var lr: Node3D = r["leg_r"]
	var root: Node3D = r["root"]
	ll.rotation.x = sw
	lr.rotation.x = -sw
	if aiming:
		var al: Node3D = r["arm_l"]
		al.rotation.x = 1.2 + sin(t * 10.0) * 0.05 * amp
	root.position.y = absf(sin(t * 10.0)) * 0.06 * amp


func _build_plane() -> void:
	plane = Node3D.new()
	plane.position = PLANE_START
	add_child(plane)
	var body_mat := _mat(Color(0.55, 0.6, 0.65))
	var wing_mat := _mat(Color(0.35, 0.45, 0.3))
	var fus := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.5
	cm.height = 5.0
	fus.mesh = cm
	fus.material_override = body_mat
	fus.rotation.x = PI / 2.0
	plane.add_child(fus)
	_add_box(plane, Vector3(9, 0.12, 1.4), Vector3(0, 0, 0.2), wing_mat)
	_add_box(plane, Vector3(3, 0.1, 0.8), Vector3(0, 0.3, 2.2), wing_mat)
	_add_box(plane, Vector3(0.1, 1.0, 0.9), Vector3(0, 0.8, 2.2), wing_mat)
	var cockpit := _add_sphere(plane, 0.4, Vector3(0, 0.45, -0.6), _mat(Color(0.5, 0.8, 1.0)))
	cockpit.scale = Vector3(1, 0.7, 1.5)
	_add_sphere(plane, 0.25, Vector3(-0.8, -0.7, -0.3), _mat(Color(0.1, 0.1, 0.1)))
	_add_sphere(plane, 0.25, Vector3(0.8, -0.7, -0.3), _mat(Color(0.1, 0.1, 0.1)))
	prop = Node3D.new()
	prop.position = Vector3(0, 0, -2.6)
	plane.add_child(prop)
	_add_box(prop, Vector3(2.4, 0.14, 0.06), Vector3.ZERO, _mat(Color(0.1, 0.1, 0.1)))


func _spawn_enemy() -> void:
	var e := CharacterBody3D.new()
	var a := randf() * TAU
	var d := randf_range(25.0, 60.0)
	e.position = Vector3(cos(a) * d, 1.1, sin(a) * d)
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.4
	sh.height = 1.8
	cs.shape = sh
	e.add_child(cs)
	var r := _make_humanoid(Color(0.85, 0.1, 0.1), Color(0.3, 0.1, 0.1), false)
	e.add_child(r["root"])
	e.set_meta("hp", 50.0)
	e.set_meta("rig", r)
	e.set_meta("ph", randf() * 6.0)
	add_child(e)
	enemies.append(e)


func _restart() -> void:
	hp = 100.0
	disp_hp = 100.0
	kills = 0
	ammo = 30
	reloading = false
	in_plane = false
	p_speed = 0.0
	p_pitch = 0.0
	p_roll = 0.0
	p_yaw = 0.0
	plane.position = PLANE_START
	plane.basis = Basis.IDENTITY
	player.visible = true
	player.position = Vector3(0, 1.1, 0)
	player.velocity = Vector3.ZERO
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for i in 6:
		_spawn_enemy()


func _toast(t: String) -> void:
	toast_text = t
	toast_t = 1.6


# ---------------------------------------------------------------- الإدخال

func _action_visible() -> bool:
	if hp <= 0.0:
		return false
	return in_plane or player.global_position.distance_to(plane.global_position) < 7.0


func _input(event: InputEvent) -> void:
	var s := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			if hp <= 0.0:
				_restart()
				return
			if _action_visible() and p.distance_to(Vector2(s.x * 0.85, s.y * 0.45)) < s.y * 0.1:
				_toggle_plane()
			elif p.distance_to(Vector2(s.x * 0.85, s.y * 0.8)) < s.y * 0.14:
				fire_id = event.index
			elif p.x < s.x * 0.45:
				move_id = event.index
				move_origin = p
				move_vec = Vector2.ZERO
			else:
				look_id = event.index
		else:
			if event.index == move_id:
				move_id = -1
				move_vec = Vector2.ZERO
			elif event.index == look_id:
				look_id = -1
			elif event.index == fire_id:
				fire_id = -1
	elif event is InputEventScreenDrag:
		if event.index == move_id:
			move_vec = ((event.position - move_origin) / (s.y * 0.1)).limit_length(1.0)
		elif event.index == look_id and not in_plane:
			yaw -= event.relative.x * 0.005
			pitch = clampf(pitch + event.relative.y * 0.005, -0.2, 1.0)
	elif event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_E:
			_toggle_plane()


func _toggle_plane() -> void:
	if hp <= 0.0:
		return
	if in_plane:
		if plane.position.y > 1.5 or p_speed > 6.0:
			_toast("LAND FIRST")
			return
		in_plane = false
		p_speed = 0.0
		p_pitch = 0.0
		p_roll = 0.0
		var right := plane.global_transform.basis.x
		plane.basis = Basis(Vector3.UP, p_yaw)
		player.visible = true
		player.global_position = Vector3(plane.position.x, 1.1, plane.position.z) + right * 3.0
		player.velocity = Vector3.ZERO
		yaw = p_yaw
	else:
		if player.global_position.distance_to(plane.global_position) < 7.0:
			in_plane = true
			player.visible = false
			p_speed = 0.0
			_toast("STICK UP = TAKE OFF")
		else:
			_toast("GET CLOSER TO THE PLANE")


# ---------------------------------------------------------------- التحديث

func _physics_process(delta: float) -> void:
	anim_t += delta
	disp_hp = lerpf(disp_hp, hp, 1.0 - exp(-8.0 * delta))
	fire_anim = lerpf(fire_anim, 1.0 if fire_id != -1 else 0.0, 1.0 - exp(-20.0 * delta))
	kills_pop = maxf(0.0, kills_pop - delta * 3.0)
	dmg_flash = maxf(0.0, dmg_flash - delta * 1.5)
	hit_marker = maxf(0.0, hit_marker - delta * 4.0)
	toast_t = maxf(0.0, toast_t - delta)
	shake = lerpf(shake, 0.0, 1.0 - exp(-10.0 * delta))
	recoil = lerpf(recoil, 0.0, 1.0 - exp(-14.0 * delta))
	prop.rotation.z += delta * (2.0 + p_speed * 1.2 if in_plane else 2.0)

	var mv := move_vec
	var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if kb != Vector2.ZERO:
		mv = kb
	var firing := fire_id != -1 or Input.is_key_pressed(KEY_SPACE)
	var now := Time.get_ticks_msec() / 1000.0

	if hp > 0.0:
		if in_plane:
			_update_plane(delta, mv, firing, now)
		else:
			_update_soldier(delta, mv, firing, now)
		_update_enemies(delta)
	_update_camera(delta)
	ui.queue_redraw()


func _update_soldier(delta: float, mv: Vector2, firing: bool, now: float) -> void:
	var dir := Basis(Vector3.UP, yaw) * Vector3(mv.x, 0, mv.y)
	player.velocity.x = dir.x * 6.0
	player.velocity.z = dir.z * 6.0
	if player.is_on_floor():
		player.velocity.y = -1.0
	else:
		player.velocity.y -= 20.0 * delta
	player.move_and_slide()
	player.rotation.y = yaw
	player.position.x = clampf(player.position.x, -WORLD_LIMIT, WORLD_LIMIT)
	player.position.z = clampf(player.position.z, -WORLD_LIMIT, WORLD_LIMIT)

	var spd := Vector2(player.velocity.x, player.velocity.z).length()
	_animate_rig(rig, anim_t, spd, true)
	var arm_r: Node3D = rig["arm_r"]
	arm_r.rotation.x = 1.4 + recoil

	if reloading:
		reload_t -= delta
		if reload_t <= 0.0:
			reloading = false
			ammo = 30
	elif firing and now >= next_fire:
		next_fire = now + 0.15
		ammo -= 1
		_fire_soldier()
		if ammo <= 0:
			reloading = true
			reload_t = 1.4


func _update_plane(delta: float, mv: Vector2, firing: bool, now: float) -> void:
	var on_ground := plane.position.y <= 1.02
	if on_ground and mv.y > 0.3:
		p_speed = maxf(0.0, p_speed - 18.0 * delta)
	else:
		p_speed = minf(35.0, p_speed + 10.0 * delta)
	var can_lift := p_speed > 16.0 or not on_ground
	var target_pitch := -mv.y * 0.7 if can_lift else 0.0
	p_pitch = lerpf(p_pitch, target_pitch, 1.0 - exp(-2.5 * delta))
	p_roll = lerpf(p_roll, -mv.x * 0.8, 1.0 - exp(-3.0 * delta))
	if p_speed > 3.0:
		p_yaw -= mv.x * (0.5 if on_ground else 0.9) * delta
	plane.basis = Basis(Vector3.UP, p_yaw) * Basis(Vector3.RIGHT, p_pitch) * Basis(Vector3.BACK, p_roll)
	var fwd := -plane.basis.z
	plane.position += fwd * p_speed * delta
	if plane.position.y < 1.0:
		plane.position.y = 1.0
		p_pitch = maxf(p_pitch, 0.0)
	plane.position.y = minf(plane.position.y, 120.0)
	plane.position.x = clampf(plane.position.x, -WORLD_LIMIT, WORLD_LIMIT)
	plane.position.z = clampf(plane.position.z, -WORLD_LIMIT, WORLD_LIMIT)
	player.global_position = plane.global_position

	if firing and now >= next_fire:
		next_fire = now + 0.1
		_fire_plane()


func _update_enemies(delta: float) -> void:
	var target := player.global_position
	var chase := true
	if in_plane:
		target = plane.global_position
		if plane.global_position.y > 3.0:
			chase = false
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var eb := e as CharacterBody3D
		var r: Dictionary = eb.get_meta("rig")
		var ph: float = eb.get_meta("ph")
		var to := target - eb.global_position
		to.y = 0.0
		var dist := to.length()
		var near := false
		if chase and dist > 1.8:
			var v := to.normalized() * 3.0
			eb.velocity.x = v.x
			eb.velocity.z = v.z
		else:
			eb.velocity.x = 0.0
			eb.velocity.z = 0.0
			if chase:
				near = true
				hp = maxf(0.0, hp - 15.0 * delta)
				dmg_flash = 0.35
				shake = maxf(shake, 0.02)
		if eb.is_on_floor():
			eb.velocity.y = -1.0
		else:
			eb.velocity.y -= 20.0 * delta
		eb.move_and_slide()
		if chase and dist > 0.1:
			eb.rotation.y = lerp_angle(eb.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-10.0 * delta))
		var spd := Vector2(eb.velocity.x, eb.velocity.z).length()
		_animate_rig(r, anim_t + ph, spd, false)
		var al: Node3D = r["arm_l"]
		var ar: Node3D = r["arm_r"]
		if near:
			al.rotation.x = 1.5 + sin((anim_t + ph) * 14.0) * 0.5
			ar.rotation.x = 1.5 - sin((anim_t + ph) * 14.0) * 0.5
		else:
			al.rotation.x = 1.4
			ar.rotation.x = 1.4


func _update_camera(delta: float) -> void:
	var desired: Vector3
	var look_pos: Vector3
	if in_plane:
		var b := plane.global_transform.basis
		desired = plane.global_position + b * Vector3(0, 2.8, 9.0)
		look_pos = plane.global_position + b * Vector3(0, 0.8, -12.0)
	else:
		var target := player.global_position + Vector3(0, 1.4, 0)
		desired = target + Basis.from_euler(Vector3(-pitch, yaw, 0)) * Vector3(0, 0, 5)
		look_pos = target
	var k := 1.0 - exp(-(6.0 if in_plane else 25.0) * delta)
	cam_pos = cam_pos.lerp(desired, k)
	var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake
	cam.global_position = cam_pos + off
	cam.look_at(look_pos)


# ---------------------------------------------------------------- القتال

func _fire_soldier() -> void:
	recoil = 0.35
	shake = maxf(shake, 0.03)
	var mz: MeshInstance3D = rig["muzzle"]
	mz.visible = true
	get_tree().create_timer(0.05).timeout.connect(func() -> void: mz.visible = false)
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0, 0xFFFFFFFF, [player.get_rid()])
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var mpos := mz.global_position
	if r.is_empty():
		_tracer(mpos, from + dir * 80.0)
		return
	var hit_pos: Vector3 = r["position"]
	_tracer(mpos, hit_pos)
	var col = r["collider"]
	if col is CharacterBody3D and col.has_meta("hp"):
		_damage_enemy(col, 25.0)
	var spark := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.3
	spark.mesh = sm
	spark.material_override = _mat(Color(1, 1, 0), true)
	add_child(spark)
	spark.global_position = hit_pos
	get_tree().create_timer(0.1).timeout.connect(spark.queue_free)


func _fire_plane() -> void:
	shake = maxf(shake, 0.03)
	var o := plane.global_position
	var d := -plane.global_transform.basis.z
	var best: Node3D = null
	var best_t := 1000000.0
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var en := e as Node3D
		var rel := en.global_position - o
		var t := rel.dot(d)
		if t < 4.0 or t > 150.0:
			continue
		var perp := (rel - d * t).length()
		if perp < 3.0 and t < best_t:
			best = en
			best_t = t
	var mpos := o + d * 3.0
	if best != null:
		_tracer(mpos, best.global_position + Vector3(0, 0.5, 0))
		_damage_enemy(best, 20.0)
	else:
		_tracer(mpos, o + d * 100.0)


func _tracer(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.5:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.04, 0.04, l)
	mi.mesh = bm
	mi.material_override = _mat(Color(1, 0.9, 0.3), true)
	add_child(mi)
	mi.global_position = (a + b) * 0.5
	if absf(d.normalized().dot(Vector3.UP)) < 0.99:
		mi.look_at(b, Vector3.UP)
	get_tree().create_timer(0.06).timeout.connect(mi.queue_free)


func _damage_enemy(e: Node, dmg: float) -> void:
	if not e.has_meta("hp"):
		return
	var h: float = float(e.get_meta("hp")) - dmg
	hit_marker = 1.0
	var r: Dictionary = e.get_meta("rig")
	var tm: StandardMaterial3D = r["torso_mat"]
	tm.albedo_color = Color.WHITE
	create_tween().tween_property(tm, "albedo_color", r["base_color"], 0.15)
	if h <= 0.0:
		_kill_enemy(e)
	else:
		e.set_meta("hp", h)


func _kill_enemy(e: Node) -> void:
	var eb := e as CharacterBody3D
	enemies.erase(eb)
	eb.collision_layer = 0
	kills += 1
	kills_pop = 1.0
	_toast("ENEMY DOWN")
	var r: Dictionary = eb.get_meta("rig")
	var root: Node3D = r["root"]
	var t1 := create_tween()
	t1.tween_property(root, "rotation:x", PI / 2.0, 0.4)
	var t2 := create_tween()
	t2.tween_property(root, "position:y", -0.75, 0.4)
	get_tree().create_timer(1.5).timeout.connect(eb.queue_free)
	_spawn_enemy()


# ---------------------------------------------------------------- الواجهة

func _round_rect(r: Rect2, c: Color, rad: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(rad))
	ui.draw_style_box(sb, r)


func _txt(text: String, pos: Vector2, size: int, c: Color) -> void:
	var font := ThemeDB.fallback_font
	ui.draw_string(font, pos + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.6))
	ui.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _txt_c(text: String, y: float, size: int, c: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := ui.size.x
	ui.draw_string(font, Vector2(2, y + 2), text, HORIZONTAL_ALIGNMENT_CENTER, w, size, Color(0, 0, 0, 0.6))
	ui.draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, w, size, c)


func _txt_r(text: String, y: float, size: int, c: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := ui.size.x - 20.0
	ui.draw_string(font, Vector2(2, y + 2), text, HORIZONTAL_ALIGNMENT_RIGHT, w, size, Color(0, 0, 0, 0.6))
	ui.draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_RIGHT, w, size, c)


func _draw_ui() -> void:
	var s := ui.size
	var fs := int(s.y / 24.0)

	if dmg_flash > 0.0:
		ui.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 0, 0, dmg_flash * 0.5))

	# شريط الصحة
	var bw := s.x * 0.28
	var bh := s.y * 0.05
	_round_rect(Rect2(20, 20, bw, bh), Color(0, 0, 0, 0.5), bh * 0.4)
	var frac := clampf(disp_hp / 100.0, 0.0, 1.0)
	if frac > 0.01:
		var hc := Color(1.0, 0.25, 0.2).lerp(Color(0.3, 0.9, 0.35), frac)
		_round_rect(Rect2(24, 24, (bw - 8.0) * frac, bh - 8.0), hc, (bh - 8.0) * 0.4)
	_txt("HP %d" % maxi(0, int(hp)), Vector2(34, 20 + bh * 0.74), int(bh * 0.65), Color.WHITE)

	# الذخيرة / معلومات الطيارة
	var info := ""
	if in_plane:
		info = "SPD %d   ALT %d" % [int(p_speed), int(plane.position.y)]
	elif reloading:
		info = "RELOADING..."
	else:
		info = "AMMO %d / 30" % ammo
	_txt(info, Vector2(24, 20 + bh + fs + 8), fs, Color(1, 1, 1, 0.9))

	# القتلى
	var kfs := int(fs * (1.0 + kills_pop * 0.5))
	_txt_r("KILLS %d" % kills, kfs + 14.0, kfs, Color(1, 0.85, 0.3))

	# الرادار
	var rr := s.y * 0.13
	var rc := Vector2(s.x - rr - 20.0, fs * 2.0 + rr + 24.0)
	ui.draw_circle(rc, rr, Color(0, 0, 0, 0.45))
	ui.draw_arc(rc, rr, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 2.0)
	var ref_pos := plane.global_position if in_plane else player.global_position
	var ref_yaw := p_yaw if in_plane else yaw
	var cosy := cos(ref_yaw)
	var siny := sin(ref_yaw)
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var rel := (e as Node3D).global_position - ref_pos
		var rp := Vector2(rel.x * cosy - rel.z * siny, rel.x * siny + rel.z * cosy) * (rr / 60.0)
		if rp.length() > rr - 4.0:
			rp = rp.normalized() * (rr - 4.0)
		ui.draw_circle(rc + rp, 3.5, Color(1, 0.25, 0.25))
	if not in_plane:
		var prel := plane.global_position - ref_pos
		var pp := Vector2(prel.x * cosy - prel.z * siny, prel.x * siny + prel.z * cosy) * (rr / 60.0)
		if pp.length() > rr - 5.0:
			pp = pp.normalized() * (rr - 5.0)
		ui.draw_circle(rc + pp, 5.0, Color(0.3, 0.8, 1.0))
	ui.draw_circle(rc, 4.0, Color.WHITE)

	# علامة التصويب
	var cc := s * 0.5
	var cl := Color(1, 1, 1, 0.85)
	ui.draw_line(cc + Vector2(-22, 0), cc + Vector2(-8, 0), cl, 2.0)
	ui.draw_line(cc + Vector2(22, 0), cc + Vector2(8, 0), cl, 2.0)
	ui.draw_line(cc + Vector2(0, -22), cc + Vector2(0, -8), cl, 2.0)
	ui.draw_line(cc + Vector2(0, 22), cc + Vector2(0, 8), cl, 2.0)
	if hit_marker > 0.0:
		var hm := Color(1, 0.2, 0.2, hit_marker)
		ui.draw_line(cc + Vector2(-12, -12), cc + Vector2(-5, -5), hm, 3.0)
		ui.draw_line(cc + Vector2(12, -12), cc + Vector2(5, -5), hm, 3.0)
		ui.draw_line(cc + Vector2(-12, 12), cc + Vector2(-5, 5), hm, 3.0)
		ui.draw_line(cc + Vector2(12, 12), cc + Vector2(5, 5), hm, 3.0)

	# عصا التحريك
	var jr := s.y * 0.14
	var jc := move_origin if move_id != -1 else Vector2(s.x * 0.15, s.y * 0.76)
	var ja := 0.35 if move_id != -1 else 0.15
	ui.draw_circle(jc, jr, Color(1, 1, 1, ja * 0.4))
	ui.draw_arc(jc, jr, 0.0, TAU, 48, Color(1, 1, 1, ja + 0.1), 3.0)
	ui.draw_circle(jc + move_vec * jr, jr * 0.4, Color(1, 1, 1, ja + 0.15))

	# زر النار
	var fc := Vector2(s.x * 0.85, s.y * 0.8)
	var fr := s.y * 0.12 * (1.0 - 0.12 * fire_anim)
	var fcol := Color(1.0, 0.2, 0.15, 0.5 + 0.2 * fire_anim)
	var flabel := "FIRE"
	if reloading and not in_plane:
		fcol = Color(0.5, 0.5, 0.5, 0.5)
		flabel = "RELOAD"
	ui.draw_circle(fc, fr, fcol)
	ui.draw_arc(fc, fr, 0.0, TAU, 48, Color(1, 1, 1, 0.7), 3.0)
	ui.draw_string(ThemeDB.fallback_font, fc + Vector2(-fr, fs * 0.35), flabel, HORIZONTAL_ALIGNMENT_CENTER, fr * 2.0, fs, Color.WHITE)

	# زر الطيارة
	if _action_visible():
		var ac := Vector2(s.x * 0.85, s.y * 0.45)
		var ar := s.y * 0.085
		var acol := Color(0.2, 0.5, 1.0, 0.55)
		var alabel := "PLANE"
		if in_plane:
			alabel = "EXIT"
			if plane.position.y > 1.5 or p_speed > 6.0:
				acol = Color(0.5, 0.5, 0.5, 0.5)
		ui.draw_circle(ac, ar, acol)
		ui.draw_arc(ac, ar, 0.0, TAU, 48, Color(1, 1, 1, 0.7), 3.0)
		ui.draw_string(ThemeDB.fallback_font, ac + Vector2(-ar, fs * 0.35), alabel, HORIZONTAL_ALIGNMENT_CENTER, ar * 2.0, int(fs * 0.9), Color.WHITE)

	# رسالة سريعة
	if toast_t > 0.0:
		_txt_c(toast_text, s.y * 0.25, int(fs * 1.3), Color(1, 1, 0.4, clampf(toast_t, 0.0, 1.0)))

	# نهاية اللعبة
	if hp <= 0.0:
		ui.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.6))
		_txt_c("GAME OVER", s.y * 0.42, fs * 3, Color(1, 0.3, 0.3))
		_txt_c("Kills: %d" % kills, s.y * 0.55, fs * 2, Color.WHITE)
		_txt_c("tap to restart", s.y * 0.66, fs, Color(1, 1, 1, 0.8))
