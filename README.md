# Aseprite Texture Map Generator Plugin  

An All-In-One Image Processing based texture map generator plugin for [Aseprite](https://github.com/aseprite/aseprite)  that enables unified and easy 2D texture map creation pipelines.  

**Supported Features:**  

- Normal Map Generation
- Height Map Generation
- Specular Map Generation (Work In Progress...)
- Emission Map Generation (Work In Progress...)

<img src="demo/demo.png" alt="Demo" />

## Building Extension File

### Download this project, then use one of the following ways  

**1. Build Script (Need Unix / Bash Environment):**  

```
chmod +x ./build.sh && ./build.sh
```

**2. Manual Method:**  

- Zip `src/`, `package.json`, and `LICENSE` into a `.zip` file and rename the file extension to `.aseprite-extension`
- DO NOT zip the submodules in the `lib/` folder.

## Installing the Extension

- In **Aseprite**, go to `Edit` > `Preferences` > `Extensions` and click `Add Extension`, then select the `.aseprite-extension` file to install.

## Using the Extension

### Normal Map Generation

- Menu Location: `Edit` > `FX` > `Texture Map Generator` > `Generate Normal Map`.
- Options
  - Layers
    - Selected Layers Are Input: The default option, treats selected layers in the timeline below as input layers, allows multiple input layers
    - Separate Generated Layers: When checked, each selected layer will generate it's own output with suffix `_normal` and insert on top of it, when unchecked, all selected layers will generate one single `Combined_normal` layer
    - Input Layer: Only activated when `Selected layers Are Input` is unchecked, use a single layer selected from the dropdown as the input layer, does not support multi-selection
  - Ground Truth Assumptions
    - Object Shape: Tells the generator whether it should treat the selected layer(s) as concave or convex shape
    - Edge Intensity: Tells the generator how high the edges are, higher the value, the more ragged the generated output will be

### Height Map Generation

- Menu Location: `Edit` > `FX` > `Texture Map Generator` > `Generate Height Map`.
- Options
  - Layers: Same as `Normal Map -> Layers`
  - Input Format
    - Treat Layers As: Tells the generator whether it should treat the input layers as `Color` or `Normal`. If switched to Normal map, the generator will treat the input as normal and infer the height from it
  - Ground Truth Assumptions: Same as `Normal Map -> Ground Truth Assumptions`
  - Height Map Generation Settings
    - Intermediate Output: When `Input Format` is set to `Color`, the generator will need to generate a normal map first as an intermediate texture, check to keep that intermediate output
    - Iterations: Heightmap generation algorithm needs a few iterations to converge, heigher iteration gives more accurate result while taking longer time to compute

## Development  

After cloning the repository, run the following command to initialize the submodule for [Aseprite Library](https://github.com/RampantDespair/Aseprite-Library) definitions:  

```
git submodule update --init --recursive
```

### Testing

#### Testing can be done in one of the following ways

**1. Using `test.sh` (Need Unix / Bash Environment):**

First, add a `.env` file in the **project root folder** with the following content:  

```env
ASEPRITE_BIN="your_path_to_aseprite_executable"
```

Second, run the following command:  

```
chmod +x ./test.sh && ./test.sh
```

**2. Using Aseprite's Lua runtime:**  

```
your_path_to_aseprite_executable -b --script ./tests/test_normal_map.lua
```

**3. Using your installed Lua runtime:**

```
lua ./tests/test_normal_map.lua
```

*Note: Make sure [Lua 5.4](https://www.lua.org/versions.html#5.4) is installed  
