---@meta
---Raw form values returned by the dialog through `Dialog.data`
---Unlike `GenerationSettings`, the form fields uses exact widget IDs and can contain unvalidated values
---Must be sanitized before generation

---@class HeightMapDialogData : LayerSelectionData
---@field public edge_strength number|string The unsanitized edge strength
---@field public height_max_iteration_count integer|string The unsanitized maximum iteration count
---@field public input_type string The selected input type ("Color" or "Normal Map")
---@field public layer_shape string The selected object shape ("Convex" or "Concave")
---@field public dump_intermediate_normal_map boolean Whether to keep the intermediate normal map output
---@field public height_max_color_value_levels integer|string The unsanitized max number of color value levels

---@class NormalMapDialogData : LayerSelectionData
---@field public edge_strength number|string The unsanitized edge strength
---@field public layer_shape string The selected object shape ("Convex" or "Concave")
---@field public normal_max_color_value_levels integer|string The unsanitized max number of color value levels
