# Agent Instructions

This repository is the versioned Python asset dependency for CSGLite.

## llama.cpp Lockstep

- Every asset release must come from one official `ggml-org/llama.cpp` tag.
- Use `scripts/sync-llama-cpp.sh --tag <tag>` to update both
  `convert_hf_to_gguf.py` and the complete matching `gguf-py` directory.
- Do not update only one of those assets.
- Keep `LlamaCppRef` on the same upstream tag and increment `Revision` whenever
  synchronized or locally patched asset content changes.
- Preserve documented CSGLite converter patches when syncing upstream.
- Run `go test ./...` and `scripts/sync-llama-cpp.sh --check` before publishing.
- Publish a new semantic Go module tag for every asset update.
- In the same upgrade task, update CSGLite's module dependency, llama-server
  installer tag, architecture mappings, tests, and user-facing version text.
