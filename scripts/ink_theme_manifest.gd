class_name InkThemeManifest
extends Resource

@export var title_text: String = "LIVING\nMAZE"
@export var subtitle_text: String = "Handmarked Escape Circuit"
@export var display_font_names: PackedStringArray = PackedStringArray([
	"Copperplate",
	"Arial Black",
	"Georgia Bold",
])
@export var body_font_names: PackedStringArray = PackedStringArray([
	"Georgia",
	"Avenir Next",
	"Helvetica Neue",
	"Arial",
])
@export var role_accents: Dictionary = {
	"pusher": Color8(229, 89, 66),
	"puller": Color8(224, 171, 87),
	"blocker": Color8(171, 152, 130),
	"redirector": Color8(201, 163, 116),
	"grabber": Color8(180, 106, 86),
	"guide": Color8(216, 169, 97),
	"smuggler": Color8(230, 177, 84),
	"rewinder": Color8(168, 186, 118),
	"killer": Color8(230, 80, 68),
	"undo": Color8(168, 186, 118),
	"step": Color8(212, 171, 114),
	"peek": Color8(214, 196, 140),
	"remote_flip": Color8(224, 134, 78),
	"anchor": Color8(227, 189, 120),
	"flip": Color8(227, 189, 120),
	"daze": Color8(238, 186, 92),
	"reset": Color8(230, 80, 68),
	"status": Color8(239, 227, 196),
	"muted": Color8(171, 152, 130),
	"paper": Color8(233, 218, 189),
	"paper_dark": Color8(201, 181, 153),
	"charcoal": Color8(23, 20, 18),
	"ink": Color8(36, 30, 25),
	"ink_soft": Color8(59, 50, 43),
	"board": Color8(44, 39, 34),
	"shadow": Color8(8, 7, 6, 220),
	"danger": Color8(230, 80, 68),
	"highlight": Color8(247, 207, 127),
	"preview": Color8(255, 229, 160),
	"structure": Color8(151, 142, 130),
	"gate": Color8(225, 174, 88),
	"hub": Color8(227, 190, 105),
	"conduit": Color8(212, 170, 102),
	"anchor_node": Color8(197, 181, 154),
}
@export var role_labels: Dictionary = {
	"pusher": "PUSHER",
	"puller": "PULLER",
	"blocker": "BLOCKER",
	"redirector": "REDIRECTOR",
	"grabber": "GRABBER",
	"guide": "GUIDE",
	"smuggler": "SMUGGLER",
	"rewinder": "REWINDER",
	"killer": "KILLER",
}
@export var role_portrait_assets: Dictionary = {
	"pusher": "pusher",
	"blocker": "guard",
	"redirector": "redirector",
	"grabber": "anchor",
	"guide": "revealer",
	"smuggler": "smuggler",
	"rewinder": "rewinder",
	"killer": "chaser",
}
@export var player_portrait_asset: String = "player"
@export var action_labels: Dictionary = {
	"flip": "REVEAL",
	"peek": "OBSERVE",
	"step": "STEP",
	"anchor": "ANCHOR",
	"undo": "UNDO",
	"remote_flip": "REMOTE FLIP",
	"daze": "DAZE",
	"reset": "RESET RUN",
}
@export var structure_labels: Dictionary = {
	"conduit": "CONDUIT",
	"gate": "GATE",
	"anchor_node": "ANCHOR NODE",
	"hub": "HUB",
}


func get_color(id: String, fallback: Color = Color.WHITE) -> Color:
	return Color(role_accents.get(id, fallback))


func get_role_meta(role_id: String) -> Dictionary:
	return {
		"accent_color": get_color(role_id, get_color("paper_dark")),
		"portrait_asset_id": get_role_portrait_asset_id(role_id),
		"legend_icon_id": role_id,
		"log_icon_id": role_id,
		"silhouette_asset_id": "%s_shadow" % role_id,
		"display_label": String(role_labels.get(role_id, role_id.capitalize())),
	}


func get_role_portrait_asset_id(role_id: String) -> String:
	return String(role_portrait_assets.get(role_id, role_id))


func get_player_portrait_asset_id() -> String:
	return player_portrait_asset


func get_portrait_asset_path(asset_id: String) -> String:
	return "res://assets/portraits/individual/%s.png" % asset_id


func get_action_meta(action_id: String) -> Dictionary:
	return {
		"accent_color": get_color(action_id, get_color("highlight")),
		"action_glyph_id": action_id,
		"display_label": String(action_labels.get(action_id, action_id.replace("_", " ").to_upper())),
	}
