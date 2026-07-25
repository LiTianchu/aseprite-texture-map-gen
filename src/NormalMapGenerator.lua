local TextureMapGenerator = require("src.TextureMapGenerator")
local TextureMapUtils = require("src.TextureMapUtils")

local DEFAULT_EDGE_STRENGTH = 1.0
local DEFAULT_LAYER_SHAPE = "Convex"
local LAYER_SHAPES = { "Convex", "Concave" }

local function valid_layer_shape(layer_shape)
	return TextureMapUtils.valid_layer_shape(layer_shape, LAYER_SHAPES)
end

local function initial_settings(pref)
	local edge_strength = tonumber(pref.edge_strength) or DEFAULT_EDGE_STRENGTH
	if not TextureMapUtils.valid_strength(edge_strength) then
		edge_strength = DEFAULT_EDGE_STRENGTH
	end

	local layer_shape = pref.layer_shape
	if not valid_layer_shape(layer_shape) then
		layer_shape = DEFAULT_LAYER_SHAPE
	end

	return {
		edge_strength = edge_strength,
		layer_shape = layer_shape,
	}
end

local function read_dialog_settings(data)
	local edge_strength = tonumber(data.edge_strength)
	if not TextureMapUtils.valid_strength(edge_strength) then
		return nil, "Edge Intensity must be zero or a positive number."
	end

	local layer_shape = data.layer_shape
	if not valid_layer_shape(layer_shape) then
		layer_shape = DEFAULT_LAYER_SHAPE
	end

	return {
		edge_strength = edge_strength,
		layer_shape = layer_shape,
	}
end

---@class NormalMapGenerator : TextureMapGenerator
local NormalMapGenerator = TextureMapGenerator.new({
	title = "Generate Normal Map",
	display_name = "Normal Map",
	singular_name = "normal map",
	plural_name = "Normal maps",
	indefinite_name = "a normal map",
	layers_separator_id = "normal_map_layers_separator",
	actions_separator_id = "normal_actions",
	generate_button_id = "generate_normal_map",
	regenerate_button_id = "regenerate_normal_map",
	initial_settings = initial_settings,
	read_dialog_settings = read_dialog_settings,
	add_settings_widgets = function(_, dialog_box, settings)
		dialog_box
			:separator({ id = "normal_ground_truth_assumptions", text = "Ground Truth Assumptions" })
			:combobox({
				id = "layer_shape",
				label = "Object Shape",
				options = LAYER_SHAPES,
				option = settings.layer_shape,
			})
			:number({
				id = "edge_strength",
				label = "Edge Intensity (0 = flat)",
				text = tostring(settings.edge_strength),
				decimals = 2,
			})
	end,
	save_dialog_preferences = function(pref, data)
		pref.layer_shape = data.layer_shape
		pref.edge_strength = data.edge_strength
	end,
	save_settings = function(pref, settings)
		pref.layer_shape = settings.layer_shape
		pref.edge_strength = settings.edge_strength
	end,
	create_outputs = function(source, settings, input_layers, is_combined) -- use polymorphic behavior to create outputs
		local name = is_combined and "Combined_normal" or input_layers[1].name .. "_normal"
		return {
			{
				key = "primary",
				name = name,
				image = TextureMapUtils.create_normal_image(source, settings.edge_strength, settings.layer_shape),
			},
		}
	end,
})

return NormalMapGenerator
