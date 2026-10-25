extends Node2D

# The customization preview is a still image. These anchors are deliberately
# local to it; match sprites are never changed by this script.
const DUCK := preload("res://assets/ui/cosmetics/duck_hat.svg")
const BOW := preload("res://assets/ui/cosmetics/bow.svg")
const SCARF := preload("res://assets/ui/cosmetics/scarf.svg")
const DUCK_WIDTH := [1.03, 0.70, 0.70, 0.72, 0.72]
const DUCK_HEIGHT := [0.35, 0.35, 0.34, 0.35, 0.34]
const NECK_Y := [0.52, 0.58, 0.56, 0.58, 0.50]

var body_sprite: AnimatedSprite2D
var reference_texture: Texture2D
var headwear := 0
var accessory := 0
var character_index := 0
var hat: Sprite2D
var extra: Sprite2D

func _ready() -> void:
	hat = Sprite2D.new()
	hat.texture = DUCK
	extra = Sprite2D.new()
	add_child(hat)
	add_child(extra)
	update_fit()

func set_items(new_headwear: int, new_accessory: int) -> void:
	headwear = clampi(new_headwear, 0, 1)
	accessory = clampi(new_accessory, 0, 2)
	if is_inside_tree():
		update_fit()

func set_character_index(index: int) -> void:
	character_index = clampi(index, 0, 4)

func set_reference_texture(texture: Texture2D) -> void:
	reference_texture = texture
	if is_inside_tree():
		update_fit()

func update_fit() -> void:
	hat.visible = headwear == 1
	extra.visible = accessory != 0
	if not is_instance_valid(body_sprite) or reference_texture == null:
		return
	var image := source_image(reference_texture)
	var bounds := painted_bounds(image)
	var frame_center := reference_texture.get_size() * 0.5
	var scale_x := absf(body_sprite.scale.x)
	var scale_y := absf(body_sprite.scale.y)
	var center_x := (bounds.position.x + bounds.size.x * 0.5 - frame_center.x) * scale_x
	var top_y := (bounds.position.y - frame_center.y) * scale_y
	var width := bounds.size.x * scale_x
	var height := bounds.size.y * scale_y
	var duck_height: float = height * DUCK_HEIGHT[character_index]
	hat.position = body_sprite.position + Vector2(center_x, top_y + duck_height * 0.5)
	hat.scale = Vector2(width * DUCK_WIDTH[character_index] / 104.0, duck_height / 77.0)
	if accessory == 1:
		extra.texture = BOW
		extra.position = body_sprite.position + Vector2(center_x + width * 0.25, top_y + height * 0.25)
		extra.scale = Vector2(width * 0.22 / 90.0, height * 0.14 / 60.0)
	elif accessory == 2:
		extra.texture = SCARF
		extra.position = body_sprite.position + Vector2(center_x, top_y + height * NECK_Y[character_index])
		extra.scale = Vector2(width * 0.38 / 76.0, height * 0.12 / 62.0)

static func source_image(texture: Texture2D) -> Image:
	if texture is AtlasTexture:
		var atlas_frame := texture as AtlasTexture
		var region := atlas_frame.region
		return atlas_frame.atlas.get_image().get_region(Rect2i(Vector2i(region.position), Vector2i(region.size)))
	return texture.get_image()

static func painted_bounds(image: Image) -> Rect2:
	# Sprite sheets have faint pixels outside the outline. Ignore those so sizes
	# follow the character's real silhouette instead of the atlas cell.
	var left := image.get_width()
	var top := image.get_height()
	var right := -1
	var bottom := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.1:
				continue
			left = mini(left, x)
			top = mini(top, y)
			right = maxi(right, x)
			bottom = maxi(bottom, y)
	if right < left:
		return Rect2(Vector2.ZERO, Vector2(image.get_size()))
	return Rect2(Vector2(left, top), Vector2(right - left + 1, bottom - top + 1))
