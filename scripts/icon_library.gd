class_name IconLibrary
extends RefCounted

static var ICON_NAMES := PackedStringArray([
	"sun",
	"leaf",
	"wave",
	"gem",
	"bolt",
	"moon",
])

static var INK := {
	"sun": Color8(242, 190, 65),
	"leaf": Color8(100, 196, 116),
	"wave": Color8(90, 175, 255),
	"gem": Color8(229, 124, 181),
	"bolt": Color8(255, 232, 113),
	"moon": Color8(164, 149, 230),
}


static func make_icon_texture(icon_id: String, size: int = 16) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var ink: Color = INK.get(icon_id, Color8(255, 255, 255))
	match icon_id:
		"sun":
			_draw_sun(image, ink)
		"leaf":
			_draw_leaf(image, ink)
		"wave":
			_draw_wave(image, ink)
		"gem":
			_draw_gem(image, ink)
		"bolt":
			_draw_bolt(image, ink)
		"moon":
			_draw_moon(image, ink)
		_:
			_draw_gem(image, ink)

	return ImageTexture.create_from_image(image)


static func _draw_sun(image: Image, color: Color) -> void:
	_fill_rect(image, Rect2i(6, 6, 4, 4), color)
	_fill_rect(image, Rect2i(7, 2, 2, 2), color)
	_fill_rect(image, Rect2i(7, 12, 2, 2), color)
	_fill_rect(image, Rect2i(2, 7, 2, 2), color)
	_fill_rect(image, Rect2i(12, 7, 2, 2), color)
	_fill_rect(image, Rect2i(4, 4, 2, 2), color)
	_fill_rect(image, Rect2i(10, 4, 2, 2), color)
	_fill_rect(image, Rect2i(4, 10, 2, 2), color)
	_fill_rect(image, Rect2i(10, 10, 2, 2), color)


static func _draw_leaf(image: Image, color: Color) -> void:
	_fill_rect(image, Rect2i(7, 2, 2, 11), color)
	_fill_rect(image, Rect2i(5, 4, 2, 2), color)
	_fill_rect(image, Rect2i(9, 4, 2, 2), color)
	_fill_rect(image, Rect2i(4, 6, 3, 2), color)
	_fill_rect(image, Rect2i(9, 6, 3, 2), color)
	_fill_rect(image, Rect2i(3, 8, 3, 2), color)
	_fill_rect(image, Rect2i(10, 8, 3, 2), color)
	_fill_rect(image, Rect2i(4, 10, 3, 2), color)
	_fill_rect(image, Rect2i(9, 10, 3, 2), color)


static func _draw_wave(image: Image, color: Color) -> void:
	_fill_rect(image, Rect2i(2, 5, 3, 2), color)
	_fill_rect(image, Rect2i(5, 7, 4, 2), color)
	_fill_rect(image, Rect2i(9, 5, 5, 2), color)
	_fill_rect(image, Rect2i(2, 9, 4, 2), color)
	_fill_rect(image, Rect2i(6, 11, 4, 2), color)
	_fill_rect(image, Rect2i(10, 9, 4, 2), color)


static func _draw_gem(image: Image, color: Color) -> void:
	_fill_rect(image, Rect2i(5, 3, 6, 2), color)
	_fill_rect(image, Rect2i(4, 5, 8, 2), color)
	_fill_rect(image, Rect2i(3, 7, 10, 2), color)
	_fill_rect(image, Rect2i(4, 9, 8, 2), color)
	_fill_rect(image, Rect2i(5, 11, 6, 2), color)
	_fill_rect(image, Rect2i(7, 13, 2, 1), color)


static func _draw_bolt(image: Image, color: Color) -> void:
	_fill_rect(image, Rect2i(7, 2, 2, 4), color)
	_fill_rect(image, Rect2i(5, 5, 3, 2), color)
	_fill_rect(image, Rect2i(7, 7, 2, 3), color)
	_fill_rect(image, Rect2i(8, 9, 3, 2), color)
	_fill_rect(image, Rect2i(6, 11, 2, 3), color)


static func _draw_moon(image: Image, color: Color) -> void:
	_fill_rect(image, Rect2i(6, 3, 4, 2), color)
	_fill_rect(image, Rect2i(4, 5, 4, 2), color)
	_fill_rect(image, Rect2i(3, 7, 4, 2), color)
	_fill_rect(image, Rect2i(3, 9, 4, 2), color)
	_fill_rect(image, Rect2i(4, 11, 4, 2), color)
	_fill_rect(image, Rect2i(6, 13, 4, 1), color)


static func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			image.set_pixel(x, y, color)
