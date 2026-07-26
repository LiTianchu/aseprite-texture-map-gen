package.path = "./?.lua;" .. package.path

---@type integer
local height_dialog_open_count = 0
---@type integer
local height_quick_generation_count = 0
---@type integer
local normal_dialog_open_count = 0
---@type integer
local normal_quick_generation_count = 0
---@type Plugin|nil
local received_plugin

local height_map_generator = {}

---@param _ Plugin
---@return nil
function height_map_generator:show_dialog(_)
	height_dialog_open_count = height_dialog_open_count + 1
end

---@param plugin Plugin
---@return nil
function height_map_generator:generate_from_preferences(plugin)
	height_quick_generation_count = height_quick_generation_count + 1
	received_plugin = plugin
end

local normal_map_generator = {}

---@param _ Plugin
---@return nil
function normal_map_generator:show_dialog(_)
	normal_dialog_open_count = normal_dialog_open_count + 1
end

---@param plugin Plugin
---@return nil
function normal_map_generator:generate_from_preferences(plugin)
	normal_quick_generation_count = normal_quick_generation_count + 1
	received_plugin = plugin
end

package.loaded["src.HeightMapGenerator"] = height_map_generator
package.loaded["src.NormalMapGenerator"] = normal_map_generator
require("src.main")

---@type table<string, table>
local registered_menu_groups = {}
---@type integer
local registered_menu_group_count = 0
---@type table<string, table>
local registered_commands = {}
---@type integer
local registered_command_count = 0

---@diagnostic disable-next-line: missing-fields
local plugin = {
	preferences = {},
}

---@param menu_group table
---@return nil
function plugin:newMenuGroup(menu_group)
	registered_menu_groups[menu_group.id] = menu_group
	registered_menu_group_count = registered_menu_group_count + 1
end

---@param command table
---@return nil
function plugin:newCommand(command)
	registered_commands[command.id] = command
	registered_command_count = registered_command_count + 1
end

init(plugin)

local texture_map_menu = registered_menu_groups.texture_gen_menu
assert(texture_map_menu, "The Texture Map Generator menu group should be registered")
assert(texture_map_menu.group == "edit_fx", "The texture-map menu should remain under Edit > FX")
assert(registered_menu_group_count == 3, "The texture-map menu should contain one submenu for each generator")
assert(registered_command_count == 4, "The menu should contain two dialog commands and two quick commands")

local height_map_menu = registered_menu_groups.height_map_menu
assert(height_map_menu, "The Height Map submenu should be registered")
assert(height_map_menu.title == "Height Map", "The height-map command pair should have a clear submenu")
assert(height_map_menu.group == "texture_gen_menu", "The Height Map submenu should use the texture-map menu")

local height_dialog_command = registered_commands.generate_height_map
assert(height_dialog_command, "The dialog height-map command should be registered")
assert(
	height_dialog_command.title == "Generate Height Map (Dialog)",
	"The dialog height-map label should identify that it opens a dialog"
)
assert(height_dialog_command.group == "height_map_menu", "The dialog height-map command should use its submenu")

local quick_height_command = registered_commands.quick_generate_height_map
assert(quick_height_command, "The quick height-map command should be registered")
assert(quick_height_command.title == "Quick Generate Height Map", "The quick height-map label should start with Quick")
assert(quick_height_command.group == "height_map_menu", "The quick height-map command should use its submenu")

local normal_map_menu = registered_menu_groups.normal_map_menu
assert(normal_map_menu, "The Normal Map submenu should be registered")
assert(normal_map_menu.title == "Normal Map", "The normal-map command pair should have a clear submenu")
assert(normal_map_menu.group == "texture_gen_menu", "The Normal Map submenu should use the texture-map menu")

local normal_dialog_command = registered_commands.generate_normal_map
assert(normal_dialog_command, "The dialog normal-map command should be registered")
assert(
	normal_dialog_command.title == "Generate Normal Map (Dialog)",
	"The dialog normal-map label should identify that it opens a dialog"
)
assert(normal_dialog_command.group == "normal_map_menu", "The dialog normal-map command should use its submenu")

local quick_normal_command = registered_commands.quick_generate_normal_map
assert(quick_normal_command, "The quick normal-map command should be registered")
assert(quick_normal_command.title == "Quick Generate Normal Map", "The quick normal-map label should start with Quick")
assert(quick_normal_command.group == "normal_map_menu", "The quick normal-map command should use its submenu")

quick_height_command.onclick()
assert(height_quick_generation_count == 1, "The quick height-map command should generate from preferences")
assert(height_dialog_open_count == 0, "The quick height-map command should not open a dialog")
assert(received_plugin == plugin, "The quick height-map command should pass the active plugin preferences")

quick_normal_command.onclick()
assert(normal_quick_generation_count == 1, "The quick normal-map command should generate from preferences")
assert(normal_dialog_open_count == 0, "The quick normal-map command should not open a dialog")
assert(received_plugin == plugin, "The quick normal-map command should pass the active plugin preferences")

print("Quick command registration tests passed")
