local TextureMapGenerator = require("src.TextureMapGenerator")
local TextureMapUtils = require("src.TextureMapUtils")

local DEFAULT_EDGE_STRENGTH = 1.0
local DEFAULT_ITERATION_COUNT = 64
local MAX_ITERATION_COUNT = 512
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
---@return HeightMapGeneratorSettings settings initial settings for the height map generator
local function initial_settings(pref)
	local edge_strength = tonumber(pref.height_edge_strength) or DEFAULT_EDGE_STRENGTH
	if not TextureMapUtils.valid_strength(edge_strength) then
		edge_strength = DEFAULT_EDGE_STRENGTH
	end

	local iteration_count = tonumber(pref.height_iteration_count) or DEFAULT_ITERATION_COUNT
	if not TextureMapUtils.valid_iteration_count(iteration_count, MAX_ITERATION_COUNT) then
		iteration_count = DEFAULT_ITERATION_COUNT
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

	---@type HeightMapGeneratorSettings
	local settings = {
		edge_strength = edge_strength,
		iteration_count = iteration_count,
		input_type = input_type,
		layer_shape = layer_shape,
		dump_intermediate_normal_map = dump_intermediate_normal_map,
	}
	return settings
end

---@param data HeightMapGeneratorSettings The data table containing settings to be validated
---@return HeightMapGeneratorSettings|nil settings The validated settings for the height map generator, or nil if invalid
---@return string|nil error_message An error message if the settings are invalid,
local function sanitize_dialog_settings(data)
	local edge_strength = tonumber(data.edge_strength) or DEFAULT_EDGE_STRENGTH
	if not TextureMapUtils.valid_strength(edge_strength) then
		return nil, "Edge Intensity must be zero or a positive number."
	end

	local iteration_count = tonumber(data.iteration_count) or DEFAULT_ITERATION_COUNT
	if not TextureMapUtils.valid_iteration_count(iteration_count, MAX_ITERATION_COUNT) then
		return nil, "Slope Iterations must be a whole number from 1 to " .. MAX_ITERATION_COUNT .. "."
	end

	local input_type = data.input_type
	if not valid_input_type(input_type, INPUT_TYPES) then
		input_type = DEFAULT_INPUT_TYPE
	end

	local layer_shape = data.layer_shape
	if not TextureMapUtils.valid_layer_shape(layer_shape, LAYER_SHAPES) then
		layer_shape = DEFAULT_LAYER_SHAPE
	end

	---@type HeightMapGeneratorSettings
	local sanized_dialog_settings = {
		edge_strength = edge_strength,
		iteration_count = iteration_count,
		input_type = input_type,
		layer_shape = layer_shape,
		dump_intermediate_normal_map = input_type == "Color" and data.dump_intermediate_normal_map == true,
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
	preference_keys = {
		input_layer = "height_input_layer",
		selected_layers_are_input = "height_selected_layers_are_input",
		separate_layers = "height_separate_layers",
	},
	initial_settings = initial_settings,
	sanitize_dialog_settings = sanitize_dialog_settings,
	add_settings_widgets = function(generator, dialog_box, settings)
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
			:separator({ id = "height_input_interpretation", text = "Input Format" })
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
			:separator({ id = "height_color_input_options", text = "Ground Truth Assumptions" })
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
			:separator({ id = "height_slope_extraction", text = "Height Map Generation Settings" })
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
				id = "iteration_count",
				label = "Max Iterations (1-" .. MAX_ITERATION_COUNT .. ")",
				text = tostring(settings.iteration_count),
				decimals = 0,
				hexpand = true,
			})
	end,
	save_dialog_preferences = function(pref, data)
		pref.input_type = data.input_type
		pref.height_dump_intermediate_normal_map = data.dump_intermediate_normal_map
		pref.height_layer_shape = data.layer_shape
		pref.height_edge_strength = data.edge_strength
		pref.height_iteration_count = data.iteration_count
	end,
	save_settings = function(pref, settings)
		pref.input_type = settings.input_type
		pref.height_dump_intermediate_normal_map = settings.dump_intermediate_normal_map
		pref.height_layer_shape = settings.layer_shape
		pref.height_edge_strength = settings.edge_strength
		pref.height_iteration_count = settings.iteration_count
	end,
	job_metadata = function(settings)
		return {
			input_type = settings.input_type,
			dump_intermediate_normal_map = settings.dump_intermediate_normal_map,
		}
	end,
	create_outputs = function(source, settings, input_layers, is_combined, metadata)
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
		local outputs = {
			{
				key = "primary",
				name = base_name .. "_height",
				image = TextureMapUtils.create_height_image(
					normal_image,
					height_edge_strength,
					settings.iteration_count
				),
			},
		}

		if dump_intermediate_normal_map then
			outputs[#outputs + 1] = {
				key = "intermediate_normal",
				name = base_name .. "_normal",
				image = normal_image,
			}
		end
		return outputs
	end,
})

return HeightMapGenerator
