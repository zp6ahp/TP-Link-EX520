# build

- `build.sh` — portable Docker build: clones OpenWrt `bb8054e`, applies the
  patch, installs feeds, builds, copies images, and creates `-final.bin` with
  metadata.
- `make-sysupgrade-tar.sh` — extracts `kernel`/`root` from the FIT sysupgrade
  image, creates a tar with `CONTROL`, and appends the `fwtool` metadata.
- `Dockerfile` — build environment (Ubuntu 24.04 + OpenWrt dependencies).

Details are in `../README.md`.

## Run

```bash
docker build -t ex520-builder:24.04 .
./build.sh
```

The result is written to `../bin/` by default. You can override the output
directory with `OUT=/path/to/out`.

## Notes

- `build.sh` is safe to re-run: it resets tracked files, removes the new
  package/DTS, and re-applies the patch.
- The host `fwtool` used for metadata is taken from the build volume at
  `staging_dir/host/bin/fwtool`.
