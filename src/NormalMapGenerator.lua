local AsepriteLayerUtils = require("src.AsepriteLayerUtils")
local TextureMapUtils = require("src.TextureMapUtils")

local NormalMapGenerator = {}

local DEFAULT_EDGE_STRENGTH = 1.0
local DEFAULT_LAYER_SHAPE = "Convex"
local LAYER_SHAPES = { "Convex", "Concave" }

-- retain the public entry point used by existing callers and unit tests.
NormalMapGenerator.sobel_normal = TextureMapUtils.sobel_normal

local function show_alert(text)
	app.alert({
		title = "Generate Normal Map",
		text = text,
	})
end

---@param plugin Plugin
function NormalMapGenerator:show_dialog(plugin)
	local sprite = app.sprite
	if not sprite then
		show_alert("Open a sprite before generating a normal map.")
		return
	end
	if sprite.colorMode ~= ColorMode.RGB then
		show_alert("Normal maps require an RGB sprite.")
		return
	end

	local options, option_layers = AsepriteLayerUtils.layer_options(sprite)
	if #options == 0 then
		show_alert("The sprite does not contain any image layers.")
		return
	end

	self.pref = plugin.preferences
	self.sprite = sprite
	self.option_layers = option_layers

	local selected_layers_are_input = self.pref.selected_layers_are_input
	if selected_layers_are_input == nil then
		selected_layers_are_input = true
	end

	local edge_strength = tonumber(self.pref.edge_strength) or DEFAULT_EDGE_STRENGTH
	if not TextureMapUtils.valid_strength(edge_strength) then
		edge_strength = DEFAULT_EDGE_STRENGTH
	end

	local layer_shape = self.pref.layer_shape
	if not TextureMapUtils.valid_layer_shape(layer_shape, LAYER_SHAPES) then
		layer_shape = DEFAULT_LAYER_SHAPE
	end

	local input_option = AsepriteLayerUtils.selected_option(options, option_layers, self.pref.input_layers, app.layer)

	self.dialog_box = Dialog({
		title = "Generate Normal Map",
		onclose = function()
			local data = self.dialog_box.data
			self.pref.input_layers = data.input_layers
			self.pref.selected_layers_are_input = data.selected_layers_are_input
			self.pref.layer_shape = data.layer_shape
			self.pref.edge_strength = data.edge_strength
		end,
	})

	self.dialog_box
		:separator({ id = "normal_map_layers_separator", text = "Layers" })
		:combobox({
			id = "input_layers",
			label = "Input Layers",
			options = options,
			option = input_option,
			enabled = not selected_layers_are_input,
		})
		:check({
			id = "selected_layers_are_input",
			text = "Selected Layers Are Input",
			selected = selected_layers_are_input,
			onclick = function()
				self.dialog_box:modify({
					id = "input_layers",
					enabled = not self.dialog_box.data.selected_layers_are_input,
				})
			end,
		})
		:combobox({
			id = "layer_shape",
			label = "Layer Shape",
			options = LAYER_SHAPES,
			option = layer_shape,
		})
		:number({
			id = "edge_strength",
			label = "Edge Strength",
			text = tostring(edge_strength),
			decimals = 2,
		})
		:button({
			id = "generate_normal_map",
			text = "Generate",
			focus = true,
			onclick = function()
				self:generate_from_dialog()
			end,
		})

	self.dialog_box:show({
		wait = false,
		bounds = Rectangle(100, 100, 320, 220),
	})
end

function NormalMapGenerator:generate_from_dialog()
	if app.sprite ~= self.sprite then
		show_alert("Return to the sprite where this dialog was opened and try again.")
		return
	end

	local data = self.dialog_box.data
	local edge_strength = tonumber(data.edge_strength)
	if not TextureMapUtils.valid_strength(edge_strength) then
		show_alert("Edge Strength must be zero or a positive number.")
		return
	end

	local layer_shape = data.layer_shape
	if not TextureMapUtils.valid_layer_shape(layer_shape, LAYER_SHAPES) then
		layer_shape = DEFAULT_LAYER_SHAPE
	end

	local layers

	if data.selected_layers_are_input then
		layers = AsepriteLayerUtils.selected_layers(app.range, app.layer)
	else
		local input_layer = self.option_layers[data.input_layers]
		layers = input_layer and { input_layer } or {}
	end

	local ordered_layers = AsepriteLayerUtils.ordered_image_layers(self.sprite, layers)
	if #ordered_layers == 0 then
		show_alert("Select at least one image layer to use as input.")
		return
	end

	local frame_number = app.frame and app.frame.frameNumber or 1
	local generated_layers = {}

	for _, input_layer in ipairs(ordered_layers) do
		-- draw an temp image for the input layer to get the source image for normal map generation
		local source, has_cel = AsepriteLayerUtils.render_layer(self.sprite, input_layer, frame_number)

		if not has_cel then
			show_alert("Layer '" .. input_layer.name .. "' does not contain an image in the active frame.")
			return
		end

		-- generate the normal map
		generated_layers[#generated_layers + 1] = {
			input_layer = input_layer,
			name = input_layer.name .. "_normal",
			image = TextureMapUtils.create_normal_image(source, edge_strength, layer_shape),
		}
	end

	local output_layers = {}
	local active_input_layer = app.layer
	local active_output_layer

	app.transaction("Generate Normal Map", function()
		-- insert from top to bottom so inserting a lower pair cannot separate
		-- a source layer from the normal layer already placed above it
		for index = #generated_layers, 1, -1 do
			local generated_layer = generated_layers[index]
			local output_layer = AsepriteLayerUtils.create_layer_above(
				self.sprite,
				generated_layer.input_layer,
				generated_layer.name,
				generated_layer.image,
				frame_number
			)

			output_layers[#output_layers + 1] = output_layer
			if generated_layer.input_layer == active_input_layer then
				active_output_layer = output_layer
			end
		end
	end)

	-- update app preferences to remember the last used settings for next time
	self.pref.input_layers = data.input_layers
	self.pref.selected_layers_are_input = data.selected_layers_are_input
	self.pref.layer_shape = layer_shape
	self.pref.edge_strength = edge_strength
	app.layer = active_output_layer or output_layers[#output_layers]
	app.refresh()
end

return NormalMapGenerator
