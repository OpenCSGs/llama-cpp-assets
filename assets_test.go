package llamacppassets

import (
	"io/fs"
	"strings"
	"testing"
)

func TestBundledAssetsPresent(t *testing.T) {
	converter, err := fs.ReadFile(FS, ConverterPath)
	if err != nil {
		t.Fatalf("read converter: %v", err)
	}
	if len(converter) < 10_000 {
		t.Fatalf("converter looks truncated: %d bytes", len(converter))
	}

	initPath := GGUFPyRoot + "/gguf/__init__.py"
	if _, err := fs.Stat(FS, initPath); err != nil {
		t.Fatalf("gguf-py is missing %s: %v", initPath, err)
	}
	conversionInitPath := ConversionRoot + "/__init__.py"
	if _, err := fs.Stat(FS, conversionInitPath); err != nil {
		t.Fatalf("conversion package is missing %s: %v", conversionInitPath, err)
	}
}

func TestConverterIncludesCSGLiteMiniMaxPatch(t *testing.T) {
	const patchedHash = "a77756c3cc91392f442c5b99e414be8020d53ae31460de90754b4fcf5cc84a2d"
	base, err := fs.ReadFile(FS, ConversionRoot+"/base.py")
	if err != nil {
		t.Fatalf("read conversion base: %v", err)
	}
	if !strings.Contains(string(base), patchedHash) {
		t.Fatalf("conversion package is missing patched MiniMax tokenizer hash %q", patchedHash)
	}
}
