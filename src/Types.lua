---@class HeightMapGeneratorSettings
---@field public edge_strength number The strength of the edge detection for height map generation
---@field public iteration_count integer The number of iterations for slope extraction
---@field public input_type string The type of input layers ("Color" or "Normal Map")
---@field public layer_shape string The assumed shape of the object in the input layers ("Convex " or "Concave")
---@field public dump_intermediate_normal_map boolean Whether to keep the intermediate normal map output

---@class NormalMapGeneratorSettings
---@field public layer_shape string The assumed shape of the object in the input layers ("Convex" or "Concave")
---@field public edge_strength number The strength of the edge detection for normal map generation

---@class GenerationJobOutput
---@field public key string The stable key used to match this output when regenerating
---@field public layer Layer The Aseprite layer containing the generated output

---@class GenerationJob
---@field public input_layers Layer[] The input layers for the generation job
---@field public is_combined boolean Whether the input layers are combined into a single generation source
---@field public metadata table|nil Generator specific metadata retained for regeneration
---@field public outputs GenerationJobOutput[] The generated output layers recorded by the job
