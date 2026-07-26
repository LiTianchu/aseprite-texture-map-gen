local TextureMapGenerator = require("src.TextureMapGenerator")
local TextureMapUtils = require("src.TextureMapUtils")

local DEFAULT_MAX_COLOR_VALUE_LEVELS = 16
local MAX_COLOR_VALUE_LEVELS_CAP = 256
local DEFAULT_EDGE_STRENGTH = 1.0
local DEFAULT_LAYER_SHAPE = "Convex"
local LAYER_SHAPES = { "Convex", "Concave" }

---@param pref table The preferences table containing saved settings from Aseprite Plugin
---@return NormalMapGenerationSettings settings initial settings for the normal map generator
local function parse_pref_settings(pref)
	local edge_strength = tonumber(pref.edge_strength) or DEFAULT_EDGE_STRENGTH
	if not TextureMapUtils.valid_strength(edge_strength) then
		edge_strength = DEFAULT_EDGE_STRENGTH
	end

	local layer_shape = pref.layer_shape
	if not TextureMapUtils.valid_layer_shape(layer_shape, LAYER_SHAPES) then
		layer_shape = DEFAULT_LAYER_SHAPE
	end

	local max_color_value_levels = pref.max_color_value_levels
	if not TextureMapUtils.valid_color_value_levels(max_color_value_levels, MAX_COLOR_VALUE_LEVELS_CAP) then
		max_color_value_levels = DEFAULT_MAX_COLOR_VALUE_LEVELS
	end

	return {
		selected_layers_are_input = pref.selected_layers_are_input ~= false,
		separate_layers = pref.separate_layers ~= false,
		input_layer = pref.input_layer,
		edge_strength = edge_strength,
		layer_shape = layer_shape,
		max_color_value_levels = max_color_value_levels,
	}
end

---@param data NormalMapGenerationSettings The data table containing settings to be validated
---@return NormalMapGenerationSettings|nil settings The validated settings for the normal map generator, or nil if invalid
---@return string|nil error_message An error message if the settings are invalid, or nil if valid
local function sanitize_dialog_settings(data)
	local selected_layers_are_input = data.selected_layers_are_input
	local separate_layers = data.separate_layers

	local edge_strength = tonumber(data.edge_strength) or DEFAULT_EDGE_STRENGTH
	if not TextureMapUtils.valid_strength(edge_strength) then
		return nil, "Edge Intensity must be zero or a positive number."
	end

	local layer_shape = data.layer_shape
	if not TextureMapUtils.valid_layer_shape(layer_shape, LAYER_SHAPES) then
		layer_shape = DEFAULT_LAYER_SHAPE
	end

	local max_color_value_levels = data.max_color_value_levels
	if not TextureMapUtils.valid_color_value_levels(max_color_value_levels, MAX_COLOR_VALUE_LEVELS_CAP) then
		max_color_value_levels = DEFAULT_MAX_COLOR_VALUE_LEVELS
	end
	return {
		selected_layers_are_input = selected_layers_are_input,
		separate_layers = separate_layers,
		input_layer = data.input_layer,
		edge_strength = edge_strength,
		layer_shape = layer_shape,
		max_color_value_levels = max_color_value_levels,
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
	parse_pref_settings = parse_pref_settings,
	sanitize_dialog_settings = sanitize_dialog_settings,
	add_settings_widgets = function(_, dialog_box, settings)
		if not settings then
			settings = parse_pref_settings({})
		end
		---@cast settings NormalMapGenerationSettings

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
			:separator({ id = "normal_map_gen_settings", text = "Normal Map Generation Settings" })
			:number({
				id = "max_color_value_levels",
				label = "Color Value Levels (1-" .. MAX_COLOR_VALUE_LEVELS_CAP .. ")",
				text = tostring(settings.max_color_value_levels),
				decimals = 0,
				hexpand = true,
			})
			:newrow()
	end,
	save_dialog_preferences = function(pref, data)
		pref.layer_shape = data.layer_shape
		pref.edge_strength = data.edge_strength
		pref.max_color_value_levels = data.max_color_value_levels
	end,
	save_settings = function(pref, settings)
		if not settings then
			settings = parse_pref_settings(pref)
		end

		---@cast settings NormalMapGenerationSettings
		pref.layer_shape = settings.layer_shape
		pref.edge_strength = settings.edge_strength
		pref.max_color_value_levels = settings.max_color_value_levels
	end,
	create_outputs = function(source, settings, input_layers, is_combined) -- use polymorphic behavior to create outputs
		if not settings then
			settings = parse_pref_settings({})
		end

		---@cast settings NormalMapGenerationSettings
		local name = is_combined and "Combined_normal" or input_layers[1].name .. "_normal"
		---@type GenerationJobOutput[]
		local outputs = {
			{
				key = "primary",
				content = {
					name = name,
					image = TextureMapUtils.create_normal_image(source, settings.edge_strength, settings.layer_shape),
				},
			},
		}
		return outputs
	end,
})

return NormalMapGenerator
