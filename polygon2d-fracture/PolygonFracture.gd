class_name PolygonFracture




var _rng : RandomNumberGenerator




func _init(new_seed : int = -1) -> void:
	_rng = RandomNumberGenerator.new()
	
	if new_seed == -1:
		_rng.randomize()
	else:
		_rng.seed = new_seed





#all fracture functions return an array of dictionaries -> where the dictionary is 1 fracture shard (see func makeShapeInfo) -------------------------------------

#fracture simple generates random cut lines around the bounding box of the polygon -> cut_number is the amount of lines generated
#cut_number is capped at 32 because cut_number is not equal to the amount of shards generated -> 32 cuts can produce a lot of fracture shards
func fractureSimple(source_polygon : PoolVector2Array, source_global_trans : Transform2D, cut_number : int, min_discard_area : float) -> Array:
	cut_number = clamp(cut_number, 0, 32)
#	source_polygon = PolygonLib.rotatePolygon(source_polygon, world_rot_rad)
	var bounding_rect : Rect2 = PolygonLib.getBoundingRect(source_polygon)
	var cut_lines : Array = getCutLines(bounding_rect, cut_number)
	
	var polygons : Array = [source_polygon]
	
	for line in cut_lines:
		var poly_line = PolygonLib.offsetPolyline(line, 0.1, true)[0]
		var new_polies : Array = []
		for poly in polygons:
			var result : Array = PolygonLib.clipPolygons(poly, poly_line, true)
			new_polies += result
		
		polygons.clear()
		polygons += new_polies
	
	var fracture_info : Array = []
	for poly in polygons:
		var triangulation : Dictionary = PolygonLib.triangulatePolygon(poly, true, true)
		
		if triangulation.area > min_discard_area:
			var shape_info : Dictionary = PolygonLib.getShapeInfoSimple(source_global_trans, poly, triangulation)
			fracture_info.append(shape_info)
	
	return fracture_info

#fracture generates random points (cut_number * 2) and then connects 2 random points to form a cut line (each point is only used once) 
#lines are extended to make sure the whole polygon is cut
#cut_number is capped at 32 because cut_number is not equal to the amount of shards generated -> 32 cuts can produce a lot of fracture shards
func fracture(source_polygon : PoolVector2Array, source_global_trans : Transform2D, cut_number : int, min_discard_area : float) -> Array:
	cut_number = clamp(cut_number, 0, 32)
#	source_polygon = PolygonLib.rotatePolygon(source_polygon, world_rot_rad)
	var bounding_rect : Rect2 = PolygonLib.getBoundingRect(source_polygon)
	var points : Array = getRandomPointsInPolygon(source_polygon, cut_number * 2)
	var cut_lines : Array = getCutLinesFromPoints(points, cut_number, PolygonLib.getBoundingRectMaxSize(bounding_rect))
	
	var polygons : Array = [source_polygon]
	
	for line in cut_lines:
		var poly_line = PolygonLib.offsetPolyline(line, 0.1, true)[0]
		var new_polies : Array = []
		for poly in polygons:
			var result : Array = PolygonLib.clipPolygons(poly, poly_line, true)
			new_polies += result
		
		polygons.clear()
		polygons += new_polies
	
	var fracture_info : Array = []
	for poly in polygons:
		var triangulation : Dictionary = PolygonLib.triangulatePolygon(poly, true, true)
		
		if triangulation.area > min_discard_area:
			var shape_info : Dictionary = PolygonLib.getShapeInfoSimple(source_global_trans, poly, triangulation)
			fracture_info.append(shape_info)
	
	return fracture_info

#fracture delaunay uses delaunay triangulation to produce triangles -> random points (amount = fracture_number) inside the polygon are added to the source polygons points 
#to produce more triangles 
#is this func all produced triangles are clipped with the source polygon, to make sure there are no triangles outside 
#if you only use convex polygons use fractureDelaunyConvex
func fractureDelaunay(source_polygon : PoolVector2Array, source_global_trans : Transform2D, fracture_number : int, min_discard_area : float) -> Array:
#	source_polygon = PolygonLib.rotatePolygon(source_polygon, world_rot_rad)
	var points = getRandomPointsInPolygon(source_polygon, fracture_number)
	var triangulation : Dictionary = PolygonLib.triangulatePolygonDelaunay(points + source_polygon, true, true)
	
	var fracture_info : Array = []
	for triangle in triangulation.triangles:
		if triangle.area < min_discard_area:
			continue
		
		var results : Array = PolygonLib.intersectPolygons(triangle.points, source_polygon, true)
		for r in results:
			if r.size() > 0:
				if r.size() == 3:
					var area : float = PolygonLib.getTriangleArea(r)
					if area >= min_discard_area:
						var centroid : Vector2 = PolygonLib.getTriangleCentroid(r)
#						var source_global_trans := Transform2D(world_rot_rad, world_pos)
						var centered_shape = PolygonLib.translatePolygon(r, -centroid)
						var spawn_pos : Vector2 = PolygonLib.getShapeSpawnPos(source_global_trans, centroid)
						fracture_info.append(PolygonLib.makeShapeInfo(centered_shape, centroid, spawn_pos, triangle.area, source_global_trans))
				else:
					var t : Dictionary = PolygonLib.triangulatePolygon(r, true, true)
					if t.area >= min_discard_area:
						var shape_info : Dictionary = PolygonLib.getShapeInfoSimple(source_global_trans, r, t)
						fracture_info.append(shape_info)
	
	return fracture_info

#fractureDelaunayConvex works the same as the default fractureDelaunay but it asumes the source polygon is convex 
#makes the fracturing simpler and faster because the final triangles dont have to be clipped with the source polygon
func fractureDelaunayConvex(concave_polygon : PoolVector2Array, source_global_trans : Transform2D, fracture_number : int, min_discard_area : float) -> Array:
#	concave_polygon = PolygonLib.rotatePolygon(concave_polygon, world_rot_rad)
	var points = getRandomPointsInPolygon(concave_polygon, fracture_number)
	var triangulation : Dictionary = PolygonLib.triangulatePolygonDelaunay(points + concave_polygon, true, true)
	
	var fracture_info : Array = []
	for triangle in triangulation.triangles:
		if triangle.area < min_discard_area:
			continue
		
		var centroid : Vector2 = PolygonLib.getTriangleCentroid(triangle.points)
#		var source_global_trans := Transform2D(world_rot_rad, world_pos)
		var centered_shape = PolygonLib.translatePolygon(triangle.points, -centroid)
		var spawn_pos : Vector2 = PolygonLib.getShapeSpawnPos(source_global_trans, centroid)
		fracture_info.append(PolygonLib.makeShapeInfo(centered_shape, centroid, spawn_pos, triangle.area, source_global_trans))
	
	return fracture_info

#fractureDelaunayRectangle is the same as fractureDelaunayConvex but it asumes the source polygon is a rectangle
#the rectangle makes the random point generation easier on top of the simplification of fractureDelaunayConvex
func fractureDelaunayRectangle(rectangle_polygon : PoolVector2Array, source_global_trans : Transform2D, fracture_number : int, min_discard_area : float) -> Array:
#	rectangle_polygon = PolygonLib.rotatePolygon(rectangle_polygon, world_rot_rad)
	var points = getRandomPointsInRectangle(PolygonLib.getBoundingRect(rectangle_polygon), fracture_number)
	var triangulation : Dictionary = PolygonLib.triangulatePolygonDelaunay(points + rectangle_polygon, true, true)
	
	var fracture_info : Array = []
	for triangle in triangulation.triangles:
		if triangle.area < min_discard_area:
			continue
		
		var centroid : Vector2 = PolygonLib.getTriangleCentroid(triangle.points)
#		var source_global_trans := Transform2D(world_rot_rad, world_pos)
		var centered_shape = PolygonLib.translatePolygon(triangle.points, -centroid)
		var spawn_pos : Vector2 = PolygonLib.getShapeSpawnPos(source_global_trans, centroid)
		fracture_info.append(PolygonLib.makeShapeInfo(centered_shape, centroid, spawn_pos, triangle.area, source_global_trans))
	
	return fracture_info
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------------



#returns a dictionary containing shapes and fractures 
#-> shapes is an array containing all shape infos generated -> the clipped shapes (the non overlapping areas of the source polygon and cut polygon) can be used for new source polygons
#-> fractures is an array containing all fracture infos generated -> the intersected shapes (the overlapping areas of the source polygon and cut polygon) and the shapes smaller than cut_min_area are fractured
#-> intersected shapes smaller than fracture_min_area are discarded
#-> fracture pieces smaller than shard_min_area are discarded
func cutFracture(source_polygon : PoolVector2Array, cut_polygon : PoolVector2Array, source_trans_global : Transform2D, cut_trans_global : Transform2D, cut_min_area : float, fracture_min_area : float, shard_min_area : float, fractures : int = 3) -> Dictionary:
	var cut_info : Dictionary = PolygonLib.cutShape(source_polygon, cut_polygon, source_trans_global, cut_trans_global)
		
	var fracture_infos : Array = []
	if cut_info.intersected and cut_info.intersected.size() > 0:
		for shape in cut_info.intersected:
			var area : float = PolygonLib.getPolygonArea(shape)
			if area < fracture_min_area:
				continue
			
			var fracture_info : Array = fractureDelaunay(shape, source_trans_global, fractures, shard_min_area)
			fracture_infos.append(fracture_info)
	
	var shape_infos : Array = []
	if cut_info.final and cut_info.final.size() > 0:
		for shape in cut_info.final:
			var triangulation : Dictionary = PolygonLib.triangulatePolygon(shape)
			var shape_area : float = triangulation.area#PolygonLib.getPolygonArea(shape)
			if shape_area < cut_min_area:
				var fracture_info : Array = fractureDelaunay(shape, source_trans_global, fractures, shard_min_area)
				fracture_infos.append(fracture_info)
				continue
			
			var shape_info : Dictionary = PolygonLib.getShapeInfoSimple(source_trans_global, shape, triangulation)
			shape_infos.append(shape_info)
	
	return {"shapes" : shape_infos, "fractures" : fracture_infos}





#returns an array of PoolVector2Arrays -> each PoolVector2Array consists of two Vector2 [start, end]
#is used in the func fracture 
func getCutLinesFromPoints(points : Array, cuts : int, max_size : float) -> Array:
	var cut_lines : Array = []
	if cuts <= 0 or not points or points.size() <= 2: return cut_lines
	
	for i in range(cuts):
		var start : Vector2 = points[(i * 2)]
		var end : Vector2 = points[(i * 2) + 1]
		var dir : Vector2 = (end - start).normalized()
		
		#extend the line so it will always be bigger than the polygon
		start -= dir * max_size
		end += dir * max_size
		
		var line : PoolVector2Array = [start, end]
		cut_lines.append(line)
	return cut_lines

#returns an array of PoolVector2Arrays -> each PoolVector2Array consists of two Vector2 [start, end]
#is used in the func fractureSimple
func getCutLines(bounding_rect : Rect2, number : int) -> Array:
	var corners : Dictionary = PolygonLib.getBoundingRectCorners(bounding_rect)
	
	var horizontal_pair : Dictionary = {"left" : [corners.A, corners.D], "right" : [corners.B, corners.C]}
	var vertical_pair : Dictionary = {"top" : [corners.A, corners.B], "bottom" : [corners.D, corners.C]}
	
	var lines : Array = []
	for i in range(number):
		
		if _rng.randf() < 0.5:#horizontal
			var start : Vector2 = lerp(horizontal_pair.left[0], horizontal_pair.left[1], _rng.randf())
			var end : Vector2 = lerp(horizontal_pair.right[0], horizontal_pair.right[1], _rng.randf())
			var line : PoolVector2Array = [start, end]
			lines.append(line)
		else:#vertical
			var start : Vector2 = lerp(vertical_pair.top[0], vertical_pair.top[1], _rng.randf())
			var end : Vector2 = lerp(vertical_pair.bottom[0], vertical_pair.bottom[1], _rng.randf())
			var line : PoolVector2Array = [start, end]
			lines.append(line)
	
	return lines





func getRandomPointsInRectangle(rectangle : Rect2, number : int) -> PoolVector2Array:
	var points : PoolVector2Array = []
	
	for i in range(number):
		var x : float = _rng.randf_range(rectangle.position.x, rectangle.end.x)
		var y : float = _rng.randf_range(rectangle.position.y, rectangle.end.y)
		points.append(Vector2(x, y))
	
	return points

#gets a random triangle from a triangulation using the getRandomTriangle func and then gets a random point
#inside the chosen triangle
func getRandomPointsInPolygon(poly : PoolVector2Array, number : int) -> PoolVector2Array:
	var triangulation : Dictionary = PolygonLib.triangulatePolygon(poly, true, false)
	
	var points : PoolVector2Array = []
	
	for i in range(number):
		var triangle : Array = getRandomTriangle(triangulation)
		if triangle.size() <= 0: continue
		var point : Vector2 = getRandomPointInTriangle(triangle)
		points.append(point)
	
	return points

#if a polygon is triangulated, that function can be used to get a random triangle from the triangultion
#each triangle is weighted based on its area
func getRandomTriangle(triangulation : Dictionary) -> PoolVector2Array:
	var chosen_weight : float = _rng.randf() * triangulation.area
	var current_weight : float = 0.0
	for triangle in triangulation.triangles:
		current_weight += triangle.area
		if current_weight > chosen_weight:
			return triangle.points
	
	var empty : PoolVector2Array = []
	return empty


func getRandomPointInTriangle(points : PoolVector2Array) -> Vector2:
	var rand_1 : float = _rng.randf()
	var rand_2 : float = _rng.randf()
	var sqrt_1 : float = sqrt(rand_1)
	
	return (1.0 - sqrt_1) * points[0] + sqrt_1 * (1.0 - rand_2) * points[1] + sqrt_1 * rand_2 * points[2]
