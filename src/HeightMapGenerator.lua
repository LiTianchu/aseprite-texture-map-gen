local TextureMapGenerator = require("src.TextureMapGenerator")
local TextureMapUtils = require("src.TextureMapUtils")

local DEFAULT_EDGE_STRENGTH = 32.0
local DEFAULT_MAX_ITERATION_COUNT = 128
local DEFAULT_MAX_COLOR_VALUE_LEVELS = 16
local MAX_COLOR_VALUE_LEVELS_CAP = 256
local MAX_ITERATION_COUNT_CAP = 512
local DEFAULT_INPUT_TYPE = "Color"
local INPUT_TYPES = { "Color", "Normal Map" }
local DEFAULT_LAYER_SHAPE = "Convex"
local LAYER_SHAPES = { "Convex", "Concave" }

---@param value string The input type to validate
---@param options string[] The list of valid input types
---@return boolean is_valid True if the input type is valid, false otherwise
local function valid_input_type(value, options)
	for _, input_type in ipairs(options) do
		if value == input_type then
			return true
		end
	end
	return false
end

---@param pref table The preferences table containing saved settings from Aseprite Plugin
---@return HeightMapGenerationSettings settings initial settings for the height map generator
local function parse_pref_settings(pref)
	local edge_strength = tonumber(pref.height_edge_strength) or DEFAULT_EDGE_STRENGTH
	if not TextureMapUtils.valid_strength(edge_strength) then
		edge_strength = DEFAULT_EDGE_STRENGTH
	end

	local max_iteration_count = tonumber(pref.height_max_iteration_count) or DEFAULT_MAX_ITERATION_COUNT
	if not TextureMapUtils.valid_iteration_count(max_iteration_count, MAX_ITERATION_COUNT_CAP) then
		max_iteration_count = DEFAULT_MAX_ITERATION_COUNT
	end

	local input_type = pref.input_type
	if not valid_input_type(input_type, INPUT_TYPES) then
		input_type = DEFAULT_INPUT_TYPE
	end

	local layer_shape = pref.height_layer_shape
	if not TextureMapUtils.valid_layer_shape(layer_shape, LAYER_SHAPES) then
		layer_shape = DEFAULT_LAYER_SHAPE
	end

	local dump_intermediate_normal_map = pref.height_dump_intermediate_normal_map
	if dump_intermediate_normal_map == nil then
		dump_intermediate_normal_map = false
	end

	local max_color_value_levels = tonumber(pref.height_max_color_value_levels) or DEFAULT_MAX_COLOR_VALUE_LEVELS
	if not TextureMapUtils.valid_color_value_levels(max_color_value_levels, MAX_COLOR_VALUE_LEVELS_CAP) then
		max_color_value_levels = DEFAULT_MAX_COLOR_VALUE_LEVELS
	end

	---@type HeightMapGenerationSettings
	local settings = {
		selected_layers_are_input = pref.selected_layers_are_input ~= false,
		separate_layers = pref.separate_layers ~= false,
		input_layer = pref.input_layer,
		edge_strength = edge_strength,
		max_iteration_count = max_iteration_count,
		input_type = input_type,
		layer_shape = layer_shape,
		dump_intermediate_normal_map = dump_intermediate_normal_map,
		max_color_value_levels = max_color_value_levels,
	}
	return settings
end

---@param data HeightMapDialogData The dialog data containing settings to be validated
---@return HeightMapGenerationSettings|nil settings The validated settings for the height map generator, or nil if invalid
---@return string|nil error_message An error message if the settings are invalid,
local function sanitize_dialog_settings(data)
	local selected_layers_are_input = data.selected_layers_are_input
	local separate_layers = data.separate_layers

	local edge_strength = tonumber(data.edge_strength) or DEFAULT_EDGE_STRENGTH
	if not TextureMapUtils.valid_strength(edge_strength) then
		return nil, "Edge Intensity must be zero or a positive number."
	end

	local max_iteration_count = tonumber(data.height_max_iteration_count) or DEFAULT_MAX_ITERATION_COUNT
	if not TextureMapUtils.valid_iteration_count(max_iteration_count, MAX_ITERATION_COUNT_CAP) then
		return nil, "Max Iterations must be a whole number from 1 to " .. MAX_ITERATION_COUNT_CAP .. "."
	end

	local input_type = data.input_type
	if not valid_input_type(input_type, INPUT_TYPES) then
		input_type = DEFAULT_INPUT_TYPE
	end

	local layer_shape = data.layer_shape
	if not TextureMapUtils.valid_layer_shape(layer_shape, LAYER_SHAPES) then
		layer_shape = DEFAULT_LAYER_SHAPE
	end

	local max_color_value_levels = tonumber(data.height_max_color_value_levels) or DEFAULT_MAX_COLOR_VALUE_LEVELS
	if not TextureMapUtils.valid_color_value_levels(max_color_value_levels, MAX_COLOR_VALUE_LEVELS_CAP) then
		max_color_value_levels = DEFAULT_MAX_COLOR_VALUE_LEVELS
	end

	---@type HeightMapGenerationSettings
	local sanized_dialog_settings = {
		selected_layers_are_input = selected_layers_are_input,
		separate_layers = separate_layers,
		input_layer = data.input_layer,
		edge_strength = edge_strength,
		max_iteration_count = max_iteration_count,
		input_type = input_type,
		layer_shape = layer_shape,
		dump_intermediate_normal_map = input_type == "Color" and data.dump_intermediate_normal_map == true,
		max_color_value_levels = max_color_value_levels,
	}

	return sanized_dialog_settings
end

---@class HeightMapGenerator : TextureMapGenerator
local HeightMapGenerator = TextureMapGenerator.new({
	title = "Generate Height Map",
	display_name = "Height Map",
	singular_name = "height map",
	plural_name = "Height maps",
	indefinite_name = "a height map",
	layers_separator_id = "height_map_layers_separator",
	actions_separator_id = "height_actions",
	generate_button_id = "generate_height_map",
	regenerate_button_id = "regenerate_height_map",
	parse_pref_settings = parse_pref_settings,
	sanitize_dialog_settings = sanitize_dialog_settings,
	add_settings_widgets = function(generator, dialog_box, settings)
		if settings == nil then
			settings = parse_pref_settings({})
		end
		---@cast settings HeightMapGenerationSettings
		local color_input = settings.input_type == "Color"

		local function update_input_type_controls()
			local is_color = dialog_box.data.input_type == "Color"
			dialog_box:modify({
				id = "layer_shape",
				enabled = is_color,
			})
			dialog_box:modify({
				id = "dump_intermediate_normal_map",
				enabled = is_color,
			})
		end

		dialog_box
			:separator({ id = "height_input_format", text = "Input Format" })
			:combobox({
				id = "input_type",
				label = "Treat Layers As",
				options = INPUT_TYPES,
				option = settings.input_type,
				hexpand = true,
				onchange = function()
					update_input_type_controls()
					generator:invalidate_regeneration()
				end,
			})
			:newrow()
			:separator({ id = "height_ground_truth_assumptions", text = "Ground Truth Assumptions" })
			:combobox({
				id = "layer_shape",
				label = "Object Shape",
				options = LAYER_SHAPES,
				option = settings.layer_shape,
				enabled = color_input,
				hexpand = true,
			})
			:newrow()
			:number({
				id = "edge_strength",
				label = "Edge Intensity (0 = flat)",
				text = tostring(settings.edge_strength),
				decimals = 2,
				hexpand = true,
			})
			:newrow()
			:separator({ id = "height_map_gen_settings", text = "Height Map Generation Settings" })
			:check({
				id = "dump_intermediate_normal_map",
				label = "Intermediate Output",
				text = "Keep Intermediate Normal Map",
				selected = settings.dump_intermediate_normal_map,
				enabled = color_input,
				onclick = function()
					generator:invalidate_regeneration()
				end,
			})
			:newrow()
			:number({
				id = "height_max_iteration_count",
				label = "Max Iterations (1-" .. MAX_ITERATION_COUNT_CAP .. ")",
				text = tostring(settings.max_iteration_count),
				decimals = 0,
				hexpand = true,
			})
			:newrow()
			:number({
				id = "height_max_color_value_levels",
				label = "Color Value Levels (1-" .. MAX_COLOR_VALUE_LEVELS_CAP .. ")",
				text = tostring(settings.max_color_value_levels),
				decimals = 0,
				hexpand = true,
			})
	end,
	save_dialog_preferences = function(pref, data)
		---@cast data HeightMapDialogData
		pref.input_type = data.input_type
		pref.height_dump_intermediate_normal_map = data.dump_intermediate_normal_map
		pref.height_layer_shape = data.layer_shape
		pref.height_edge_strength = data.edge_strength
		pref.height_max_iteration_count = data.height_max_iteration_count
		pref.height_max_color_value_levels = data.height_max_color_value_levels
	end,
	save_settings = function(pref, settings)
		if not settings then
			settings = parse_pref_settings(pref)
		end

		---@cast settings HeightMapGenerationSettings

		pref.input_type = settings.input_type or DEFAULT_INPUT_TYPE
		pref.height_dump_intermediate_normal_map = settings.dump_intermediate_normal_map or false
		pref.height_layer_shape = settings.layer_shape or DEFAULT_LAYER_SHAPE
		pref.height_edge_strength = settings.edge_strength or DEFAULT_EDGE_STRENGTH
		pref.height_max_iteration_count = settings.max_iteration_count or DEFAULT_MAX_ITERATION_COUNT
		pref.height_max_color_value_levels = settings.max_color_value_levels or DEFAULT_MAX_COLOR_VALUE_LEVELS
	end,
	job_metadata = function(settings)
		return {
			input_type = settings.input_type,
			dump_intermediate_normal_map = settings.dump_intermediate_normal_map,
		}
	end,
	create_outputs = function(source, settings, input_layers, is_combined, metadata)
		if not settings then
			settings = parse_pref_settings({})
		end

		---@cast settings HeightMapGenerationSettings
		local input_type = metadata and metadata.input_type or settings.input_type
		local dump_intermediate_normal_map = settings.dump_intermediate_normal_map
		if metadata then
			dump_intermediate_normal_map = metadata.dump_intermediate_normal_map
		end
		local normal_image = source
		local height_edge_strength = settings.edge_strength

		if input_type == "Color" then
			normal_image = TextureMapUtils.create_normal_image(source, settings.edge_strength, settings.layer_shape)
			height_edge_strength = 1
		else
			dump_intermediate_normal_map = false
		end

		local base_name = is_combined and "Combined" or input_layers[1].name
		---@type GenerationJobOutput[]
		local outputs = {
			{
				key = "primary",
				content = {
					name = base_name .. "_height",
					image = TextureMapUtils.create_height_image(
						normal_image,
						height_edge_strength,
						settings.max_iteration_count
					),
				},
			},
		}

		if dump_intermediate_normal_map then
			outputs[#outputs + 1] = {
				key = "intermediate_normal",
				content = {
					name = base_name .. "_normal",
					image = normal_image,
				},
			}
		end
		return outputs
	end,
})

return HeightMapGenerator
