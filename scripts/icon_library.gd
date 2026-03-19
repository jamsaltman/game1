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
	"pusher": Color8(88, 196, 255),
	"puller": Color8(124, 230, 145),
	"blocker": Color8(214, 183, 95),
	"redirector": Color8(240, 145, 97),
	"grabber": Color8(220, 116, 171),
	"guide": Color8(123, 188, 255),
	"smuggler": Color8(169, 220, 112),
	"killer": Color8(255, 101, 101),
}

static var FACE_BG_FRONT := Color8(245, 240, 222)
static var FACE_BG_BACK := Color8(29, 35, 44)
static var FACE_BG_FRONT_HOVER := Color8(255, 248, 233)
static var FACE_BG_BACK_HOVER := Color8(47, 55, 70)


static func make_face_texture(icon_id: String, is_front: bool, hovered: bool = false, size: int = 18) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var face_color := FACE_BG_FRONT if is_front else FACE_BG_BACK
	if hovered:
		face_color = FACE_BG_FRONT_HOVER if is_front else FACE_BG_BACK_HOVER

	_draw_rounded_rect(image, Rect2i(1, 1, size - 2, size - 2), 3, face_color)
	if is_front:
		var ink: Color = INK.get(icon_id, Color8(255, 255, 255))
		_draw_front_frame(image, ink)
		_draw_role_icon(image, icon_id, ink)
	else:
		_draw_card_back(image, hovered)

	return ImageTexture.create_from_image(image)


static func _draw_role_icon(image: Image, icon_id: String, color: Color) -> void:
	match icon_id:
		"pusher":
			_fill_rect(image, Rect2i(3, 7, 7, 2), color)
			_fill_rect(image, Rect2i(8, 5, 4, 2), color)
			_fill_rect(image, Rect2i(10, 3, 3, 2), color)
			_fill_rect(image, Rect2i(10, 11, 3, 2), color)
		"puller":
			_fill_rect(image, Rect2i(6, 7, 7, 2), color)
			_fill_rect(image, Rect2i(4, 5, 4, 2), color)
			_fill_rect(image, Rect2i(3, 3, 3, 2), color)
			_fill_rect(image, Rect2i(3, 11, 3, 2), color)
		"blocker":
			_fill_rect(image, Rect2i(4, 4, 8, 8), color)
			_fill_rect(image, Rect2i(6, 6, 4, 4), FACE_BG_FRONT)
		"redirector":
			_fill_rect(image, Rect2i(4, 4, 6, 2), color)
			_fill_rect(image, Rect2i(8, 4, 2, 7), color)
			_fill_rect(image, Rect2i(8, 9, 4, 2), color)
			_fill_rect(image, Rect2i(10, 8, 2, 4), color)
		"grabber":
			_fill_rect(image, Rect2i(4, 4, 2, 8), color)
			_fill_rect(image, Rect2i(7, 4, 2, 8), color)
			_fill_rect(image, Rect2i(10, 4, 2, 8), color)
			_fill_rect(image, Rect2i(4, 10, 8, 2), color)
		"guide":
			_fill_rect(image, Rect2i(5, 3, 6, 2), color)
			_fill_rect(image, Rect2i(4, 5, 8, 6), color)
			_fill_rect(image, Rect2i(6, 7, 4, 2), FACE_BG_FRONT)
			_fill_rect(image, Rect2i(7, 12, 2, 2), color)
		"smuggler":
			_fill_rect(image, Rect2i(4, 5, 8, 6), color)
			_fill_rect(image, Rect2i(6, 7, 4, 2), FACE_BG_FRONT)
			_fill_rect(image, Rect2i(11, 4, 2, 4), color)
			_fill_rect(image, Rect2i(9, 3, 4, 2), color)
		"killer":
			_fill_rect(image, Rect2i(4, 4, 3, 3), color)
			_fill_rect(image, Rect2i(10, 4, 3, 3), color)
			_fill_rect(image, Rect2i(6, 10, 4, 2), color)
			_fill_rect(image, Rect2i(4, 12, 8, 2), color)
		_:
			_fill_rect(image, Rect2i(5, 5, 6, 6), color)


static func _draw_card_back(image: Image, hovered: bool) -> void:
	var accent := Color8(84, 94, 118) if hovered else Color8(61, 71, 90)
	_fill_rect(image, Rect2i(3, 3, 10, 1), accent)
	_fill_rect(image, Rect2i(3, 13, 10, 1), accent)
	_fill_rect(image, Rect2i(3, 4, 1, 9), accent)
	_fill_rect(image, Rect2i(12, 4, 1, 9), accent)
	_fill_rect(image, Rect2i(5, 5, 8, 1), accent)
	_fill_rect(image, Rect2i(5, 8, 8, 1), accent)
	_fill_rect(image, Rect2i(5, 11, 8, 1), accent)
	_fill_rect(image, Rect2i(7, 3, 4, 1), accent)
	_fill_rect(image, Rect2i(7, 13, 4, 1), accent)


static func _draw_front_frame(image: Image, color: Color) -> void:
	_fill_rect(image, Rect2i(3, 3, 10, 1), color)
	_fill_rect(image, Rect2i(3, 13, 10, 1), color)
	_fill_rect(image, Rect2i(3, 4, 1, 9), color)
	_fill_rect(image, Rect2i(12, 4, 1, 9), color)
	_fill_rect(image, Rect2i(5, 5, 6, 6), color.darkened(0.55))


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
