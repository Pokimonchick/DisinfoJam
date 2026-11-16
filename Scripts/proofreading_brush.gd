extends RefCounted

# Derived drawing data only. Normalized saved points remain the source of truth.
const CHUNK_SEGMENTS := 128
const CAP_STEPS := 6

var meshes: Array[ArrayMesh] = []
var tail: ArrayMesh
var built_chunks := 0
var _source: Array = []
var _scale := Vector2.ONE
var _width := 2.8
var _softness := 0.45
var _points := PackedVector2Array()
var _distance := PackedFloat32Array()
var _source_index := 0
var _sealed_index := 0
var _phase := 0.0
var _tail_dirty := false

func configure(points: Array, scale: Vector2, width: float, softness: float) -> void:
	_source = points
	_scale = scale
	_width = width
	_softness = softness

func pending() -> bool:
	return _source_index < _source.size() or _tail_dirty

func advance(deadline: int) -> bool:
	var changed := false
	while _source_index < _source.size() and Time.get_ticks_usec() < deadline:
		var raw: Array = _source[_source_index]
		_source_index += 1
		var point := Vector2(float(raw[0]), float(raw[1])) * _scale
		if not _points.is_empty() and point.distance_squared_to(_points[-1]) < 0.01:
			continue
		if _points.is_empty():
			_phase = point.x * 0.071 + point.y * 0.113
			_distance.append(0.0)
		else:
			_distance.append(_distance[-1] + point.distance_to(_points[-1]))
		_points.append(point)
		_tail_dirty = true
		# One following point makes the last join immutable. Tail rebuilding never
		# revisits the thousands of points already sealed into earlier chunks.
		if _points.size() > _sealed_index + CHUNK_SEGMENTS + 1:
			meshes.append(_mesh(_sealed_index, _sealed_index + CHUNK_SEGMENTS, _sealed_index == 0, false))
			_sealed_index += CHUNK_SEGMENTS
			tail = null
			built_chunks += 1
			changed = true
	if _tail_dirty and Time.get_ticks_usec() < deadline:
		tail = _mesh(_sealed_index, _points.size() - 1, _sealed_index == 0, true) if _points.size() > _sealed_index + 1 else null
		_tail_dirty = false
		changed = true
	return changed

func _radius(index: int) -> float:
	var distance := _distance[index]
	var variation := sin(distance * 0.115 + _phase) * 0.7 + sin(distance * 0.031 + _phase * 1.7) * 0.3
	# The outer edge stays within the existing paper-clipping width.
	return _width * 0.5 * (0.92 + variation * 0.08)

func _normal(index: int) -> Vector2:
	var before := (_points[index] - _points[maxi(0, index - 1)]).normalized()
	var after := (_points[mini(index + 1, _points.size() - 1)] - _points[index]).normalized()
	var tangent := before + after
	# No miter division: slow points and near reversals cannot create long spikes.
	if tangent.length_squared() < 0.25:
		tangent = after if after.length_squared() > 0.0 else before
	if tangent.length_squared() < 0.0001:
		tangent = Vector2.RIGHT
	return Vector2(-tangent.y, tangent.x).normalized()

func _mesh(first: int, last: int, start_cap: bool, end_cap: bool) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for index in range(first, last + 1):
		var normal := _normal(index)
		var radius := _radius(index)
		var inner := maxf(0.1, radius - minf(_softness, radius * 0.75))
		for offset in [radius, inner, -inner, -radius]:
			var point := _points[index] + normal * float(offset)
			vertices.append(Vector3(point.x, point.y, 0.0))
		colors.append(Color(1.0, 1.0, 1.0, 0.0))
		colors.append(Color.WHITE)
		colors.append(Color.WHITE)
		colors.append(Color(1.0, 1.0, 1.0, 0.0))
		if index > first:
			var current := (index - first) * 4
			var previous := current - 4
			for band in range(3):
				indices.append_array(PackedInt32Array([previous + band, previous + band + 1, current + band, current + band, previous + band + 1, current + band + 1]))
	if start_cap:
		_cap(first, (_points[first] - _points[first + 1]).angle(), vertices, colors, indices)
	if end_cap:
		_cap(last, (_points[last] - _points[last - 1]).angle(), vertices, colors, indices)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _cap(index: int, angle: float, vertices: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var center := vertices.size()
	var point := _points[index]
	var radius := _radius(index)
	var inner := maxf(0.1, radius - minf(_softness, radius * 0.75))
	vertices.append(Vector3(point.x, point.y, 0.0))
	colors.append(Color.WHITE)
	for step in range(CAP_STEPS + 1):
		var direction := Vector2.from_angle(angle - PI * 0.5 + PI * float(step) / CAP_STEPS)
		for distance in [inner, radius]:
			var edge := point + direction * float(distance)
			vertices.append(Vector3(edge.x, edge.y, 0.0))
		colors.append(Color.WHITE)
		colors.append(Color(1.0, 1.0, 1.0, 0.0))
		if step > 0:
			var current := center + 1 + step * 2
			var previous := current - 2
			indices.append_array(PackedInt32Array([center, previous, current, previous, previous + 1, current, current, previous + 1, current + 1]))
