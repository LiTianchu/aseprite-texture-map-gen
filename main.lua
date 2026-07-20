function init(plugin)
	print("Plugin initialized: " .. plugin.name)

	plugin:newCommand({})
end
