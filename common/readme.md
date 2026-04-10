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
├── connection_test.sql            -- Version and session info
├── generate_refresh_stats.sql     -- Statistics refresh generators
├── generate_health_check.sql      -- Health report templates
└── drawio/
    ├── drawio_style_guide.md      -- Full documentation
    ├── drawio_quick_reference.md  -- Quick copy-paste reference
    ├── drawio_template_light.xml  -- Light mode template
    ├── drawio_template_dark.xml    -- Dark mode template
    └── drawio_shapes_library.xml   -- Custom shapes library
```

These scripts serve as starting points. Customize thresholds and filters to match your environment.

## Draw.io Diagram Templates

Standardized templates for database and infrastructure architecture diagrams with support for light and dark modes.

### Quick Start
1. Open draw.io (app.diagrams.net or desktop app)
2. File → Open → select `drawio_template_light.xml` or `drawio_template_dark.xml`
3. Use the pre-configured shapes and styles to build your diagram

### Files
| File | Purpose |
|------|---------|
| `drawio_style_guide.md` | Full documentation with color palettes, shape standards, and patterns |
| `drawio_quick_reference.md` | Copy-paste ready style strings for quick diagram building |
| `drawio_template_*.xml` | Importable templates with all styles pre-configured |
| `drawio_shapes_library.xml` | Custom shapes for databases and infrastructure |

### Color Schemes
- **Light Mode:** Clean white background with Material Design-inspired colors
- **Dark Mode:** Dark slate background with adjusted colors for visibility
