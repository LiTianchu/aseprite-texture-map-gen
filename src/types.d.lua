---@meta

---Layer selection fields
---@class LayerSelectionData
---@field public selected_layers_are_input boolean Whether the selected layers are used as input for generation
---@field public separate_layers boolean Whether to generate outputs for each input layer separately
---@field public input_layer string|nil The path of the input layer to use for generation when not using selected layers as input

---Sanitized settings shared by every texture map generator
---@class GenerationSettings : LayerSelectionData

---Sanitized settings shared by normal map and height map generation
---@class SurfaceMapGenerationSettings : GenerationSettings
---@field public layer_shape string The assumed shape of the object in the input layers ("Convex" or "Concave")
---@field public edge_strength number The strength of edge detection during surface-map generation
---@field public max_color_value_levels integer The max number of discrete color value levels in the final output

---Sanitized height map settings produced from preferences or `HeightMapDialogData`
---@class HeightMapGenerationSettings : SurfaceMapGenerationSettings
---@field public edge_strength number The strength of the edge detection for height map generation
---@field public max_iteration_count integer The maximum number of iterations for slope extraction
---@field public input_type string The type of input layers ("Color" or "Normal Map")
---@field public layer_shape string The assumed shape of the object in the input layers ("Convex" or "Concave")
---@field public dump_intermediate_normal_map boolean Whether to keep the intermediate normal map output

---Sanitized normal map settings produced from preferences or `NormalMapDialogData`
---@class NormalMapGenerationSettings : SurfaceMapGenerationSettings

---@class LayerImagePair
---@field public layer? Layer The Aseprite layer, once the output has been inserted into a sprite
---@field public image Image The Aseprite image

---@class NamedLayerImagePair : LayerImagePair
---@field public name string The name of the layer

---@class GenerationJobOutput
---@field public key string The unique key identifying the output layer
---@field public content NamedLayerImagePair The generated output layer and its image

---@class GenerationJob
---@field public input_layers Layer[] The input layers for the generation job
---@field public is_combined boolean Whether the input layers are combined into a single generation source
---@field public metadata table|nil Generator specific metadata retained for regeneration
---@field public outputs GenerationJobOutput[]|nil The generated output layers recorded by the job

---@class GenerationRecord
---@field public sprite Sprite The Aseprite sprite containing the generated outputs
---@field public frame_anchors LayerCelPair[] The recorded frame anchors for this sprite
---@field public jobs GenerationJob[] The recorded generation jobs for this sprite

---@class LayerCelPair
---@field public layer Layer The Aseprite layer containing the cel
---@field public cel Cel|nil The Aseprite cel inside the layer

---@class GeneratorConfig
---@field title string
---@field display_name string
---@field singular_name string
---@field plural_name string
---@field indefinite_name string
---@field layers_separator_id string
---@field actions_separator_id string
---@field generate_button_id string
---@field regenerate_button_id string
---@field parse_pref_settings fun(pref: table): GenerationSettings
---@field sanitize_dialog_settings fun(data: HeightMapDialogData|NormalMapDialogData): settings: GenerationSettings|nil, error_message: string|nil
---@field add_settings_widgets fun(generator: TextureMapGenerator, dialog_box: Dialog, settings: GenerationSettings)
---@field save_dialog_preferences fun(pref: table, data: HeightMapDialogData|NormalMapDialogData)
---@field save_settings fun(pref: table, settings: GenerationSettings|nil)
---@field job_metadata? fun(settings: table): table|nil
---@field create_outputs fun(source: Image, settings: GenerationSettings|nil, input_layers: Layer[], is_combined: boolean, metadata?: table): GenerationJobOutput[]
