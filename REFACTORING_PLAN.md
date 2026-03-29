# Board.gd Refactoring Plan

## Current Status (Phase 1: Utilities Extraction)

Board.gd is being incrementally refactored from 2158 lines into modular components.

### Completed ✅
- **BoardGridHelper.gd** (90 lines) - Static utility functions for grid operations
  - `is_in_grid()`, `is_cell_active()`, `is_adjacent()`
  - Array creation: `make_2d_array()`, `make_2d_int_array()`
  - Cell collection: `add_cell_unique()`, `append_row_to_cells()`, etc.
  - Added to autoload for global access

- **Board.gd reduced** from 2158 to ~2165 lines by:
  - Delegating grid operations to BoardGridHelper
  - Removing duplicate implementations
  - Adding #region markers for code organization

### Next Steps (Planned)

#### Phase 2: Match System (~400 lines to extract)
```
BoardMatchFinder.gd
- find_matches()
- check_for_bombs()
- bomb combo detection (chilli, camembert, mozzarella)
- special piece combinations
```

#### Phase 3: Physics System (~300 lines)
```
BoardPhysics.gd
- collapse_columns() - gravity
- swap_pieces() - piece swapping
- would_swap_create_match() - validation
- swap animation handling
```

#### Phase 4: Input Handling (~200 lines)
```
BoardInputHandler.gd
- _input() override
- touch/mouse event handling
- piece selection logic
- swap triggering
```

#### Phase 5: Goal System (~150 lines)
```
BoardGoalSystem.gd
- Goal progress tracking
- Different goal types (score, clear_color, bring_down, clear_ice, clear_mold)
- Goal completion checks
- Star calculation
```

#### Phase 6: Level Loading (~250 lines)
```
BoardLevelLoader.gd
- JSON level loading
- build_board_from_loaded_level()
- Obstacle setup (ice, mold)
- Tutorial system
```

### Architecture Notes

- Helpers are **static utility classes** (BoardGridHelper) - use as `ClassName.function()`
- System classes will be **inner classes** or **composition-based** to maintain references
- Board.gd remains the **orchestrator** connecting all systems
- No circular dependencies - all systems delegate up to Board

### Code Organization Markers

Board.gd now uses `#region` / `#endregion` markers:

```gdscript
#region === LIFECYCLE & INITIALIZATION ===
func _ready():
  ...
#endregion

#region === LEVEL LOADING ===
func load_level_data_json():
  ...
#endregion
```

Use Ctrl+K Ctrl+0/1 in VS Code to collapse/expand regions.

## Benefits

- ✅ Easier debugging - each system has ~200-400 lines max
- ✅ Reusable helpers - BoardGridHelper can be used by other systems
- ✅ Clearer separation of concerns
- ✅ Reduced cognitive load when editing
- ✅ Easier to add new features without bloat

## Testing Checklist

After each phase:
- [ ] Game starts level correctly
- [ ] Match detection works
- [ ] Gravity and swaps work
- [ ] Input handling responsive
- [ ] Goals track properly
- [ ] Level progression works
