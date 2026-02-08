# PCity Mapgen Documentation

This directory contains comprehensive documentation for the Perfect City mapgen modules.

## Module Documentation

### Core Systems

- **[canvas.md](canvas.md)** - Canvas class for 2D citychunk data storage and manipulation
- **[megacanvas.md](megacanvas.md)** - Multi-canvas system for overgeneration across chunk boundaries
- **[canvas_ids.md](canvas_ids.md)** - Material ID definitions and priority system
- **[canvas_brushes.md](canvas_brushes.md)** - Shape generation and brush system

### Path and Point System

- **[docs_path.md](docs_path.md)** - Path class documentation (existing)
- **[path_utils.md](path_utils.md)** - 2D geometric utilities for path operations
- **[pathpaver.md](pathpaver.md)** - Point and path storage for citychunks

### Coordinate Systems and Utilities

- **[units.md](units.md)** - Unit conversion functions between coordinate systems
- **[sizes.md](sizes.md)** - Size constants and map division definitions
- **[utils.md](utils.md)** - High-level coordinate utilities and helper functions
- **[metastore.md](metastore.md)** - Metadata storage with weak tables

## Quick Reference

### Coordinate Systems

Perfect City uses three coordinate systems:

1. **Node** - Individual block positions (1x1x1)
2. **Mapchunk** - Minetest chunks (80x80x80 nodes default)
3. **Citychunk** - Perfect City chunks (800x800x800 nodes default)

See [units.md](units.md) for conversion functions and [sizes.md](sizes.md) for size constants.

### Material Priority System

Materials have priorities that determine what can overwrite what:

- 0: Blank (default)
- 1-4: Roads and pavements
- 5-9: Buildings (future)
- 1000+: Meta materials (algorithm markers)

See [canvas_ids.md](canvas_ids.md) for details.

### Common Workflows

#### Drawing Roads

```lua
-- Create canvas for citychunk
local canvas = pcmg.canvas.new(citychunk_origin)

-- Position cursor
canvas:set_cursor_absolute(world_pos)

-- Draw road
canvas:draw_rectangle(width, length, materials_by_name.road_asphalt, false)
```

#### Working with Paths

```lua
-- Create points
local start = pcmg.point.new(vector.new(0, 8, 0))
local finish = pcmg.point.new(vector.new(100, 8, 0))

-- Create path
local path = pcmg.path.new(start, finish)

-- Store in pathpaver
local paver = pcmg.pathpaver.new(citychunk_origin)
paver:save_path(path)
```

#### Overgeneration

For features crossing chunk boundaries, use Megacanvas:

```lua
local megacanv = pcmg.megacanvas.new(citychunk_origin)
megacanv:set_cursor_absolute(world_pos)
megacanv:draw_rectangle(200, 20, material_id, false)  -- Can cross boundaries
```

## Architecture Overview

### Generation Flow

1. **Mapgen callback** - Minetest calls for each mapchunk
2. **Canvas creation** - Create megacanvas for citychunk
3. **Layout generation** - Generate roads/features on canvas
4. **Writing** - Convert canvas to actual nodes
5. **Caching** - Cache completed citychunks

### Key Design Principles

- **Modularity** - Each file handles one concern
- **Caching** - Generated content is cached per citychunk
- **Weak tables** - Automatic memory cleanup
- **Deterministic** - Same seed produces same world
- **Overgeneration** - Features can extend across chunk boundaries

## File Organization

Each module follows this structure:

1. License header (AGPL-3.0-or-later)
2. Module documentation (block comments)
3. Dependencies and imports
4. Constants and configuration
5. Local helper functions
6. Public API functions
7. Return statement (if module)

See the [Coding Style Guidelines](../../../doc/CODING_STYLE.md) for full details.

## Contributing

When adding new modules:

1. Follow the coding style guidelines
2. Add comprehensive inline documentation
3. Create a markdown doc file in this directory
4. Update this README with links
5. Add usage examples in the doc file

## Related Documentation

- [Main Coding Style Guidelines](../../../doc/CODING_STYLE.md)
- [Perfect City Design Guide](../../../doc/Perfect_City_Design_Guide.md)

## Support

For questions or issues with the mapgen system, refer to:

1. This documentation directory
2. Inline code comments
3. The example code in tests/
4. The repository README
