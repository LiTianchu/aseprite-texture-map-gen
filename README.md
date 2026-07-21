## Aseprite Texture Map Generator Plugin  

## Development  

After cloning the repository, run the following command to initialize the submodule for Aseprite lib definitions:  

```
git submodule update --init --recursive
```

## Packaging Extension File

### Build Script (Need Unix / Bash Environment)  

`chmod +x ./build.sh && ./build.sh`

### Manual Packaging Method  

- Zip `src/`, `package.json`, and `LICENSE` into a `.zip` file and rename the file extension to `.aseprite-extension`
- DO NOT zip the submodules in the `lib/` folder.

## Using the Extension
- In Aseprite, go to `Edit` > `Preferences` > `Extensions` and click `Add Extension`, then select the `texture-map-gen.aseprite-extension` file to install.
