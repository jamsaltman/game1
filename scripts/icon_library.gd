class_name IconLibrary
extends RefCounted

static var ICON_NAMES := PackedStringArray([
	"pusher",
	"puller",
	"blocker",
	"redirector",
	"grabber",
	"guide",
	"smuggler",
	"killer",
])

static var INK := {
	"pusher": Color8(217, 103, 73),
	"puller": Color8(215, 166, 77),
	"blocker": Color8(120, 102, 81),
	"redirector": Color8(177, 132, 86),
	"grabber": Color8(164, 95, 67),
	"guide": Color8(190, 144, 71),
	"smuggler": Color8(207, 154, 63),
	"killer": Color8(190, 68, 54),
}

static var LABELS := {
	"pusher": "PU",
	"puller": "PL",
	"blocker": "BL",
	"redirector": "RD",
	"grabber": "GB",
	"guide": "GD",
	"smuggler": "SM",
	"killer": "KL",
}

static var FACE_BG_FRONT := Color8(236, 219, 189)
static var FACE_BG_BACK := Color8(43, 39, 36)
static var FACE_BG_FRONT_HOVER := Color8(247, 230, 200)
static var FACE_BG_BACK_HOVER := Color8(61, 54, 49)
static var OUTLINE := Color8(33, 28, 24)
static var DARK := Color8(53, 48, 41)
static var LIGHT := Color8(255, 246, 225)

static var GLYPHS := {
	"B": PackedStringArray(["110", "101", "110", "101", "110"]),
	"D": PackedStringArray(["110", "101", "101", "101", "110"]),
	"G": PackedStringArray(["011", "100", "101", "101", "011"]),
	"K": PackedStringArray(["101", "101", "110", "101", "101"]),
	"L": PackedStringArray(["100", "100", "100", "100", "111"]),
	"M": PackedStringArray(["101", "111", "111", "101", "101"]),
	"P": PackedStringArray(["110", "101", "110", "100", "100"]),
	"R": PackedStringArray(["110", "101", "110", "101", "101"]),
	"S": PackedStringArray(["011", "100", "010", "001", "110"]),
	"U": PackedStringArray(["101", "101", "101", "101", "111"]),
}


static func make_face_texture(icon_id: String, is_front: bool, hovered: bool = false, size: int = 32) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var face_color := FACE_BG_FRONT if is_front else FACE_BG_BACK
	if hovered:
		face_color = FACE_BG_FRONT_HOVER if is_front else FACE_BG_BACK_HOVER

	var unit := maxi(size / 16, 1)
	var canvas_size := unit * 16
	var origin := Vector2i((size - canvas_size) / 2, (size - canvas_size) / 2)
	_draw_rounded_rect(image, Rect2i(origin.x + unit, origin.y + unit, canvas_size - unit * 2, canvas_size - unit * 2), unit * 2, face_color)
	if is_front:
		var ink: Color = INK.get(icon_id, Color8(255, 255, 255))
		_draw_front_face(image, icon_id, ink, unit, origin)
	else:
		_draw_card_back(image, hovered, unit, origin)

	return ImageTexture.create_from_image(image)


static func _draw_front_face(image: Image, icon_id: String, ink: Color, unit: int, origin: Vector2i) -> void:
	var shadow := ink.darkened(0.52)
	var panel := FACE_BG_FRONT.lerp(ink, 0.08)
	var band := ink.darkened(0.18)

	_grid_rect(image, origin, unit, Rect2i(2, 2, 12, 12), OUTLINE)
	_grid_rect(image, origin, unit, Rect2i(3, 3, 10, 10), panel)
	_grid_rect(image, origin, unit, Rect2i(3, 3, 10, 3), band)
	_grid_rect(image, origin, unit, Rect2i(4, 6, 8, 1), ink.lightened(0.34))
	_grid_rect(image, origin, unit, Rect2i(4, 11, 8, 1), ink.darkened(0.24))
	_grid_rect(image, origin, unit, Rect2i(4, 7, 8, 4), panel.lightened(0.06))
	_draw_role_label(image, String(LABELS.get(icon_id, "?")), unit, origin)
	_draw_role_emblem(image, icon_id, ink, shadow, unit, origin)


static func _draw_role_emblem(image: Image, icon_id: String, ink: Color, shadow: Color, unit: int, origin: Vector2i) -> void:
	match icon_id:
		"pusher":
			_grid_rect(image, origin, unit, Rect2i(5, 8, 4, 2), shadow)
			_grid_rect(image, origin, unit, Rect2i(8, 7, 2, 4), shadow)
			_grid_rect(image, origin, unit, Rect2i(9, 6, 2, 6), shadow)
			_grid_rect(image, origin, unit, Rect2i(11, 8, 1, 2), shadow)
			_grid_rect(image, origin, unit, Rect2i(5, 7, 4, 2), LIGHT)
			_grid_rect(image, origin, unit, Rect2i(8, 6, 2, 4), ink)
			_grid_rect(image, origin, unit, Rect2i(9, 5, 2, 6), ink)
			_grid_rect(image, origin, unit, Rect2i(11, 7, 1, 2), LIGHT)
		"puller":
			_grid_rect(image, origin, unit, Rect2i(5, 7, 2, 5), shadow)
			_grid_rect(image, origin, unit, Rect2i(9, 7, 2, 5), shadow)
			_grid_rect(image, origin, unit, Rect2i(6, 10, 4, 2), shadow)
			_grid_rect(image, origin, unit, Rect2i(6, 6, 4, 2), shadow)
			_grid_rect(image, origin, unit, Rect2i(7, 5, 2, 2), shadow)
			_grid_rect(image, origin, unit, Rect2i(5, 6, 2, 5), ink)
			_grid_rect(image, origin, unit, Rect2i(9, 6, 2, 5), ink)
			_grid_rect(image, origin, unit, Rect2i(6, 9, 4, 2), ink)
			_grid_rect(image, origin, unit, Rect2i(6, 5, 4, 2), LIGHT)
			_grid_rect(image, origin, unit, Rect2i(7, 4, 2, 2), LIGHT)
		"blocker":
			_grid_rect(image, origin, unit, Rect2i(5, 7, 6, 6), shadow)
			_grid_rect(image, origin, unit, Rect2i(6, 8, 4, 4), DARK)
			_grid_rect(image, origin, unit, Rect2i(4, 8, 8, 1), ink)
			_grid_rect(image, origin, unit, Rect2i(4, 11, 8, 1), ink)
			_grid_rect(image, origin, unit, Rect2i(5, 7, 1, 6), LIGHT)
			_grid_rect(image, origin, unit, Rect2i(10, 7, 1, 6), ink)
		"redirector":
			_grid_rect(image, origin, unit, Rect2i(5, 7, 3, 2), shadow)
			_grid_rect(image, origin, unit, Rect2i(7, 7, 2, 4), shadow)
			_grid_rect(image, origin, unit, Rect2i(8, 9, 3, 2), shadow)
			_grid_rect(image, origin, unit, Rect2i(9, 8, 2, 4), shadow)
			_grid_rect(image, origin, unit, Rect2i(5, 6, 3, 2), LIGHT)
			_grid_rect(image, origin, unit, Rect2i(7, 6, 2, 4), ink)
			_grid_rect(image, origin, unit, Rect2i(8, 8, 3, 2), ink)
			_grid_rect(image, origin, unit, Rect2i(9, 7, 2, 4), LIGHT)
		"grabber":
			_grid_rect(image, origin, unit, Rect2i(5, 7, 1, 5), shadow)
			_grid_rect(image, origin, unit, Rect2i(7, 7, 1, 5), shadow)
			_grid_rect(image, origin, unit, Rect2i(9, 7, 1, 5), shadow)
			_grid_rect(image, origin, unit, Rect2i(5, 11, 5, 1), shadow)
			_grid_rect(image, origin, unit, Rect2i(5, 6, 1, 5), LIGHT)
			_grid_rect(image, origin, unit, Rect2i(7, 6, 1, 5), ink)
			_grid_rect(image, origin, unit, Rect2i(9, 6, 1, 5), LIGHT)
			_grid_rect(image, origin, unit, Rect2i(5, 10, 5, 1), ink)
		"guide":
			_grid_rect(image, origin, unit, Rect2i(4, 8, 8, 3), shadow)
			_grid_rect(image, origin, unit, Rect2i(5, 7, 6, 5), LIGHT)
			_grid_rect(image, origin, unit, Rect2i(7, 8, 2, 3), shadow)
			_grid_rect(image, origin, unit, Rect2i(8, 8, 1, 2), ink)
			_grid_rect(image, origin, unit, Rect2i(7, 6, 2, 1), ink)
			_grid_rect(image, origin, unit, Rect2i(7, 12, 2, 1), ink)
		"smuggler":
			_grid_rect(image, origin, unit, Rect2i(5, 7, 6, 5), shadow)
			_grid_rect(image, origin, unit, Rect2i(6, 6, 4, 1), shadow)
			_grid_rect(image, origin, unit, Rect2i(6, 8, 4, 3), ink)
			_grid_rect(image, origin, unit, Rect2i(5, 7, 6, 1), LIGHT)
			_grid_rect(image, origin, unit, Rect2i(5, 11, 6, 1), ink.darkened(0.28))
			_grid_rect(image, origin, unit, Rect2i(7, 5, 2, 2), LIGHT)
		"killer":
			_grid_rect(image, origin, unit, Rect2i(5, 7, 6, 4), LIGHT)
			_grid_rect(image, origin, unit, Rect2i(6, 11, 4, 1), LIGHT)
			_grid_rect(image, origin, unit, Rect2i(6, 8, 1, 1), OUTLINE)
			_grid_rect(image, origin, unit, Rect2i(9, 8, 1, 1), OUTLINE)
			_grid_rect(image, origin, unit, Rect2i(7, 11, 2, 1), ink)
			_grid_rect(image, origin, unit, Rect2i(6, 12, 1, 1), shadow)
			_grid_rect(image, origin, unit, Rect2i(9, 12, 1, 1), shadow)
		_:
			_grid_rect(image, origin, unit, Rect2i(5, 7, 6, 5), ink)


static func _draw_role_label(image: Image, label: String, unit: int, origin: Vector2i) -> void:
	var glyph_width := 3 * unit
	var spacing := unit
	var total_width := label.length() * glyph_width + maxi(label.length() - 1, 0) * spacing
	var start_x := origin.x + ((16 * unit) - total_width) / 2
	var start_y := origin.y + unit * 4
	for index in range(label.length()):
		_draw_glyph(image, label.substr(index, 1), Vector2i(start_x + index * (glyph_width + spacing), start_y), unit, LIGHT)


static func _draw_glyph(image: Image, glyph: String, pos: Vector2i, unit: int, color: Color) -> void:
	var rows: PackedStringArray = GLYPHS.get(glyph, PackedStringArray())
	for y in range(rows.size()):
		var row := rows[y]
		for x in range(row.length()):
			if row.substr(x, 1) == "1":
				_fill_rect(image, Rect2i(pos.x + x * unit, pos.y + y * unit, unit, unit), color)


static func _draw_card_back(image: Image, hovered: bool, unit: int, origin: Vector2i) -> void:
	var accent := Color8(117, 100, 79) if hovered else Color8(87, 73, 59)
	var bright := accent.lightened(0.28)
	_grid_rect(image, origin, unit, Rect2i(2, 2, 12, 12), OUTLINE)
	_grid_rect(image, origin, unit, Rect2i(3, 3, 10, 10), accent.darkened(0.18))
	_grid_rect(image, origin, unit, Rect2i(4, 4, 8, 8), accent)
	_grid_rect(image, origin, unit, Rect2i(5, 5, 6, 6), accent.darkened(0.16))
	_grid_rect(image, origin, unit, Rect2i(4, 7, 8, 1), bright)
	_grid_rect(image, origin, unit, Rect2i(4, 10, 8, 1), bright)
	_grid_rect(image, origin, unit, Rect2i(7, 4, 1, 8), bright)
	_grid_rect(image, origin, unit, Rect2i(10, 4, 1, 8), bright)


static func _grid_rect(image: Image, origin: Vector2i, unit: int, rect: Rect2i, color: Color) -> void:
	_fill_rect(
		image,
		Rect2i(
			origin.x + rect.position.x * unit,
			origin.y + rect.position.y * unit,
			rect.size.x * unit,
			rect.size.y * unit
		),
		color
	)


static func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				image.set_pixel(x, y, color)


static func _draw_rounded_rect(image: Image, rect: Rect2i, radius: int, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var local_x: float = x - rect.position.x
			var local_y: float = y - rect.position.y
			var dx: float = max(abs(local_x - (rect.size.x - 1) * 0.5) - (rect.size.x * 0.5 - radius), 0.0)
			var dy: float = max(abs(local_y - (rect.size.y - 1) * 0.5) - (rect.size.y * 0.5 - radius), 0.0)
			if dx * dx + dy * dy <= radius * radius:
				image.set_pixel(x, y, color)
