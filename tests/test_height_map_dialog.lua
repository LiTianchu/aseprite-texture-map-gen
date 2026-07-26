package.path = "./?.lua;" .. package.path

-- This test should be checked using Asperite's Lua runtime for safety and compatibility
-- To use Aseprite's Lua runtine, it requires Aseprite to be installed:
-- To run:
-- "your_path_to_aseprite_binary" -b --script tests/test_height_map_dialog.lua

local HeightMapGenerator = require("src.HeightMapGenerator")
local MAX_ITERATION_COUNT_CAP = 512

local dialog

Dialog = function(config)
	dialog = {
		config = config,
		data = {},
		widgets = {},
		widgets_by_id = {},
		modifications = {},
	}

	local function add_widget(self, widget_type, widget)
		local entry = {
			type = widget_type,
			widget = widget,
		}
		self.widgets[#self.widgets + 1] = entry
		if widget and widget.id then
			self.widgets_by_id[widget.id] = widget
		end
		return self
	end

	function dialog:separator(widget)
		return add_widget(self, "separator", widget)
	end

	function dialog:check(widget)
		self.data[widget.id] = widget.selected
		return add_widget(self, "check", widget)
	end

	function dialog:newrow()
		return add_widget(self, "newrow")
	end

	function dialog:combobox(widget)
		self.data[widget.id] = widget.option
		return add_widget(self, "combobox", widget)
	end

	function dialog:number(widget)
		self.data[widget.id] = tonumber(widget.text)
		return add_widget(self, "number", widget)
	end

	function dialog:button(widget)
		return add_widget(self, "button", widget)
	end

	function dialog:modify(options)
		self.modifications[options.id] = options
		return self
	end

	function dialog:show(options)
		self.show_options = options
		return self
	end

	return dialog
end

ColorMode = { RGB = "rgb" }

local only_layer = {
	name = "Only Layer",
	isImage = true,
}
local alert

app = {
	sprite = {
		colorMode = ColorMode.RGB,
		layers = { only_layer },
	},
	layer = only_layer,
	range = {
		layers = { only_layer },
	},
	alert = function(options)
		alert = options
	end,
}

---@type table
local preferences = {}
---@diagnostic disable-next-line: missing-fields
local plugin = {
	preferences = preferences,
}

HeightMapGenerator:show_dialog(plugin)

assert(dialog, "The height-map dialog should be created")
assert(dialog.widgets_by_id.input_type.option == "Color", "Normal Map should be the default input interpretation")
assert(
	dialog.widgets_by_id.dump_intermediate_normal_map.enabled == true,
	"Keeping an intermediate normal should start enabled for color input"
)
assert(dialog.widgets_by_id.layer_shape.enabled == true, "Color Object Shape should be available for color input")
assert(
	dialog.widgets_by_id.height_max_iteration_count.decimals == 0,
	"Max Iterations should be a whole-number input"
)
assert(
	dialog.widgets_by_id.height_max_iteration_count.label:find(tostring(MAX_ITERATION_COUNT_CAP), 1, true),
	"The iteration input should display its safety cap"
)
assert(dialog.widgets_by_id.input_layer.onchange, "The single-layer picker should be selectable")
assert(
	dialog.widgets_by_id.height_max_color_value_levels.decimals == 0,
	"Max Color Value Levels should be a whole-number input"
)

dialog.data.height_max_iteration_count = 37
dialog.data.height_max_color_value_levels = 48
dialog.config.onclose()

assert(preferences.height_max_iteration_count == 37, "Closing the dialog should save Max Iterations")
assert(preferences.height_max_color_value_levels == 48, "Closing the dialog should save Max Color Value Levels")

HeightMapGenerator:show_dialog(plugin)
assert(
	dialog.widgets_by_id.height_max_iteration_count.text == "37",
	"Reopening the dialog should restore Max Iterations"
)
assert(
	dialog.widgets_by_id.height_max_color_value_levels.text == "48",
	"Reopening the dialog should restore Max Color Value Levels"
)

assert(dialog.widgets_by_id.separate_layers, "Separate generation should be available")
assert(dialog.widgets_by_id.regenerate_height_map.enabled == false, "Regenerate should start disabled")
assert(dialog.show_options.wait == false, "The height-map dialog should remain non-modal")
assert(dialog.show_options.bounds == nil, "The height-map dialog should size itself to its controls")

HeightMapGenerator.last_generation = {
	jobs = { {} },
}
HeightMapGenerator.regenerate_available = true
dialog.data.input_type = "Color"
dialog.widgets_by_id.input_type.onchange()

assert(
	dialog.modifications.dump_intermediate_normal_map.enabled,
	"Color input should enable keeping the generated intermediate normal"
)
assert(dialog.modifications.layer_shape.enabled, "Color input should enable Object Shape")
assert(HeightMapGenerator.last_generation == nil, "Changing input interpretation should invalidate regeneration")
assert(
	dialog.modifications.regenerate_height_map.enabled == false,
	"Invalidating height regeneration should disable its button immediately"
)

HeightMapGenerator.last_generation = {
	jobs = { {} },
}
dialog.widgets_by_id.dump_intermediate_normal_map.onclick()
assert(
	HeightMapGenerator.last_generation == nil,
	"Changing whether to keep the intermediate normal should invalidate regeneration"
)

dialog.data.edge_strength = 1
dialog.data.height_max_iteration_count = MAX_ITERATION_COUNT_CAP + 1
HeightMapGenerator:generate_from_dialog()
assert(alert, "An iteration count over the cap should display an alert")
assert(
	alert.text:find(tostring(MAX_ITERATION_COUNT_CAP), 1, true),
	"The cap alert should explain the maximum accepted iteration count"
)

print("Height map dialog tests passed")
