local TextureMapUtils = {}
local MathUtils = require("src.MathUtils")

---@param value number The edge strength value to validate
---@return boolean # true if the value is a valid edge strength (non-negative finite number),
function TextureMapUtils.valid_strength(value)
	return value ~= nil and value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

---@param count number|nil The iteration count to validate
---@param maximum integer The maximum allowed iteration count
---@return boolean # true if the count is a valid iteration count within [1, maximum], false otherwise
function TextureMapUtils.valid_iteration_count(count, maximum)
	if type(count) ~= "number" then
		return false
	end

	return count ~= nil
		and count == count
		and count ~= math.huge
		and count ~= -math.huge
		and count == math.floor(count)
		and count >= 1
		and count <= maximum
end

---@param shape_name string Name of the layer shape to validate
---@param layer_shapes string[] The list of valid layer shapes
---@return boolean # true if the name value is a valid layer shape, false otherwise
function TextureMapUtils.valid_layer_shape(shape_name, layer_shapes)
	for _, shape in ipairs(layer_shapes) do
		if shape_name == shape then
			return true
		end
	end
	return false
end

---@param num_levels number|nil The color value levels to validate
---@param max_levels integer The maximum allowed color value levels
---@return boolean is_valid true if the color value level num is in 1..MAX_COLOR_VALUE_LEVELS_CAP, false otherwise
function TextureMapUtils.valid_color_value_levels(num_levels, max_levels)
	if type(num_levels) ~= "number" then
		return false
	end
	return num_levels == math.floor(num_levels) and num_levels >= 1 and num_levels <= max_levels
end

---@param channel_value integer The channel value to quantize in the range [0, 255]
---@param max_color_value_levels integer The maximum number of discrete output levels
---@return integer quantized_value The nearest evenly spaced channel value
local function quantize_color_channel(channel_value, max_color_value_levels)
	if max_color_value_levels == 1 then
		return 128
	end

	local interval_count = max_color_value_levels - 1
	local nearest_level_index = math.floor((channel_value / 255) * interval_count + 0.5)
	return MathUtils.round_to_u8((nearest_level_index / interval_count) * 255)
end

---Quantize each RGB channel to evenly spaced values while preserving alpha and the source image
---@param source Image The image to quantize the RGB channels
---@param max_color_value_levels integer The maximum number of discrete values allowed in each RGB channel
---@return Image quantized_image A cloned image containing the quantized RGB values
function TextureMapUtils.quantize_image(source, max_color_value_levels)
	if not TextureMapUtils.valid_color_value_levels(max_color_value_levels, 256) then
		error("Max Color Value Levels must be a whole number from 1 to 256.")
	end

	local quantized_image = source:clone()
	local pixel_color = app.pixelColor
	for y = 0, source.height - 1 do
		for x = 0, source.width - 1 do
			local source_pixel = source:getPixel(x, y)
			quantized_image:drawPixel(
				x,
				y,
				pixel_color.rgba(
					quantize_color_channel(pixel_color.rgbaR(source_pixel), max_color_value_levels),
					quantize_color_channel(pixel_color.rgbaG(source_pixel), max_color_value_levels),
					quantize_color_channel(pixel_color.rgbaB(source_pixel), max_color_value_levels),
					pixel_color.rgbaA(source_pixel)
				)
			)
		end
	end
	return quantized_image
end

---@param band number[] The texture band to sample from, represented as a 1D array of pixel values
---@param width integer The width of the texture
---@param height integer The height of the texture
---@param x integer The x-coordinate of the pixel to sample
---@param y integer The y-coordinate of the pixel to sample
---@return number value sampled pixel value, clamped to the texture bounds
local function sample_band(band, width, height, x, y)
	x = MathUtils.clamp(x, 0, width - 1)
	y = MathUtils.clamp(y, 0, height - 1)
	return band[y * width + x + 1]
end

---Calculates one tangent-space normal using a 3x3 Sobel kernel.
---@param luminance_map number[]
---@param width integer
---@param height integer
---@param x integer
---@param y integer
---@param edge_strength number
---@return number x
---@return number y
---@return number z
function TextureMapUtils.sobel_normal(luminance_map, width, height, x, y, edge_strength)
	-- sample the 3x3 neighborhood of the pixel at (x, y)
	local top_left = sample_band(luminance_map, width, height, x - 1, y - 1)
	local top = sample_band(luminance_map, width, height, x, y - 1)
	local top_right = sample_band(luminance_map, width, height, x + 1, y - 1)
	local left = sample_band(luminance_map, width, height, x - 1, y)
	local right = sample_band(luminance_map, width, height, x + 1, y)
	local bottom_left = sample_band(luminance_map, width, height, x - 1, y + 1)
	local bottom = sample_band(luminance_map, width, height, x, y + 1)
	local bottom_right = sample_band(luminance_map, width, height, x + 1, y + 1)

	-- horizontal Sobel operator Gx, shape:
	-- -1 0 1
	-- -2 0 2
	-- -1 0 1
	local gradient_x = -(top_left + 2 * left + bottom_left - top_right - 2 * right - bottom_right)

	-- vertical Sobel operator Gy, shape:
	--  1  2  1
	--  0  0  0
	-- -1 -2 -1
	local gradient_y = top_left + 2 * top + top_right - bottom_left - 2 * bottom - bottom_right

	local normal_x = gradient_x * edge_strength
	local normal_y = gradient_y * edge_strength
	local normal_z = 1
	local length = math.sqrt(normal_x * normal_x + normal_y * normal_y + normal_z * normal_z)

	-- normalize
	return normal_x / length, normal_y / length, normal_z / length
end

--- Converts an image to a luminance texture using Rec. 709 formula.
--- Each pixel is represented by a single luminance value.
--- @param image Image The source image to convert to a luminance texture.
--- @return number[] luminance_map # RGB luminance values in the range [0, 1], multiplied by alpha
--- @return number[] alpha_map # Alpha values in the range [0, 255]
local function image_to_luminance_texture(image)
	local luminance_map = {}
	local alpha_map = {}
	local pixel_color = app.pixelColor

	for y = 0, image.height - 1 do
		for x = 0, image.width - 1 do
			local pixel = image:getPixel(x, y)
			local red = pixel_color.rgbaR(pixel)
			local green = pixel_color.rgbaG(pixel)
			local blue = pixel_color.rgbaB(pixel)
			local alpha = pixel_color.rgbaA(pixel)
			local index = y * image.width + x + 1

			-- Rec. 709 luminance calculation formula
			luminance_map[index] = (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255 * alpha / 255
			alpha_map[index] = alpha
		end
	end

	return luminance_map, alpha_map
end

---Create a tangent-space normal map from a source image using a Sobel filter.
---@param source Image The source image to convert to a normal map.
---@param edge_strength number The strength of the edges in the normal map.
---@param layer_shape string The shape of the layer, either "Convex" or "Concave".
---@return Image normal_map The generated normal map image.
function TextureMapUtils.create_normal_image(source, edge_strength, layer_shape)
	local luminance_map, alpha_map = image_to_luminance_texture(source)

	---@diagnostic disable-next-line: param-type-mismatch
	local normal_map = Image(source.width, source.height, ColorMode.RGB)
	local pixel_color = app.pixelColor
	local direction = layer_shape == "Concave" and 1 or -1

	for y = 0, source.height - 1 do
		for x = 0, source.width - 1 do
			local normal_x, normal_y, normal_z = TextureMapUtils.sobel_normal(
				luminance_map,
				source.width,
				source.height,
				x,
				y,
				edge_strength * direction
			)
			local index = y * source.width + x + 1
			normal_map:drawPixel(
				x,
				y,
				pixel_color.rgba(
					MathUtils.round_to_u8((normal_x * 0.5 + 0.5) * 255),
					MathUtils.round_to_u8((normal_y * 0.5 + 0.5) * 255),
					MathUtils.round_to_u8((normal_z * 0.5 + 0.5) * 255),
					alpha_map[index]
				)
			)
		end
	end

	return normal_map
end

---@param mask boolean[]|nil Optional mask indicating which pixels are part of the surface. If nil, all pixels are considered part of the surface
---@param index integer The index of the pixel to check
---@return boolean # true if the pixel is part of the surface, false otherwise
local function has_surface(mask, index)
	return mask == nil or mask[index]
end

---Reconstructs height values from per-pixel X/Y slopes using iterative relaxation with Jacobi Iteration
---@param slope_x number[] Slope map detected in the X direction, expressed as height change per pixel when moved in the +X direction
---@param slope_y number[] Slope map detected in the Y direction, expressed as height change per pixel when moved in the +Y direction
---@param width integer Width of the slope maps
---@param height integer Height of the slope maps
---@param iteration_count integer Number of iterations to perform for relaxation. More iterations yield more converged results
---@param mask boolean[]|nil Optional mask indicating which pixels are part of the surface. If nil, all pixels are considered part of the surface
---@return number[] height_map Reconstructed height values, centered around 0.5, expressed as a 1D array of pixel values
function TextureMapUtils.slope_extract_height(slope_x, slope_y, width, height, iteration_count, mask)
	local pixel_count = width * height

	-- iteration states
	local current = {}
	local next_values = {}

	-- initial state
	for index = 1, pixel_count do
		current[index] = 0.5
		next_values[index] = 0.5
	end

	for _ = 1, iteration_count do
		-- max change for convergence tracking
		local maximum_change = 0

		for y = 0, height - 1 do
			for x = 0, width - 1 do
				local index = y * width + x + 1
				if not has_surface(mask, index) then
					next_values[index] = 0.5
				else
					local estimate_sum = 0
					local estimate_count = 0
					local center_slope_x = slope_x[index]
					local center_slope_y = slope_y[index]

					-- apply 5 point stencil operator
					-- 0 1 0
					-- 1 4 1
					-- 0 1 0
					if x > 0 then -- left neighbor
						local left = index - 1
						if has_surface(mask, left) then
							-- center pixel is at +X dir, so need to add
							estimate_sum = estimate_sum + current[left] + 0.5 * (slope_x[left] + center_slope_x)
							estimate_count = estimate_count + 1
						end
					end
					if x + 1 < width then -- right neighbor
						local right = index + 1
						if has_surface(mask, right) then
							-- center pixel is at -X dir, so need to subtract
							estimate_sum = estimate_sum + current[right] - 0.5 * (slope_x[right] + center_slope_x)
							estimate_count = estimate_count + 1
						end
					end
					if y > 0 then -- top neighbor
						local top = index - width
						if has_surface(mask, top) then
							-- center pixel is at +Y dir, so need to add
							estimate_sum = estimate_sum + current[top] + 0.5 * (slope_y[top] + center_slope_y)
							estimate_count = estimate_count + 1
						end
					end
					if y + 1 < height then -- bottom neighbor
						local bottom = index + width
						if has_surface(mask, bottom) then
							-- center pixel is at -Y dir, so need to subtract
							estimate_sum = estimate_sum + current[bottom] - 0.5 * (slope_y[bottom] + center_slope_y)
							estimate_count = estimate_count + 1
						end
					end

					-- update step
					local next_height = current[index]
					if estimate_count > 0 then
						-- normalize
						local neighbor_estimate = estimate_sum / estimate_count
						-- under-relaxation prevents two-pixel/checkerboard oscillation by blending
						next_height = 0.5 * current[index] + 0.5 * neighbor_estimate
					end
					next_values[index] = next_height

					-- compute maximum change for convergence tracking
					maximum_change = math.max(maximum_change, math.abs(next_height - current[index]))
				end
			end
		end

		-- update states for next iteration
		current, next_values = next_values, current

		-- if the maximum change is small enought to be considered converged, stop iterating
		if maximum_change < 0.0000001 then
			break
		end
	end

	-- re-center step
	-- a slope field determines relative not absolute height, re-centering is needed
	local height_sum = 0
	local surface_pixel_count = 0
	for index = 1, pixel_count do
		if has_surface(mask, index) then
			height_sum = height_sum + current[index]
			surface_pixel_count = surface_pixel_count + 1
		end
	end

	if surface_pixel_count > 0 then
		local mean_height = height_sum / surface_pixel_count
		local offset = 0.5 - mean_height -- how far does mean height deviate from center

		-- shifts everything by the offset so that the mean is centered at 0.5
		for index = 1, pixel_count do
			if has_surface(mask, index) then
				current[index] = current[index] + offset
			end
		end
	end

	return current
end

---@param image Image The source image to convert to slope textures
---@param edge_strength number The strength of the edges in the generated slope textures
---@return number[] slope_x Slope map detected in the X direction, expressed as height change per pixel when moved in the +X direction
---@return number[] slope_y Slope map detected in the Y direction, expressed as height change per pixel when moved in the +Y direction
---@return number[] alpha_map Alpha values in the range [0, 255] for each pixel
---@return boolean[] surface_mask Boolean mask indicating which pixels are part of the surface (true) and which are not (false)
local function image_to_slope_texture(image, edge_strength)
	local slope_x = {}
	local slope_y = {}
	local alpha_map = {}
	local surface_mask = {}
	local pixel_color = app.pixelColor

	for y = 0, image.height - 1 do
		for x = 0, image.width - 1 do
			local pixel = image:getPixel(x, y)
			local red = pixel_color.rgbaR(pixel)
			local green = pixel_color.rgbaG(pixel)
			local blue = pixel_color.rgbaB(pixel)
			local alpha = pixel_color.rgbaA(pixel)
			local index = y * image.width + x + 1

			-- remap normal values from [0, 255] to [-1, 1] range
			local normal_x = MathUtils.clamp((red - 128) / 127, -1, 1)
			local normal_y = MathUtils.clamp((green - 128) / 127, -1, 1)
			local normal_z = MathUtils.clamp((blue - 128) / 127, -1, 1)

			alpha_map[index] = alpha
			surface_mask[index] = alpha > 0
			if alpha > 0 and normal_z >= 0.001 then
				-- Aseprite normal maps use green-up so use flipped sign for x and y
				-- normal = (-∂h/∂x, -∂h/∂y, 1)

				-- ∂h/∂x: rate of change of height in the x direction
				slope_x[index] = ((-normal_x / normal_z) / image.width) * edge_strength

				-- ∂h/∂y: rate of change of height in the y direction
				-- image y grows downward in Aseprite, need to flip the sign again
				slope_y[index] = ((normal_y / normal_z) / image.height) * edge_strength
			else
				slope_x[index] = 0
				slope_y[index] = 0
			end
		end
	end

	return slope_x, slope_y, alpha_map, surface_mask
end

---Creates a height map from a normal map using iterative relaxation.
---@param source Image The source normal map image to convert to a height map
---@param edge_strength number The strength of the edges in the generated height map
---@param iteration_count integer The number of iterations to perform for relaxation. More iterations yield more converged results
---@return Image height_map The generated height map image
function TextureMapUtils.create_height_image(source, edge_strength, iteration_count)
	local slope_x, slope_y, alpha_map, surface_mask = image_to_slope_texture(source, edge_strength)
	local heights = TextureMapUtils.slope_extract_height(
		slope_x,
		slope_y,
		source.width,
		source.height,
		iteration_count,
		surface_mask
	)
	---@diagnostic disable-next-line: param-type-mismatch
	local height_map = Image(source.width, source.height, ColorMode.RGB)
	local pixel_color = app.pixelColor

	for y = 0, source.height - 1 do
		for x = 0, source.width - 1 do
			local index = y * source.width + x + 1
			local height_byte = MathUtils.round_to_u8(heights[index] * 255)
			height_map:drawPixel(x, y, pixel_color.rgba(height_byte, height_byte, height_byte, alpha_map[index]))
		end
	end

	return height_map
end

return TextureMapUtils
