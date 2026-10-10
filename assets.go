package llamacppassets

import "embed"

const (
	// LlamaCppRef is the upstream llama.cpp release used for every bundled asset.
	LlamaCppRef = "b11541"
	// Revision changes whenever the synchronized or locally patched assets change.
	Revision = 6

	ConverterPath  = "data/convert_hf_to_gguf.py"
	GGUFPyRoot     = "data/gguf-py"
	ConversionRoot = "data/conversion"
)

// FS contains the pinned converter script and its complete matching Python packages.
//
// all: is required because Python packages contain __init__.py files, which
// go:embed excludes from directory patterns unless the all: prefix is used.
//
//go:embed all:data
var FS embed.FS
