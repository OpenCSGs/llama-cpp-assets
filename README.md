# llama.cpp assets for CSGLite

This Go module packages a version-locked llama.cpp
`convert_hf_to_gguf.py` script and its complete matching `gguf-py` and
`conversion` packages.
Consumers embed the module into their binaries, so end users do not need Git or
a llama.cpp source download at runtime.

## Usage

```go
import assets "github.com/opencsgs/llama-cpp-assets"

converter, err := fs.ReadFile(assets.FS, assets.ConverterPath)
```

`assets.LlamaCppRef` identifies the exact upstream llama.cpp release.

## Updating llama.cpp

```bash
source ~/.myshrc
./scripts/sync-llama-cpp.sh --tag bXXXX
go test ./...
```

Review and commit all synchronized files, tag a new semantic module version,
and update CSGLite's `go.mod`. CSGLite must update its llama-server installer
tag in the same change.

## License

The synchronized llama.cpp files retain their upstream MIT license in
`data/gguf-py/LICENSE`. Repository integration code is available under
Apache-2.0; see `LICENSE`.
