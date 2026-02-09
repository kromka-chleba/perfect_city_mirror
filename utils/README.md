# Utils Directory

This directory contains utilities for CI/CD testing.

## utils/test/

Docker-based test runner used by GitHub Actions CI.

**Usage:**
```bash
# From repository root
DOCKER_IMAGE=ghcr.io/luanti-org/luanti:master ./utils/test/run.sh
```

**Note:** For local development testing, use `./.util/run_tests.sh` instead.

See `.github/workflows/test.yml` for CI usage.
