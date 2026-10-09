extends Node3D
# المرحلة 1: جندي بسلاح. كل شيء ينبني بالكود.

var player: CharacterBody3D
var cam: Camera3D
var ui: Control
var yaw := 0.0
var pitch := 0.25
var hp := 100.0
var kills := 0
var next_fire := 0.0
var enemies: Array = []
var move_id := -1
var look_id := -1
var fire_id := -1
var move_origin := Vector2.ZERO
var move_vec := Vector2.ZERO


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
		if pos.length() < 10.0:
			continue
		_make_box(pos, size, Color(0.5, 0.5, 0.5))

	player = CharacterBody3D.new()
	player.position = Vector3(0, 1.1, 0)
	var pcol := CollisionShape3D.new()
	var pshape := CapsuleShape3D.new()
	pshape.radius = 0.4
	pshape.height = 1.8
	pcol.shape = pshape
	player.add_child(pcol)
	var pmesh := MeshInstance3D.new()
	var pcaps := CapsuleMesh.new()
	pcaps.radius = 0.4
	pcaps.height = 1.8
	pmesh.mesh = pcaps
	pmesh.material_override = _mat(Color(0.2, 0.35, 0.2))
	player.add_child(pmesh)
	var gun := MeshInstance3D.new()
	var gbox := BoxMesh.new()
	gbox.size = Vector3(0.12, 0.12, 0.9)
	gun.mesh = gbox
	gun.position = Vector3(0.4, 0.2, -0.6)
	gun.material_override = _mat(Color(0.05, 0.05, 0.05))
	player.add_child(gun)
	add_child(player)

	cam = Camera3D.new()
	cam.far = 500.0
	add_child(cam)
	cam.current = true

	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.draw.connect(_draw_ui)
	layer.add_child(ui)

	for i in 6:
		_spawn_enemy()


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _make_box(pos: Vector3, size: Vector3, c: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	add_child(body)


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
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	mi.mesh = cm
	mi.material_override = _mat(Color(0.9, 0.1, 0.1))
	e.add_child(mi)
	e.set_meta("hp", 50.0)
	add_child(e)
	enemies.append(e)


func _restart() -> void:
	hp = 100.0
	kills = 0
	player.position = Vector3(0, 1.1, 0)
	player.velocity = Vector3.ZERO
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for i in 6:
		_spawn_enemy()


func _input(event: InputEvent) -> void:
	var s := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			if hp <= 0.0:
				_restart()
				return
			if p.distance_to(Vector2(s.x * 0.85, s.y * 0.8)) < s.y * 0.14:
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
		elif event.index == look_id:
			yaw -= event.relative.x * 0.005
			pitch = clampf(pitch + event.relative.y * 0.005, -0.2, 1.0)


func _physics_process(delta: float) -> void:
	if hp > 0.0:
		var mv := move_vec
		var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if kb != Vector2.ZERO:
			mv = kb
		var dir := Basis(Vector3.UP, yaw) * Vector3(mv.x, 0, mv.y)
		player.velocity.x = dir.x * 6.0
		player.velocity.z = dir.z * 6.0
		if player.is_on_floor():
			player.velocity.y = -1.0
		else:
			player.velocity.y -= 20.0 * delta
		player.move_and_slide()
		player.rotation.y = yaw

		var now := Time.get_ticks_msec() / 1000.0
		if (fire_id != -1 or Input.is_key_pressed(KEY_SPACE)) and now >= next_fire:
			next_fire = now + 0.15
			_fire()

		for e in enemies:
			if not is_instance_valid(e):
				continue
			var to: Vector3 = player.global_position - e.global_position
			to.y = 0.0
			if to.length() > 1.8:
				var v: Vector3 = to.normalized() * 3.0
				e.velocity.x = v.x
				e.velocity.z = v.z
			else:
				e.velocity.x = 0.0
				e.velocity.z = 0.0
				hp -= 15.0 * delta
			if e.is_on_floor():
				e.velocity.y = -1.0
			else:
				e.velocity.y -= 20.0 * delta
			e.move_and_slide()

	var target := player.global_position + Vector3(0, 1.4, 0)
	cam.global_position = target + Basis.from_euler(Vector3(-pitch, yaw, 0)) * Vector3(0, 0, 5)
	cam.look_at(target)
	ui.queue_redraw()


func _fire() -> void:
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * 200.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, [player.get_rid()])
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return
	var col = r["collider"]
	if col.has_meta("hp"):
		var h: float = float(col.get_meta("hp")) - 25.0
		if h <= 0.0:
			enemies.erase(col)
			col.queue_free()
			kills += 1
			_spawn_enemy()
		else:
			col.set_meta("hp", h)
	var spark := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.3
	spark.mesh = sm
	spark.material_override = _mat(Color(1, 1, 0))
	add_child(spark)
	spark.global_position = r["position"]
	get_tree().create_timer(0.1).timeout.connect(spark.queue_free)


func _draw_ui() -> void:
	var s := ui.size
	var font := ThemeDB.fallback_font
	var fs := int(s.y / 22.0)
	ui.draw_string(font, Vector2(20, fs + 10), "HP: %d   Kills: %d" % [maxi(0, int(hp)), kills], HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var c := Vector2(s.x * 0.85, s.y * 0.8)
	ui.draw_circle(c, s.y * 0.12, Color(1, 0, 0, 0.35))
	ui.draw_string(font, c + Vector2(-fs, fs * 0.35), "FIRE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	if move_id != -1:
		ui.draw_circle(move_origin, 60, Color(1, 1, 1, 0.2))
		ui.draw_circle(move_origin + move_vec * 60.0, 30, Color(1, 1, 1, 0.45))
	if hp <= 0.0:
		ui.draw_string(font, Vector2(s.x * 0.25, s.y * 0.5), "GAME OVER - tap to restart", HORIZONTAL_ALIGNMENT_LEFT, -1, fs * 2)
