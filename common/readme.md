# Common Utilities

Cross-platform scripts and templates for general DBA work.

## Connectivity

| Script | Description |
|--------|-------------|
| `connection_test.sql` | Basic connectivity verification |
| `generate_refresh_stats.sql` | Generate ANALYZE/UPDATE STATISTICS commands |
| `generate_health_check.sql` | Template for periodic health reports |

## Usage

Each file contains sections for different databases. Copy the relevant block for your platform, or use as a template for custom scripts.

## Structure

```
common/
├── connection_test.sql       -- Version and session info
├── generate_refresh_stats.sql-- Statistics refresh generators
└── generate_health_check.sql -- Health report templates
```

These scripts serve as starting points. Customize thresholds and filters to match your environment.
