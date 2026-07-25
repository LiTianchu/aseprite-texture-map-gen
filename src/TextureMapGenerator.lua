local AsepriteLayerUtils = require("src.AsepriteLayerUtils")

--- The abstract base class for generating texture maps from image layers in Aseprite
--- Inherited by specific texture map generators like NormalMapGenerator and HeightMapGenerator
---@class TextureMapGenerator
local TextureMapGenerator = {}
TextureMapGenerator.__index = TextureMapGenerator

local function preference_key(config, name)
	return (config.preference_keys and config.preference_keys[name]) or name
end

local function read_preference(generator, name)
	return generator.pref[preference_key(generator.config, name)]
end

local function write_preference(generator, name, value)
	generator.pref[preference_key(generator.config, name)] = value
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

function TextureMapGenerator.new(config)
	return setmetatable({
		config = config,
		last_generation = nil,
		regenerate_available = false,
	}, TextureMapGenerator)
end

function TextureMapGenerator:show_alert(text)
	app.alert({
		title = self.config.title,
		text = text,
	})
end

function TextureMapGenerator:set_regenerate_available(available)
	self.regenerate_available = available and self.last_generation ~= nil
	if self.dialog_box then
		self.dialog_box:modify({
			id = self.config.regenerate_button_id,
			enabled = self.regenerate_available,
		})
	end
end

function TextureMapGenerator:invalidate_regeneration()
	self.last_generation = nil
	self:set_regenerate_available(false)
end

function TextureMapGenerator:save_layer_preferences(data)
	write_preference(self, "input_layer", data.input_layer)
	write_preference(self, "selected_layers_are_input", data.selected_layers_are_input)
	write_preference(self, "separate_layers", data.separate_layers)
end

---@param plugin Plugin
function TextureMapGenerator:show_dialog(plugin)
	local sprite = app.sprite
	if not sprite then
		self:show_alert("Open a sprite before generating " .. self.config.indefinite_name .. ".")
		return
	end
	if sprite.colorMode ~= ColorMode.RGB then
		self:show_alert(self.config.plural_name .. " require an RGB sprite.")
		return
	end

	local options, option_layers = AsepriteLayerUtils.layer_options(sprite)
	if #options == 0 then
		self:show_alert("The sprite does not contain any image layers.")
		return
	end

	self.pref = plugin.preferences
	self.sprite = sprite
	self.option_layers = option_layers
	self.last_generation = nil
	self.regenerate_available = false

	local selected_layers_are_input = read_preference(self, "selected_layers_are_input")
	if selected_layers_are_input == nil then
		selected_layers_are_input = true
	end

	local separate_layers = read_preference(self, "separate_layers")
	if separate_layers == nil then
		separate_layers = true
	end

	local preferred_input = read_preference(self, "input_layer")
	local input_option = AsepriteLayerUtils.selected_option(options, option_layers, preferred_input, app.layer)
	local initial_settings = self.config.initial_settings(self.pref)

	self.dialog_box = Dialog({
		title = self.config.title,
		onclose = function()
			local data = self.dialog_box.data
			self:save_layer_preferences(data)
			self.config.save_dialog_preferences(self.pref, data)
			self.last_generation = nil
			self.regenerate_available = false
		end,
	})

	self.dialog_box
		:separator({ id = self.config.layers_separator_id, text = "Layers" })
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

	self.config.add_settings_widgets(self, self.dialog_box, initial_settings)

	self.dialog_box
		:separator({ id = self.config.actions_separator_id, text = "Actions" })
		:button({
			id = self.config.generate_button_id,
			text = "Generate New",
			focus = true,
			onclick = function()
				self:generate_from_dialog()
			end,
		})
		:button({
			id = self.config.regenerate_button_id,
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

function TextureMapGenerator:input_layers_from_dialog(data)
	if data.selected_layers_are_input then
		return AsepriteLayerUtils.selected_layers(app.range, app.layer)
	end

	local single_input_layer = self.option_layers[data.input_layer]
	return single_input_layer and { single_input_layer } or {}
end

function TextureMapGenerator:render_generation_jobs(ordered_layers, frame_number, data, settings)
	local source_jobs = {}
	if data.selected_layers_are_input and not data.separate_layers and #ordered_layers > 1 then
		source_jobs[1] = {
			input_layers = ordered_layers,
			is_combined = true,
		}
	else
		for _, input_layer in ipairs(ordered_layers) do
			source_jobs[#source_jobs + 1] = {
				input_layers = { input_layer },
				is_combined = false,
			}
		end
	end

	local generated_jobs = {}
	for _, source_job in ipairs(source_jobs) do
		local source, has_cel, missing_layer =
			AsepriteLayerUtils.render_layers(self.sprite, source_job.input_layers, frame_number)
		if not has_cel then
			self:show_alert(
				"Layer '"
					.. (missing_layer ~= nil and missing_layer.name or "Unknown Layer")
					.. "' does not contain an image in the active frame."
			)
			return nil
		end

		source_job.metadata = self.config.job_metadata and self.config.job_metadata(settings) or nil

		source_job.generated_outputs =
			self.config.create_outputs(source, settings, source_job.input_layers, source_job.is_combined)
		generated_jobs[#generated_jobs + 1] = source_job
	end
	return generated_jobs
end

--- Main entry point for the Generate button in the dialog
--- Takes currently selected layers and generate the texture maps based on the settings
function TextureMapGenerator:generate_from_dialog()
	if app.sprite ~= self.sprite then
		self:show_alert("Return to the sprite where this dialog was opened and try again.")
		return
	end

	local data = self.dialog_box.data
	local settings, settings_error = self.config.read_dialog_settings(data)
	if settings_error then
		self:show_alert(settings_error)
		return
	end

	local layers = self:input_layers_from_dialog(data)
	local ordered_layers = AsepriteLayerUtils.ordered_image_layers(self.sprite, layers)
	if #ordered_layers == 0 then
		self:show_alert("Select at least one image layer to use as input.")
		return
	end

	local frame_number = app.frame and app.frame.frameNumber or 1
	local generated_jobs = self:render_generation_jobs(ordered_layers, frame_number, data, settings)
	if not generated_jobs then
		return
	end

	local output_layers = {}
	---@type GenerationJob[]
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

	app.transaction("Generate " .. self.config.display_name, function()
		-- Aseprite shifts layers on top of inserted layers when inserting new layers
		-- need to process from last (top in stack) to first (bottom in stack)
		-- so that layers below the generated outputs are not affected by the new layer's insertion
		for index = #generated_jobs, 1, -1 do
			local generated_job = generated_jobs[index]
			local recorded_outputs = {}

			-- create the primary output is first
			-- any intermediate (dump) outputs are placed between the source and primary output
			for output_index, output in ipairs(generated_job.generated_outputs) do
				local output_layer = AsepriteLayerUtils.create_layer_for_inputs(
					self.sprite,
					generated_job.input_layers,
					output.name,
					output.image,
					frame_number
				)
				recorded_outputs[output_index] = {
					key = output.key,
					layer = output_layer,
				}
				frame_anchors[#frame_anchors + 1] = {
					layer = output_layer,
					cel = output_layer:cel(frame_number),
				}
			end

			local primary_output_layer = recorded_outputs[1].layer
			output_layers[index] = primary_output_layer
			regeneration_jobs[index] = {
				input_layers = generated_job.input_layers,
				is_combined = generated_job.is_combined,
				metadata = generated_job.metadata,
				outputs = recorded_outputs,
			}
			for _, input_layer in ipairs(generated_job.input_layers) do
				if input_layer == active_input_layer then
					active_output_layer = primary_output_layer
					break
				end
			end
		end
	end)

	self:save_layer_preferences(data)
	self.config.save_settings(self.pref, settings)
	self.last_generation = {
		sprite = self.sprite,
		frame_anchors = frame_anchors,
		jobs = regeneration_jobs,
	}
	self:set_regenerate_available(true)

	app.layer = active_output_layer or output_layers[#output_layers]
	app.refresh()
end

function TextureMapGenerator:validate_regeneration(last_generation)
	if app.sprite ~= last_generation.sprite then
		self:show_alert(
			"Return to the sprite where the " .. self.config.singular_name .. " was generated and try again."
		)
		return false
	end

	for _, job in ipairs(last_generation.jobs) do
		for _, output in ipairs(job.outputs) do
			if not AsepriteLayerUtils.sprite_contains_layer(last_generation.sprite, output.layer) then
				self:invalidate_regeneration()
				self:show_alert(
					"A generated layer no longer exists. Generate a new " .. self.config.singular_name .. "."
				)
				return false
			end
		end
		for _, input_layer in ipairs(job.input_layers) do
			if not AsepriteLayerUtils.sprite_contains_layer(last_generation.sprite, input_layer) then
				self:invalidate_regeneration()
				self:show_alert("An input layer no longer exists. Generate a new " .. self.config.singular_name .. ".")
				return false
			end
		end
	end
	return true
end

function TextureMapGenerator:regenerate_last()
	local last_generation = self.last_generation
	if not last_generation or not last_generation.jobs or #last_generation.jobs == 0 then
		self:show_alert("Generate " .. self.config.indefinite_name .. " before using Regenerate.")
		return
	end
	if not self:validate_regeneration(last_generation) then
		return
	end

	local frame_number = find_recorded_frame_number(last_generation.frame_anchors or {})
	if not frame_number then
		self:invalidate_regeneration()
		self:show_alert("The original frame no longer exists. Generate a new " .. self.config.singular_name .. ".")
		return
	end

	local settings, settings_error = self.config.read_dialog_settings(self.dialog_box.data)
	if settings_error then
		self:show_alert(settings_error)
		return
	end

	local regenerated_jobs = {}
	for index, job in ipairs(last_generation.jobs) do
		local source, has_cel, missing_layer =
			AsepriteLayerUtils.render_layers(last_generation.sprite, job.input_layers, frame_number)
		if not has_cel then
			self:show_alert(
				"Layer '" .. missing_layer.name .. "' does not contain an image in the originally generated frame."
			)
			return
		end

		local generated_outputs =
			self.config.create_outputs(source, settings, job.input_layers, job.is_combined, job.metadata)
		local generated_by_key = {}
		for _, output in ipairs(generated_outputs) do
			generated_by_key[output.key] = output
		end

		local updates = {}
		for _, output in ipairs(job.outputs) do
			local regenerated = generated_by_key[output.key]
			if not regenerated then
				self:invalidate_regeneration()
				self:show_alert(
					"The generated output settings changed. Generate a new " .. self.config.singular_name .. "."
				)
				return
			end
			updates[#updates + 1] = {
				layer = output.layer,
				image = regenerated.image,
			}
		end
		regenerated_jobs[index] = updates
	end

	app.transaction("Regenerate " .. self.config.display_name, function()
		for _, updates in ipairs(regenerated_jobs) do
			for _, update in ipairs(updates) do
				AsepriteLayerUtils.update_layer_image(last_generation.sprite, update.layer, update.image, frame_number)
			end
		end
	end)

	self.config.save_settings(self.pref, settings)
	app.refresh()
end

return TextureMapGenerator
