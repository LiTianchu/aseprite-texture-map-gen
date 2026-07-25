# Aseprite Texture Map Generator Plugin  

## Installing the Extension

- In Aseprite, go to `Edit` > `Preferences` > `Extensions` and click `Add Extension`, then select the `texture-map-gen.aseprite-extension` file to install.

## Using the Extension

### Normal Map

- Generate a normal map from `Edit` > `FX` > `Texture Map Generator` > `Generate Normal Map`.
- Choose one input layer, or enable **Selected Layers Are Input** to use the image layers selected in the timeline.
- Enable **Separate Generated Layers** for one `<layer name>_normal` result per input, or disable it to render the selected inputs into one `Combined_normal` layer.
- **Object Shape** switches between convex and concave normals.
- **Edge Height** controls edge intensity; higher values give a steeper edge.
- **Regenerate** updates the last generated output layers in their original frame using the current Object Shape and Edge Height.

## Development  

After cloning the repository, run the following command to initialize the submodule for Aseprite lib definitions:  

```
git submodule update --init --recursive
```

### Testing

#### Using `test.sh` (Need Unix / Bash Environment)

First, add a `.env` file in the **project root folder** with the following content:  

```env
ASEPRITE_BIN="your_path_to_aseprite_executable"
```

Second, run the following command:  

```
chmod +x ./test.sh && ./test.sh
```

#### Using Aseprite's Lua runtime to test

```
your_path_to_aseprite_executable -b --script ./tests/test_normal_map.lua
```

#### Using your installed Lua runtime

```
lua ./tests/test_normal_map.lua
```

## Packaging Extension File

### Build Script (Need Unix / Bash Environment)  

`chmod +x ./build.sh && ./build.sh`

### Manual Packaging Method  

- Zip `src/`, `package.json`, and `LICENSE` into a `.zip` file and rename the file extension to `.aseprite-extension`
- DO NOT zip the submodules in the `lib/` folder.
