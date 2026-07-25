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

local function read_dialog_settings(dialog_box)
	local data = dialog_box.data
	local edge_strength = tonumber(data.edge_strength)
	if not TextureMapUtils.valid_strength(edge_strength) then
		return nil, nil, "Edge Height must be zero or a positive number."
	end

	local layer_shape = data.layer_shape
	if not TextureMapUtils.valid_layer_shape(layer_shape, LAYER_SHAPES) then
		layer_shape = DEFAULT_LAYER_SHAPE
	end

	return edge_strength, layer_shape
end

local function find_recorded_frame_number(frame_anchors)
	for _, anchor in ipairs(frame_anchors) do
		for _, cel in ipairs(anchor.layer.cels) do
			if cel == anchor.cel then
				return cel.frameNumber
			end
		end
	end
	return nil
end

function NormalMapGenerator:set_regenerate_available(available)
	self.regenerate_available = available and self.last_generation ~= nil
	if self.dialog_box then
		self.dialog_box:modify({
			id = "regenerate_normal_map",
			enabled = self.regenerate_available,
		})
	end
end

function NormalMapGenerator:invalidate_regeneration()
	self.last_generation = nil
	self:set_regenerate_available(false)
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
	self.last_generation = nil
	self.regenerate_available = false
	-- These runtime objects were stored in preferences by older builds.
	self.pref.is_regenerate_available = nil
	self.pref.last_input_layers = nil
	self.pref.last_generated_layers = nil

	local selected_layers_are_input = self.pref.selected_layers_are_input
	if selected_layers_are_input == nil then
		selected_layers_are_input = true
	end

	local separate_layers = self.pref.separate_layers
	if separate_layers == nil then
		separate_layers = true
	end

	local edge_strength = tonumber(self.pref.edge_strength) or DEFAULT_EDGE_STRENGTH
	if not TextureMapUtils.valid_strength(edge_strength) then
		edge_strength = DEFAULT_EDGE_STRENGTH
	end

	local layer_shape = self.pref.layer_shape
	if not TextureMapUtils.valid_layer_shape(layer_shape, LAYER_SHAPES) then
		layer_shape = DEFAULT_LAYER_SHAPE
	end

	local input_option = AsepriteLayerUtils.selected_option(options, option_layers, self.pref.input_layer, app.layer)

	self.dialog_box = Dialog({
		title = "Generate Normal Map",
		onclose = function()
			local data = self.dialog_box.data
			self.pref.input_layer = data.input_layer
			self.pref.selected_layers_are_input = data.selected_layers_are_input
			self.pref.separate_layers = data.separate_layers
			self.pref.layer_shape = data.layer_shape
			self.pref.edge_strength = data.edge_strength
			self.last_generation = nil
			self.regenerate_available = false
		end,
	})

	self.dialog_box
		:separator({ id = "normal_map_layers_separator", text = "Layers" })
		:check({
			id = "selected_layers_are_input",
			text = "Selected Layers Are Input (Multiple Layers)",
			selected = selected_layers_are_input,
			onclick = function()
				self.dialog_box:modify({
					id = "input_layer",
					enabled = not self.dialog_box.data.selected_layers_are_input,
				})
				self.dialog_box:modify({
					id = "separate_layers",
					enabled = self.dialog_box.data.selected_layers_are_input,
				})
				self:invalidate_regeneration()
			end,
		})
		:newrow()
		:check({
			id = "separate_layers",
			text = "Separate Generated Layers",
			selected = separate_layers,
			enabled = selected_layers_are_input,
			onclick = function()
				self:invalidate_regeneration()
			end,
		})
		:combobox({
			id = "input_layer",
			label = "Input Layer (Single Layer)",
			options = options,
			option = input_option,
			enabled = not selected_layers_are_input,
			onchange = function()
				self:invalidate_regeneration()
			end,
		})
		:separator({ id = "normal_ground_truth_assumptions", text = "Ground Truth Assumptions" })
		:combobox({
			id = "layer_shape",
			label = "Object Shape",
			options = LAYER_SHAPES,
			option = layer_shape,
		})
		:number({
			id = "edge_strength",
			label = "Edge Height (0 = flat)",
			text = tostring(edge_strength),
			decimals = 2,
		})
		:separator({ id = "normal_actions", text = "Actions" })
		:button({
			id = "generate_normal_map",
			text = "Generate New",
			focus = true,
			onclick = function()
				self:generate_from_dialog()
			end,
		})
		:button({
			id = "regenerate_normal_map",
			text = "Regenerate",
			onclick = function()
				self:regenerate_last()
			end,
			enabled = self.regenerate_available,
		})
	self.dialog_box:show({
		wait = false,
	})
end

function NormalMapGenerator:generate_from_dialog()
	if app.sprite ~= self.sprite then
		show_alert("Return to the sprite where this dialog was opened and try again.")
		return
	end

	local data = self.dialog_box.data
	local edge_strength, layer_shape, settings_error = read_dialog_settings(self.dialog_box)
	if settings_error then
		show_alert(settings_error)
		return
	end

	local layers

	if data.selected_layers_are_input then
		layers = AsepriteLayerUtils.selected_layers(app.range, app.layer)
	else
		local single_input_layer = self.option_layers[data.input_layer]
		layers = single_input_layer and { single_input_layer } or {}
	end

	local ordered_layers = AsepriteLayerUtils.ordered_image_layers(self.sprite, layers)
	if #ordered_layers == 0 then
		show_alert("Select at least one image layer to use as input.")
		return
	end

	local frame_number = app.frame and app.frame.frameNumber or 1
	local generated_jobs = {}

	if data.selected_layers_are_input and not data.separate_layers and #ordered_layers > 1 then
		local source, has_cel, missing_layer =
			AsepriteLayerUtils.render_layers(self.sprite, ordered_layers, frame_number)
		if not has_cel then
			show_alert(
				"Layer '"
					.. (missing_layer ~= nil and missing_layer.name or "Unknown Layer")
					.. "' does not contain an image in the active frame."
			)
			return
		end
		generated_jobs[1] = {
			input_layers = ordered_layers,
			name = "Combined_normal",
			image = TextureMapUtils.create_normal_image(source, edge_strength, layer_shape),
		}
	else
		for _, input_layer in ipairs(ordered_layers) do
			local source, has_cel = AsepriteLayerUtils.render_layer(self.sprite, input_layer, frame_number)
			if not has_cel then
				show_alert("Layer '" .. input_layer.name .. "' does not contain an image in the active frame.")
				return
			end

			generated_jobs[#generated_jobs + 1] = {
				input_layers = { input_layer },
				name = input_layer.name .. "_normal",
				image = TextureMapUtils.create_normal_image(source, edge_strength, layer_shape),
			}
		end
	end

	local output_layers = {}
	local regeneration_jobs = {}
	local frame_anchors = {}
	local active_input_layer = app.layer
	local active_output_layer

	for _, input_layer in ipairs(ordered_layers) do
		frame_anchors[#frame_anchors + 1] = {
			layer = input_layer,
			cel = input_layer:cel(frame_number),
		}
	end

	app.transaction("Generate Normal Map", function()
		-- insert from top to bottom so inserting a lower pair cannot separate
		-- a source layer from the normal layer already placed above it
		for index = #generated_jobs, 1, -1 do
			local generated_job = generated_jobs[index]
			local output_layer = AsepriteLayerUtils.create_layer_for_inputs(
				self.sprite,
				generated_job.input_layers,
				generated_job.name,
				generated_job.image,
				frame_number
			)

			output_layers[index] = output_layer
			regeneration_jobs[index] = {
				input_layers = generated_job.input_layers,
				output_layer = output_layer,
			}
			frame_anchors[#frame_anchors + 1] = {
				layer = output_layer,
				cel = output_layer:cel(frame_number),
			}
			for _, input_layer in ipairs(generated_job.input_layers) do
				if input_layer == active_input_layer then
					active_output_layer = output_layer
					break
				end
			end
		end
	end)

	-- update app preferences to remember the last used settings for next time
	self.pref.selected_layers_are_input = data.selected_layers_are_input
	self.pref.separate_layers = data.separate_layers
	self.pref.input_layer = data.input_layer
	self.pref.layer_shape = layer_shape
	self.pref.edge_strength = edge_strength
	self.last_generation = {
		sprite = self.sprite,
		frame_anchors = frame_anchors,
		jobs = regeneration_jobs,
	}
	self:set_regenerate_available(true)

	app.layer = active_output_layer or output_layers[#output_layers]
	app.refresh()
end

function NormalMapGenerator:regenerate_last()
	local last_generation = self.last_generation
	if not last_generation or not last_generation.jobs or #last_generation.jobs == 0 then
		show_alert("Generate a normal map before using Regenerate.")
		return
	end

	if app.sprite ~= last_generation.sprite then
		show_alert("Return to the sprite where the normal map was generated and try again.")
		return
	end

	-- validate the complete recorded set before rendering or writing anything
	-- if one generated layer was deleted, regeneration becomes unavailable
	for _, job in ipairs(last_generation.jobs) do
		if not AsepriteLayerUtils.sprite_contains_layer(last_generation.sprite, job.output_layer) then
			self:invalidate_regeneration()
			show_alert("A generated layer no longer exists. Generate a new normal map.")
			return
		end
		for _, input_layer in ipairs(job.input_layers) do
			if not AsepriteLayerUtils.sprite_contains_layer(last_generation.sprite, input_layer) then
				self:invalidate_regeneration()
				show_alert("An input layer no longer exists. Generate a new normal map.")
				return
			end
		end
	end

	local frame_number = find_recorded_frame_number(last_generation.frame_anchors or {})
	if not frame_number then
		self:invalidate_regeneration()
		show_alert("The original frame no longer exists. Generate a new normal map.")
		return
	end

	local edge_strength, layer_shape, settings_error = read_dialog_settings(self.dialog_box)
	if settings_error then
		show_alert(settings_error)
		return
	end

	local regenerated_images = {}
	for index, job in ipairs(last_generation.jobs) do
		local source, has_cel, missing_layer =
			AsepriteLayerUtils.render_layers(last_generation.sprite, job.input_layers, frame_number)
		if not has_cel then
			show_alert(
				"Layer '" .. missing_layer.name .. "' does not contain an image in the originally generated frame."
			)
			return
		end

		regenerated_images[index] = TextureMapUtils.create_normal_image(source, edge_strength, layer_shape)
	end

	app.transaction("Regenerate Normal Map", function()
		for index, job in ipairs(last_generation.jobs) do
			AsepriteLayerUtils.update_layer_image(
				last_generation.sprite,
				job.output_layer,
				regenerated_images[index],
				frame_number
			)
		end
	end)

	self.pref.layer_shape = layer_shape
	self.pref.edge_strength = edge_strength
	app.refresh()
end

return NormalMapGenerator
