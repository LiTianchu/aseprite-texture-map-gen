## Aseprite Heighmap Generator Plugin  

## Development  

After cloning the repository, run the following command to initialize the submodule for Aseprite lib definitions:  

```
git submodule update --init --recursive
```

## Releasing  

- Zip `src/`, `package.json`, and `LICENSE` into a `.zip` file and rename the file extension to `.aseprite-extension`
- DO NOT zip the submodules in the `lib/` folder.
- On Linux environment: `chmod +x ./build.sh && ./build.sh`
