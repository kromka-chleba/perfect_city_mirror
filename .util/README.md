# .util Directory

This directory contains utilities for local development.

## .util/run_tests.sh

Local test runner for developers with Luanti/Minetest installed on their system.

**Usage:**
```bash
# From repository root
./.util/run_tests.sh
```

**Requirements:**
- Luanti/Minetest 5.12+ installed and in PATH

**Note:** For CI/Docker-based testing, use `./utils/test/run.sh` instead.

See `mods/pcity_mapgen/tests/TESTING.md` for detailed documentation.
