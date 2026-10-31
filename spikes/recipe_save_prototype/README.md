# recipe_save_prototype (ANVL-158 spike, not for merge)

Throwaway prototype of the record-level save cycle on the Recipe editor.
Results and recommendations for ANVL-155 are in [FINDINGS.md](FINDINGS.md).

```sh
cd spikes/recipe_save_prototype
fvm flutter test
fvm flutter build linux
build/linux/x64/release/bundle/recipe_save_prototype /path/to/project.anvil
```

The app copies the given `.anvil` file to a fresh temp directory and opens
only the copy (the path is printed on stdout and shown on the list page).
