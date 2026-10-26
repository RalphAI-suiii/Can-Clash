extends Control

signal closed

const UI = preload("res://ui/game_ui.gd")
const OVERLAY = preload("res://ui/character_customization/cosmetic_overlay.gd")
const HEADWEAR_MASK := [0.35, 0.0, 0.0, 0.0, 0.32, 0.0, 0.0]
const FRAMES := [
	preload("res://scenes/player_movement_neutral_frames.tres"),
	preload("res://ui/main_menu/menu_idle_band_gesture.tres"),
	preload("res://ui/main_menu/menu_idle_glasses_gesture.tres"),
	preload("res://scenes/Curly_haired_frames.tres"),
	preload("res://scenes/Bullcap_Head_frames.tres"),
	preload("res://scenes/leonardo_preview_frames.tres"),
	preload("res://scenes/kay_preview_frames.tres"),
]
const COLOR_NAMES := ["BLUE", "ORANGE", "GREEN", "PURPLE", "PINK"]

var name_input: LineEdit
var preview_sprite: AnimatedSprite2D
var preview_overlay: Node2D
var preview_ring: Polygon2D
var preview_label: Label
var base_preview_texture: Texture2D
var preview_index := 0
var headwear := 0
var accessory := 0
var color_index := 0
var color_buttons: Array[Button] = []
var headwear_buttons: Array[Button] = []
var accessory_buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	headwear = UserSettings.headwear_index
	accessory = UserSettings.accessory_index
	color_index = UserSettings.player_color_index
	_build()
	_choose_preview(0)
	_refresh_choices()
	name_input.grab_focus()

func _build() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("1b130eeb")
	add_child(shade)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(0, 1010)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(1470, 850)
	card.add_theme_stylebox_override("panel", UI.panel(Color("b84e12"), 8))
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)
	column.add_child(UI.label("CUSTOMIZE YOUR PLAYER", 48))
	column.add_child(UI.label("Try a still look here. Claim your character in the lobby.", 25))
	var halves := HBoxContainer.new()
	halves.add_theme_constant_override("separation", 28)
	halves.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(halves)
	_build_preview(halves)
	_build_choices(halves)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 18)
	column.add_child(footer)
	footer.add_child(UI.button("Back", _close))
	footer.add_child(UI.button("Save Preview", _save))

func _build_preview(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(590, 650)
	panel.add_theme_stylebox_override("panel", UI.panel(Color("ffe9a7"), 6))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(UI.label("LIVE PREVIEW", 30))
	var viewport_box := SubViewportContainer.new()
	viewport_box.custom_minimum_size = Vector2(530, 505)
	viewport_box.stretch = true
	column.add_child(viewport_box)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(530, 505)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_box.add_child(viewport)
	var stage := Node2D.new()
	stage.position = Vector2(265, 455)
	stage.scale = Vector2.ONE * 1.55
	viewport.add_child(stage)
	var shadow := Polygon2D.new()
	shadow.color = Color("4d311754")
	shadow.polygon = PackedVector2Array([Vector2(-95, 0), Vector2(-72, -16), Vector2(0, -21), Vector2(72, -16), Vector2(95, 0), Vector2(72, 14), Vector2(0, 20), Vector2(-72, 14)])
	stage.add_child(shadow)
	preview_ring = Polygon2D.new()
	preview_ring.polygon = PackedVector2Array([Vector2(-80, 0), Vector2(-54, -16), Vector2(0, -22), Vector2(54, -16), Vector2(80, 0), Vector2(54, 16), Vector2(0, 22), Vector2(-54, 16)])
	stage.add_child(preview_ring)
	preview_sprite = AnimatedSprite2D.new()
	stage.add_child(preview_sprite)
	preview_overlay = OVERLAY.new()
	preview_overlay.set("body_sprite", preview_sprite)
	stage.add_child(preview_overlay)
	var chooser := HBoxContainer.new()
	chooser.alignment = BoxContainer.ALIGNMENT_CENTER
	chooser.add_theme_constant_override("separation", 12)
	column.add_child(chooser)
	chooser.add_child(UI.button("<", func() -> void: _choose_preview(preview_index - 1)))
	preview_label = UI.label("", 22)
	preview_label.custom_minimum_size = Vector2(235, 50)
	chooser.add_child(preview_label)
	chooser.add_child(UI.button(">", func() -> void: _choose_preview(preview_index + 1)))
	for child in chooser.get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(65, 55)

func _build_choices(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UI.panel(Color("713612"), 5))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(UI.label("PLAYER NAME", 26))
	name_input = LineEdit.new()
	name_input.max_length = 20
	name_input.custom_minimum_size = Vector2(0, 62)
	name_input.text = UserSettings.display_name
	column.add_child(name_input)
	column.add_child(UI.label("PLAYER MARKER COLOR", 26))
	var colors := HBoxContainer.new()
	colors.alignment = BoxContainer.ALIGNMENT_CENTER
	colors.add_theme_constant_override("separation", 9)
	column.add_child(colors)
	for index in range(LanSession.COLORS.size()):
		var button := UI.button(COLOR_NAMES[index], _choose_color.bind(index))
		button.custom_minimum_size = Vector2(126, 64)
		button.add_theme_font_size_override("font_size", 16)
		colors.add_child(button)
		color_buttons.append(button)
	column.add_child(UI.label("HEADWEAR", 26))
	var hats := HBoxContainer.new()
	hats.alignment = BoxContainer.ALIGNMENT_CENTER
	hats.add_theme_constant_override("separation", 12)
	column.add_child(hats)
	for index in 2:
		var button := UI.button("No Hat" if index == 0 else "Duck Hat", _choose_headwear.bind(index))
		button.custom_minimum_size = Vector2(290, 82)
		button.icon = preload("res://assets/ui/cosmetics/duck_hat.svg") if index == 1 else null
		button.expand_icon = true
		hats.add_child(button)
		headwear_buttons.append(button)
	column.add_child(UI.label("ACCESSORY", 26))
	var accessories := HBoxContainer.new()
	accessories.alignment = BoxContainer.ALIGNMENT_CENTER
	accessories.add_theme_constant_override("separation", 10)
	column.add_child(accessories)
	for index in 3:
		var names := ["None", "Bow", "Scarf"]
		var button := UI.button(names[index], _choose_accessory.bind(index))
		button.custom_minimum_size = Vector2(190, 82)
		if index == 1: button.icon = preload("res://assets/ui/cosmetics/bow.svg")
		if index == 2: button.icon = preload("res://assets/ui/cosmetics/scarf.svg")
		button.expand_icon = true
		accessories.add_child(button)
		accessory_buttons.append(button)
	var note := UI.label("Preview only: accessories are not used during play yet.", 20)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)

func _choose_preview(index: int) -> void:
	preview_index = posmod(index, FRAMES.size())
	preview_overlay.call("set_character_index", preview_index)
	var source: SpriteFrames = FRAMES[preview_index]
	if preview_index == 1 or preview_index == 2:
		base_preview_texture = source.get_frame_texture(&"idle", 0)
	elif preview_index == 3:
		base_preview_texture = source.get_frame_texture(&"idle_throw_down", 0)
	else:
		base_preview_texture = source.get_frame_texture(&"idle_down", 0)
	preview_sprite.position = Vector2(0, -99 if preview_index == 0 else -104)
	var preview_scale := 0.7 if preview_index == 0 else (0.64 if preview_index == 1 or preview_index == 2 else 0.5 if preview_index >= 5 else 0.85)
	preview_sprite.scale = Vector2.ONE * preview_scale
	_update_preview_image()
	preview_label.text = LanSession.CHARACTERS[preview_index]

func _update_preview_image() -> void:
	var texture := base_preview_texture
	if headwear == 1 and HEADWEAR_MASK[preview_index] > 0.0:
		var image: Image = OVERLAY.source_image(base_preview_texture)
		image.convert(Image.FORMAT_RGBA8)
		var bounds: Rect2 = OVERLAY.painted_bounds(image)
		var cut_y := mini(image.get_height(), ceili(bounds.position.y + bounds.size.y * float(HEADWEAR_MASK[preview_index])))
		image.fill_rect(Rect2i(0, 0, image.get_width(), cut_y), Color.TRANSPARENT)
		texture = ImageTexture.create_from_image(image)
	var still := SpriteFrames.new()
	still.add_animation(&"preview")
	still.add_frame(&"preview", texture)
	preview_sprite.sprite_frames = still
	preview_sprite.animation = &"preview"
	preview_sprite.stop()
	preview_sprite.frame = 0
	preview_overlay.call("set_reference_texture", base_preview_texture)

func _choose_color(index: int) -> void:
	color_index = index
	_refresh_choices()

func _choose_headwear(index: int) -> void:
	headwear = index
	_update_preview_image()
	_refresh_choices()

func _choose_accessory(index: int) -> void:
	accessory = index
	_refresh_choices()

func _refresh_choices() -> void:
	preview_ring.color = LanSession.COLORS[color_index]
	preview_overlay.call("set_items", headwear, accessory)
	for i in color_buttons.size():
		var style: StyleBoxFlat = UI.panel(LanSession.COLORS[i], 6 if i == color_index else 3)
		style.border_color = Color("fff5c4") if i == color_index else Color("20130f")
		color_buttons[i].add_theme_stylebox_override("normal", style)
	_mark_choice(headwear_buttons, headwear)
	_mark_choice(accessory_buttons, accessory)

func _mark_choice(buttons: Array[Button], selected_index: int) -> void:
	for i in buttons.size():
		var chosen: bool = i == selected_index
		var style: StyleBoxFlat = UI.panel(Color("efaa36") if chosen else Color("8f552a"), 5 if chosen else 3)
		style.border_color = Color("fff4b7") if chosen else Color("20130f")
		buttons[i].add_theme_stylebox_override("normal", style)

func _save() -> void:
	UserSettings.set_display_name(name_input.text)
	UserSettings.set_player_color_index(color_index)
	UserSettings.set_cosmetics(headwear, accessory)
	_close()

func _close() -> void:
	closed.emit()
	queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
