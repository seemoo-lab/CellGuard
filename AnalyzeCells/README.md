# Analyze Cells

A Python script to analyze .cells2 files exported by CellGuard.

CellGuard's exported files are ZIP archives.
The analysis script extracts components from the archive and analyzes them.
Therefore, we advise you to manually inspect .cells2 files from third-party sources before using them with the analysis script.

## Usage

```sh
# Analyze export-2024-10-10_19-48-46.cells2
uv run analyze_cells2.py ./export-2024-10-10_19-48-46.cells2
```
