---@class GenerationJobOutput
---@field public key string The stable key used to match this output when regenerating
---@field public layer Layer The Aseprite layer containing the generated output

---@class GenerationJob
---@field public input_layers Layer[] The input layers for the generation job
---@field public is_combined boolean Whether the input layers are combined into a single generation source
---@field public metadata table|nil Generator specific metadata retained for regeneration
---@field public outputs GenerationJobOutput[] The generated output layers recorded by the job
local GenerationJob = {}
