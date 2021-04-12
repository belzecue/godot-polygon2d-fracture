extends Polygon2D




const LINE_FADE_SPEED : float  = 1.5




signal Despawn(ref)




export(float, 0.0, 256.0, 0.05) var lin_drag : float = 0.0
export(float, 0.0, 256.0, 0.05) var ang_drag : float = 0.0
export(Vector2) var gravity_direction = Vector2(0, 1)
export(float) var gravity_scale : float = 10.0

export(Curve) var lifetime_scale_curve



onready var _line := $Line2D
onready var _timer := $Timer
onready var _line_lerp_start_color : Color = _line.modulate




var _t : float = 1.0
var _lifetime : float = 0.0

var _lin_accel := Vector2.ZERO
var _ang_accel : float = 0.0
var _lin_vel := Vector2.ZERO
var _ang_vel : float = 0.0

var _mass : float = 1.0

var _scale_lerp_start := Vector2.ZERO
#var _dead : bool = false



func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	visible = false


func _process(delta: float) -> void:
	if _t < 1.0:
		_t += delta * LINE_FADE_SPEED
		_line.modulate = lerp(_line_lerp_start_color, self_modulate, min(_t, 1.0))
	
	if not _timer.is_stopped() and _lifetime > 0.0:
		var p : float = clamp(1.0 - (_timer.time_left / _lifetime), 0.0, 1.0)
		if lifetime_scale_curve:
			p = lifetime_scale_curve.interpolate_baked(p)
		global_scale = lerp(_scale_lerp_start, Vector2.ZERO, p)
	
	

func _physics_process(delta: float) -> void:
	addForce(gravity_direction.normalized() * gravity_scale * delta)
#	var friction : Vector2 = (-1.0 * _lin_vel).normalized() * lin_drag
#	_lin_vel += friction
	_lin_vel += _lin_accel
	_ang_vel += _ang_accel
	
	var lin_drag_magnitude : float = _lin_vel.length() * lin_drag * delta
	var lin_drag_force : Vector2 = -1.0 * _lin_vel.normalized() * lin_drag_magnitude
	_lin_vel += lin_drag_force
	
	var ang_drag_magnitude : float = _ang_vel * ang_drag * delta
	var ang_drag_force : float = sign(_ang_vel) * -1.0 * ang_drag_magnitude
	_ang_vel += ang_drag_force
	
	global_position += _lin_vel * delta
	global_rotation += _ang_vel * delta
	
	_lin_accel = Vector2.ZERO
	_ang_accel = 0.0
	
#	print("Lin vel: ", _lin_vel, " Ang Vel: ", _ang_vel)
#	if _dead:
#		scale = lerp(scale, Vector2.ZERO, delta)


func spawn(pos : Vector2, rot : float, s : Vector2, lifetime : float = 3.0) -> void:
	visible = true
	
	global_position = pos
	global_rotation = rot
	global_scale = s
	_scale_lerp_start = s
	
	_lifetime = lifetime
	_timer.start(lifetime)
	_t = 0.0
	
	_lin_vel = Vector2.ZERO
	_ang_vel = 0.0
	_lin_accel = Vector2.ZERO
	_ang_accel = 0.0
	
	set_process(true)
	set_physics_process(true)


func despawn() -> void:
#	_dead = false
	visible = false
	set_process(false)
	set_physics_process(false)
	_t = 1.0


func addForce(force : Vector2) -> void:
	if _mass > 0.0:
		force /= _mass
	_lin_accel += force

func addTorque(torque : float) -> void:
	_ang_accel += torque


func setPolygon(poly : PoolVector2Array, c : Color, texture_info : Dictionary) -> void:
	set_polygon(poly)
	poly.append(poly[0])
	_line.points = poly
	setColor(c)
	setTexture(texture_info)


func setTexture(texture_info : Dictionary) -> void:
	texture = texture_info.texture
	texture_scale = texture_info.scale
	texture_offset = texture_info.offset
	texture_rotation = texture_info.rot


func setColor(color : Color) -> void:
	self_modulate = color

func setMass(new_mass : float) -> void:
	_mass = new_mass


func _on_Timer_timeout() -> void:
#	if _dead: return
#	_dead = true
	emit_signal("Despawn", self)