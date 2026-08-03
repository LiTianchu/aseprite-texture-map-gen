local AsepriteLayerUtils = require("src.AsepriteLayerUtils")
local AsepriteUIUtils = require("src.AsepriteUIUtils")
local TextureMapUtils = require("src.TextureMapUtils")

--- The abstract base class for generating texture maps from image layers in Aseprite
--- Inherited by specific texture map generators like NormalMapGenerator and HeightMapGenerator
---@class TextureMapGenerator
---@field public config GeneratorConfig The configuration for the texture map generator
---@field public pref table The plugin preferences used by this generator instance
---@field public sprite Sprite The sprite used by this generator instance
---@field public layer_path_dict table<string, Layer> The image layers indexed by their unique paths
---@field public dialog_box Dialog|nil The non-modal settings dialog, when one is open
---@field public last_generation GenerationRecord|nil The last generation jobs and their outputs, used for regeneration
---@field public regenerate_available boolean Whether the Regenerate button is enabled in the dialog
local TextureMapGenerator = {}
TextureMapGenerator.__index = TextureMapGenerator

---@param generator TextureMapGenerator The texture map generator instance
---@param name string The name of the preference key to read
---@return any value The value of the preference key, or nil if not set
local function read_preference(generator, name)
	return generator.pref[name]
end

---@param generator TextureMapGenerator The texture map generator instance
---@param name string The name of the preference key to write
---@param value any The value to write to the preference key
local function write_preference(generator, name, value)
	generator.pref[name] = value
end

---@param frame_anchors LayerCelPair[] The recorded frame anchors for a generation record
---@return integer|nil frame_number The frame number of the recorded cel, or nil if not
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

---@param config GeneratorConfig The configuration for the texture map generator
---@return TextureMapGenerator generator The new instance of the texture map generator
function TextureMapGenerator.new(config)
	return setmetatable({
		config = config,
		last_generation = nil,
		regenerate_available = false,
	}, TextureMapGenerator)
end

---@param available boolean Whether the Regenerate button should be enabled in the dialog
function TextureMapGenerator:set_regenerate_available(available)
	self.regenerate_available = available and self.last_generation ~= nil
	if self.dialog_box then
		self.dialog_box:modify({
			id = self.config.regenerate_button_id,
			enabled = self.regenerate_available,
		})
	end
end

---Invalidate the last generation record, preventing regeneration until a new generation is performed
function TextureMapGenerator:invalidate_regeneration()
	self.last_generation = nil
	self:set_regenerate_available(false)
end

---@param data LayerSelectionData Raw dialog data or sanitized settings containing layer-selection values
function TextureMapGenerator:save_layer_preferences(data)
	write_preference(self, "input_layer", data.input_layer)
	write_preference(self, "selected_layers_are_input", data.selected_layers_are_input)
	write_preference(self, "separate_layers", data.separate_layers)
	write_preference(self, "generate_all_frames", data.generate_all_frames)
end

---@param plugin Plugin The Aseprite plugin instance
---@return string[]|nil layer_paths The available image-layer paths, or nil when generation cannot start
function TextureMapGenerator:initialize_generation_context(plugin)
	---@type Sprite|nil
	local active_sprite = app.sprite
	if not active_sprite then
		AsepriteUIUtils.show_alert(
			self.config.title,
			"Open a sprite before generating " .. self.config.indefinite_name .. "."
		)
		return nil
	end
	if active_sprite.colorMode ~= ColorMode.RGB then
		AsepriteUIUtils.show_alert(self.config.title, self.config.plural_name .. " require an RGB sprite.")
		return nil
	end

	local layer_paths, layer_path_dict = AsepriteLayerUtils.layer_paths(active_sprite)
	if #layer_paths == 0 then
		AsepriteUIUtils.show_alert(self.config.title, "The sprite does not contain any image layers.")
		return nil
	end

	self.pref = plugin.preferences
	self.sprite = active_sprite
	self.layer_path_dict = layer_path_dict
	self.last_generation = nil
	self.regenerate_available = false
	return layer_paths
end

---@param plugin Plugin
function TextureMapGenerator:show_dialog(plugin)
	local layer_paths = self:initialize_generation_context(plugin)
	if not layer_paths then
		return
	end

	local selected_layers_are_input = read_preference(self, "selected_layers_are_input")
	if selected_layers_are_input == nil then
		selected_layers_are_input = true
	end

	local separate_layers = read_preference(self, "separate_layers")
	if separate_layers == nil then
		separate_layers = true
	end

	local generate_all_frames = read_preference(self, "generate_all_frames")
	if generate_all_frames == nil then
		generate_all_frames = false
	end

	local preferred_layer_path = read_preference(self, "input_layer")
	local input_layer_path =
		AsepriteLayerUtils.selected_layer_path(layer_paths, self.layer_path_dict, preferred_layer_path, app.layer)
	local initial_settings = self.config.parse_pref_settings(self.pref)

	self.dialog_box = Dialog({
		title = self.config.title,
		onclose = function()
			local data = self.dialog_box.data
			self:save_layer_preferences(data)
			self.config.save_specific_preferences(self.pref, data)
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
		:combobox({
			id = "input_layer",
			label = "Input Layer (Single Layer)",
			options = layer_paths,
			option = input_layer_path,
			enabled = not selected_layers_are_input,
			onchange = function()
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
		:newrow()
		:check({
			id = "generate_all_frames",
			text = "Generate All Frames",
			selected = generate_all_frames,
			onclick = function()
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

---Generate a new texture map immediately from the settings persisted in plugin preferences.
---This uses an isolated generator instance so an open non-modal dialog keeps its own generation state.
---@param plugin Plugin The Aseprite plugin instance
---@return nil
function TextureMapGenerator:generate_from_preferences(plugin)
	---@type TextureMapGenerator
	local quick_generator = TextureMapGenerator.new(self.config)
	local layer_paths = quick_generator:initialize_generation_context(plugin)
	if not layer_paths then
		return
	end

	---@type GenerationSettings
	local saved_settings = quick_generator.config.parse_pref_settings(quick_generator.pref)
	---@type Layer[]
	local input_layers = quick_generator:input_layers_from_settings(saved_settings)
	quick_generator:generate_new(input_layers, saved_settings)
end

---@param settings GenerationSettings The settings that determine which layers are used as input
---@return Layer[] input_layers The ordered input layers to generate from
function TextureMapGenerator:input_layers_from_settings(settings)
	if settings.selected_layers_are_input then
		return AsepriteLayerUtils.selected_layers(app.range, app.layer)
	end

	local input_layer_path = settings.input_layer
	if not input_layer_path then
		return {}
	end

	---@type Layer|nil
	local single_input_layer = self.layer_path_dict[input_layer_path]
	return single_input_layer and { single_input_layer } or {}
end

---Create generated outputs and apply quantization
---@param source Image The rendered reference source image for the generation job
---@param settings GenerationSettings The sanitized generator settings
---@param input_layers Layer[] The input layers used by the generation job
---@param is_combined boolean Whether the inputs were combined into one source, it is only used for layer name
---@param metadata table|nil Generator specific metadata retained for regeneration
---@return GenerationJobOutput[] final_outputs The final outputs
function TextureMapGenerator:create_final_outputs(source, settings, input_layers, is_combined, metadata)
	---@cast settings SurfaceMapGenerationSettings
	local generated_outputs = self.config.create_outputs(source, settings, input_layers, is_combined, metadata)
	for _, output in ipairs(generated_outputs) do
		output.content.image = TextureMapUtils.quantize_image(output.content.image, settings.max_color_value_levels)
	end
	return generated_outputs
end

---@param ordered_layers Layer[] The ordered input layers to generate from
---@param frame_number integer The frame number selected from the ordered_layers input
---@param settings GenerationSettings|nil The settings for the generation
---@param skip_empty_outputs? boolean Whether to skip image processing when every input cel is empty
---@return GenerationJob[] generated_jobs The generated jobs with their outputs
function TextureMapGenerator:render_generation_jobs(ordered_layers, frame_number, settings, skip_empty_outputs)
	if not settings then
		settings = self.config.parse_pref_settings({})
	end

	---@type GenerationJob[]
	local source_jobs = {}
	if settings.selected_layers_are_input and not settings.separate_layers and #ordered_layers > 1 then
		-- if don't want to separate layers, put every layer into a single job
		-- number of generation jobs = 1
		source_jobs[1] = {
			input_layers = ordered_layers,
			is_combined = true,
		}
	else
		--number of generation jobs = number of layers
		for _, input_layer in ipairs(ordered_layers) do
			source_jobs[#source_jobs + 1] = {
				input_layers = { input_layer }, -- put a single layer into each job
				is_combined = false,
			}
		end
	end

	local generated_jobs = {}
	for _, source_job in ipairs(source_jobs) do
		local source, _, _, has_source_cel =
			AsepriteLayerUtils.render_layers(self.sprite, source_job.input_layers, frame_number)
		-- if not has_cel then
		-- 	AsepriteUIUtils.show_alert(
		-- 		self.config.title,
		-- 		"Layer '"
		-- 			.. (missing_layer ~= nil and missing_layer.name or "Unknown Layer")
		-- 			.. "' does not contain an image in the active frame."
		-- 	)
		-- 	return nil
		-- end

		source_job.metadata = self.config.job_metadata and self.config.job_metadata(settings) or nil
		source_job.has_source_cel = has_source_cel

		if has_source_cel or not skip_empty_outputs then
			-- start texture map generation from the input source
			source_job.outputs = self:create_final_outputs(
				source,
				settings,
				source_job.input_layers,
				source_job.is_combined,
				source_job.metadata
			)
		else
			source_job.outputs = {}
		end

		generated_jobs[#generated_jobs + 1] = source_job
	end
	return generated_jobs
end

---Generate each layer job across the sprite timeline, retaining no image for frames with no source cel
---@param ordered_layers Layer[] The ordered input layers to generate from
---@param settings GenerationSettings The settings for the generation
---@return GenerationJob[] generated_jobs The generated jobs with images indexed by frame number
function TextureMapGenerator:render_all_frames_generation_jobs(ordered_layers, settings)
	---@type GenerationJob[]
	local generated_jobs = {}

	for frame_index, frame in ipairs(self.sprite.frames) do
		local frame_number = frame.frameNumber
		local frame_jobs = self:render_generation_jobs(ordered_layers, frame_number, settings, frame_index > 1)

		-- iterate through each frame job, each frame job corresponds to one frame in one layer
		-- if combined, then only one job for that frame
		for job_index, frame_job in ipairs(frame_jobs) do
			-- frame job represents one generation job for one specific frame
			-- generation job is intended to aggregate all the frame jobs in the timeline for a specific layer(or combined layer if combine layer is enbled)
			-- therefore need to re-build frame generation job
			local generated_job = generated_jobs[job_index]
			if not generated_job then
				generated_job = {
					input_layers = frame_job.input_layers,
					is_combined = frame_job.is_combined,
					metadata = frame_job.metadata,
					outputs = {},
				}

				for output_index, output in ipairs(frame_job.outputs or {}) do
					generated_job.outputs[output_index] = {
						key = output.key,
						content = {
							name = output.content.name,
							image = output.content.image,
							frame_images = {},
						},
					}
				end

				generated_jobs[job_index] = generated_job
			end

			-- register the frame images
			if frame_job.has_source_cel then
				for output_index, output in ipairs(frame_job.outputs or {}) do
					local frame_images = generated_job.outputs[output_index].content.frame_images
					assert(frame_images, "All-frame generation output is missing its frame image registry.")
					frame_images[frame_number] = output.content.image
				end
			end
		end
	end

	-- returns an aggregated generation job array
	-- all the generated jobs per each output layer across all frames in the timeline
	return generated_jobs
end

--- Main entry point for the Generate button in the dialog
--- Takes currently selected layers and generate the texture maps based on the settings
function TextureMapGenerator:generate_from_dialog()
	if app.sprite ~= self.sprite then
		AsepriteUIUtils.show_alert(
			self.config.title,
			"Return to the sprite where this dialog was opened and try again."
		)
		return
	end

	local data = self.dialog_box.data

	local settings, settings_error = self.config.sanitize_dialog_settings(data)

	if settings_error then
		AsepriteUIUtils.show_alert(self.config.title, settings_error)
		return
	end

	---@type Layer[]
	assert(settings, "Settings provided for generation is nil.")
	local input_layers = self:input_layers_from_settings(settings)
	self:generate_new(input_layers, settings)
end

---Generate new texture-map layers from explicit input layers and sanitized settings.
---@param input_layers Layer[] The input layers selected for generation
---@param settings GenerationSettings The sanitized settings to use for generation
---@return nil
function TextureMapGenerator:generate_new(input_layers, settings)
	---@type Layer[]
	local ordered_layers = AsepriteLayerUtils.ordered_image_layers(self.sprite, input_layers)

	if #ordered_layers == 0 then
		AsepriteUIUtils.show_alert(self.config.title, "Select at least one image layer to use as input.")
		return
	end

	local frame_number = app.frame and app.frame.frameNumber or 1
	---@type GenerationJob[]
	local generated_jobs = {}
	if settings.generate_all_frames then
		generated_jobs = self:render_all_frames_generation_jobs(ordered_layers, settings)
	else
		generated_jobs = self:render_generation_jobs(ordered_layers, frame_number, settings)
	end

	if not generated_jobs then
		return
	end

	---@type Layer[]
	local output_layers = {}
	---@type GenerationJob[]
	local regeneration_jobs = {}
	---@type LayerCelPair[]
	local frame_anchors = {}
	---@type Layer
	local active_input_layer = app.layer
	---@type Layer
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
			---@type GenerationJobOutput[]
			local recorded_outputs = {}

			-- create the primary output is first
			-- any intermediate (dump) outputs are placed between the source and primary output
			for output_index, output in ipairs(generated_job.outputs) do
				local output_image = output.content.image
				local output_frame_number = frame_number
				if settings.generate_all_frames then
					output_image = nil
					output_frame_number = nil
					local frame_images = output.content.frame_images or {}
					for _, frame in ipairs(self.sprite.frames) do
						local candidate = frame_images[frame.frameNumber]
						if candidate then
							output_image = candidate
							output_frame_number = frame.frameNumber
							break
						end
					end
				end

				-- allocate the layers for the generated outputs
				local output_layer = AsepriteLayerUtils.create_layer_for_inputs(
					self.sprite,
					generated_job.input_layers,
					output.content.name,
					output_image,
					output_frame_number
				)

				-- fill in the cells
				if settings.generate_all_frames then
					local frame_images = output.content.frame_images or {}
					for _, frame in ipairs(self.sprite.frames) do
						local generated_image = frame_images[frame.frameNumber]
						if generated_image and frame.frameNumber ~= output_frame_number then
							-- aseprite does not automatically create a cel for the frame, so need to allocate a new cel for the generated image
							self.sprite:newCel(output_layer, frame.frameNumber, generated_image, Point(0, 0))
						end
					end
				end

				-- record the generated output for regeneration
				recorded_outputs[output_index] = {
					key = output.key,
					content = {
						name = output.content.name,
						layer = output_layer,
						image = output.content.image,
					},
				}

				frame_anchors[#frame_anchors + 1] = {
					layer = output_layer,
					cel = output_layer:cel(frame_number),
				}
			end

			local primary_output_layer = recorded_outputs[1].content.layer
			output_layers[index] = primary_output_layer

			regeneration_jobs[index] = {
				input_layers = generated_job.input_layers,
				is_combined = generated_job.is_combined,
				metadata = generated_job.metadata,
				outputs = recorded_outputs,
			}

			for _, input_layer in ipairs(generated_job.input_layers) do
				if input_layer == active_input_layer then
					local next_active_layer =
						assert(primary_output_layer, "Primary output layer is missing for regeneration job.")
					active_output_layer = next_active_layer
					break
				end
			end
		end
	end)

	self:save_layer_preferences(settings)
	self.config.save_settings(self.pref, settings)
	self.last_generation = {
		sprite = self.sprite,
		frame_anchors = frame_anchors,
		jobs = regeneration_jobs,
		generate_all_frames = settings.generate_all_frames,
	}
	self:set_regenerate_available(true)

	app.layer = active_output_layer or output_layers[#output_layers]
	app.refresh()
end

---@param last_generation GenerationRecord The last generation record to validate
---@return boolean is_valid Whether the last generation record is still valid for regeneration
function TextureMapGenerator:validate_regeneration(last_generation)
	if app.sprite ~= last_generation.sprite then
		AsepriteUIUtils.show_alert(
			self.config.title,
			"Return to the sprite where the " .. self.config.singular_name .. " was generated and try again."
		)
		return false
	end

	for _, job in ipairs(last_generation.jobs) do
		for _, output in ipairs(job.outputs) do
			local output_layer = output.content.layer
			if
				not output_layer
				or not AsepriteLayerUtils.sprite_contains_layer(last_generation.sprite, output_layer)
			then
				self:invalidate_regeneration()
				AsepriteUIUtils.show_alert(
					self.config.title,
					"A generated layer no longer exists. Generate a new " .. self.config.singular_name .. "."
				)
				return false
			end
		end
		for _, input_layer in ipairs(job.input_layers) do
			if not AsepriteLayerUtils.sprite_contains_layer(last_generation.sprite, input_layer) then
				self:invalidate_regeneration()
				AsepriteUIUtils.show_alert(
					self.config.title,
					"An input layer no longer exists. Generate a new " .. self.config.singular_name .. "."
				)
				return false
			end
		end
	end
	return true
end

---Regenerate the last generated texture maps using new settings except for Layers settings
function TextureMapGenerator:regenerate_last()
	local last_generation = self.last_generation
	if not last_generation or not last_generation.jobs or #last_generation.jobs == 0 then
		AsepriteUIUtils.show_alert(
			self.config.title,
			"Generate " .. self.config.indefinite_name .. " before using Regenerate."
		)
		return
	end
	if not self:validate_regeneration(last_generation) then
		return
	end

	---@type integer[]
	local frame_numbers = {}
	if last_generation.generate_all_frames then
		for _, frame in ipairs(last_generation.sprite.frames) do
			frame_numbers[#frame_numbers + 1] = frame.frameNumber
		end
	else
		local recorded_frame_number = find_recorded_frame_number(last_generation.frame_anchors or {})
		if not recorded_frame_number then
			self:invalidate_regeneration()
			AsepriteUIUtils.show_alert(
				self.config.title,
				"The original frame no longer exists. Generate a new " .. self.config.singular_name .. "."
			)
			return
		end
		frame_numbers[1] = recorded_frame_number
	end

	local settings, settings_error = self.config.sanitize_dialog_settings(self.dialog_box.data)
	if settings_error then
		AsepriteUIUtils.show_alert(self.config.title, settings_error)
		return
	end
	assert(settings, "Settings provided for regeneration is nil.")

	---@type table[][] # job_update_registry\[job_index\]\[layer_img_update_index\]
	local job_update_registry = {}
	for index, job in ipairs(last_generation.jobs) do
		---@type table[]
		local updated_layer_imgs_from_job = {}
		for _, frame_number in ipairs(frame_numbers) do
			local source, has_cel, missing_layers, has_source_cel =
				AsepriteLayerUtils.render_layers(last_generation.sprite, job.input_layers, frame_number)
			if not last_generation.generate_all_frames and not has_cel then
				local missing_layer = missing_layers[1]
				AsepriteUIUtils.show_alert(
					self.config.title,
					"Layer '"
						.. (missing_layer and missing_layer.name or "Unknown Layer")
						.. "' does not contain an image in the originally generated frame."
				)
				return
			end

			---@type table<string, GenerationJobOutput>
			local generated_by_key = {}
			if has_source_cel then
				---@type GenerationJobOutput[]
				local generated_outputs =
					self:create_final_outputs(source, settings, job.input_layers, job.is_combined, job.metadata)
				for _, output in ipairs(generated_outputs) do
					generated_by_key[output.key] = output
				end
			end

			for _, output in ipairs(job.outputs) do
				local regenerated = generated_by_key[output.key]
				if has_source_cel and not regenerated then
					self:invalidate_regeneration()
					AsepriteUIUtils.show_alert(
						self.config.title,
						"The generated output settings changed. Generate a new " .. self.config.singular_name .. "."
					)
					return
				end
				updated_layer_imgs_from_job[#updated_layer_imgs_from_job + 1] = {
					layer = output.content.layer,
					image = regenerated and regenerated.content.image or nil,
					frame_number = frame_number,
				}
			end
		end
		job_update_registry[index] = updated_layer_imgs_from_job
	end

	app.transaction("Regenerate " .. self.config.display_name, function()
		for _, updates in ipairs(job_update_registry) do
			for _, update in ipairs(updates) do
				if not update.layer then
					error("Recorded generation output is missing its layer.")
				end
				if update.image then
					AsepriteLayerUtils.update_layer_image(
						last_generation.sprite,
						update.layer,
						update.image,
						update.frame_number
					)
				else
					local cel = update.layer:cel(update.frame_number)
					if cel then
						last_generation.sprite:deleteCel(cel)
					end
				end
			end
		end
	end)

	self.config.save_settings(self.pref, settings)
	app.refresh()
end

return TextureMapGenerator
