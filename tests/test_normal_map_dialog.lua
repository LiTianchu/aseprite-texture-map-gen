package.path = "./?.lua;" .. package.path

-- This test should be checked using Asperite's Lua runtime for safety and compatibility
-- To use Aseprite's Lua runtine, it requires Aseprite to be installed:
-- To run:
-- "your_path_to_aseprite_binary" -b --script tests/test_normal_map_dialog.lua

local NormalMapGenerator = require("src.NormalMapGenerator")

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

app = {
	sprite = {
		colorMode = ColorMode.RGB,
		layers = { only_layer },
	},
	layer = only_layer,
	range = {
		layers = { only_layer },
	},
	alert = function()
		error("The dialog test should not display an alert")
	end,
}

---@diagnostic disable: missing-fields
NormalMapGenerator:show_dialog({
	preferences = {},
})

assert(dialog, "The normal-map dialog should be created")

local first_check_index
for index, entry in ipairs(dialog.widgets) do
	if entry.type == "check" and entry.widget.id == "selected_layers_are_input" then
		first_check_index = index
		break
	end
end

assert(first_check_index, "The selected-layers checkbox should exist")
assert(
	dialog.widgets[first_check_index + 1].type == "newrow",
	"The two normal-map checkboxes should be separated by a forced row"
)
assert(
	dialog.widgets[first_check_index + 2].type == "check"
		and dialog.widgets[first_check_index + 2].widget.id == "separate_layers",
	"The separate-layers checkbox should start on the next row"
)
assert(dialog.widgets_by_id.separate_layers.enabled, "Separate generation should start enabled in multi-layer mode")
assert(
	type(dialog.widgets_by_id.input_layer.onchange) == "function",
	"The input combobox should use Aseprite's onchange callback"
)
assert(dialog.widgets_by_id.input_layer.select == nil, "The unsupported select callback should not be used")
assert(dialog.show_options.wait == false, "The dialog should remain non-modal")
assert(dialog.show_options.bounds == nil, "The dialog should use Aseprite's content-based minimum size")

---@diagnostic disable: missing-fields
NormalMapGenerator.last_generation = {
	jobs = { {} },
}
NormalMapGenerator.regenerate_available = true
dialog.widgets_by_id.input_layer.onchange()

assert(NormalMapGenerator.last_generation == nil, "Changing the input should invalidate regeneration")
assert(
	dialog.modifications.regenerate_normal_map.enabled == false,
	"Invalidating regeneration should disable its button immediately"
)

print("Normal map dialog tests passed")
