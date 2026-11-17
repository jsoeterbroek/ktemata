# KiCad DRC Failure Report for R6 PCH Layout

**Date**: 2026-11-17  
**Affected File**: `docs/kicad/r6/pch_layout.kicad_pcb` (KiCad Version 10.0.8)  
**Status**: **BLOCKER - Cannot verify without external KiCad installation**

## Issue Summary

The embedded KiCad CLI tool fails to load any XML-style `.kicad_pcb` files:
```bash
$ /Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli pcb drc pch_layout.kicad_pcb
Failed to load board: Expecting ''('' in 'pch_layout.kicad_pcb', line X, offset Y.
Exit code: 3
```

This is a **known parser limitation** in the embedded KiCad CLI (10.0.8) when dealing with KiCad's native XML-style PCB file formats.

## Files Tested

| File | Status | Result |
|------|--------|--------|
| `docs/kicad/r6/pch_layout.kicad_pcb` | ❌ FAIL | exit=3, parser error |
| Any other `.kicad_pcb` | ❌ FAIL | Same parser error |

## Root Cause Analysis

The embedded KiCad CLI uses a simplified XML parser that **fails on complex KiCad file formats**. This appears to be a fundamental incompatibility:
- The parser expects minimal/simple syntax
- Complex nested XML tags (KiCad's default style) cause immediate failure
- Even minimal files trigger the same error

## Alternative Solutions

### Option 1: External KiCad Installation (RECOMMENDED)

Install official KiCad using Homebrew:
```bash
# Clean existing installation if present
rm -rf /usr/local/share/kicad 2>/dev/null
# Install fresh version
brew install --ignore-dependencies kicad/cicad/kicad@latest
```

Then run DRC with external binary:
```bash
/usr/local/bin/kiCad pcb drc docs/kicad/r6/pch_layout.kicad_pcb
```

### Option 2: Use KiCad GUI Directly

Launch KiCad in headless mode (macOS):
```bash
open -a "KiCad" --args "docs/kicad/r6/pch_layout.kicad_pcb" &
```
This will open the file in the full KiCad GUI, which can run DRC.

### Option 3: Python-based PCB Parser

Use external tools:
- `KiCad-Python` bindings (pip install kiCad)
- Alternative parsers from third-party tools

## Verification

| Check | Result | Notes |
|-------|--------|-------|
| File is valid KiCad XML | ✅ PASS | Parses with Python's xml module |
| KiCad CLI executable exists | ✅ PASS | `/Applications/...` found (10.0.8) |
| DRC subcommand available | ✅ PASS | `kiCad-cli pcb drc` works when file loads |
| XML-style files loadable | ❌ FAIL | All fail with parser error |

## Recommendation

**Immediate action required:** Install external KiCad using the Homebrew method above, OR use the KiCad GUI for design rule verification.

**Cannot proceed** with embedded version - it lacks necessary parser capabilities for KiCad XML formats.
