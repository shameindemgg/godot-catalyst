# Godot Catalyst (public addon) Code Index

Public mirror of the Godot EditorPlugin. The TypeScript MCP server and build system are in the private repo at `x:/source/repos/godot-catalyst/`.

## Architecture

MCP Client <-> TypeScript MCP Server (stdio, private repo) <-> this EditorPlugin (WebSocket:6505)

The plugin boots a TCPServer, upgrades incoming connections to WebSocket, parses JSON-RPC requests, and dispatches them through `tool_executor.gd` to one of 23 handler scripts.

## Directory Structure

### Root
- `README.md` — install instructions, feature comparison, activation flow
- `LICENSE` — license text for the public addon
- `icon.png` — addon icon

### `addons/godot_catalyst/` — Core plugin files
- `plugin.cfg` — Godot plugin manifest (name, version, entry script)
- `plugin.gd` — `EditorPlugin` subclass. Lifecycle hooks, WebSocket request routing, status panel registration
- `mcp_server.gd` — TCPServer + WebSocketPeer server on port 6505. Accepts connections, frames messages, emits request signals
- `tool_executor.gd` — Central dispatcher. Routes `namespace.action` calls to the correct handler script
- `status_panel.gd` / `status_panel.tscn` — Bottom-panel UI showing connection state and recent requests

### `addons/godot_catalyst/handlers/` — Request handlers (23 files, one per namespace)
- `animation_handler.gd` — AnimationPlayer, AnimationTree, tracks, keyframes
- `audio_handler.gd` — audio players, buses, effects
- `build_handler.gd` — play/stop scenes, export presets
- `editor_handler.gd` — selection, undo/redo, settings, screenshots, tabs
- `input_handler.gd` — keyboard, mouse, touch, gamepad, action simulation
- `manipulation_2d_handler.gd` — sprites, collision, tilemap, camera, parallax
- `manipulation_3d_handler.gd` — meshes, materials, lights, CSG, environment
- `navigation_handler.gd` — navigation regions, agents, baking
- `networking_handler.gd` — HTTP, WebSocket, multiplayer, RPC
- `node_handler.gd` — node CRUD, properties, search, groups, instancing
- `particle_handler.gd` — GPU particles, materials, gradients
- `physics_handler.gd` — physics bodies, collision shapes, raycasts
- `profiling_handler.gd` — performance metrics, profiler data
- `project_handler.gd` — project settings, filesystem, input actions, stats
- `resource_handler.gd` — resource CRUD, imports, dependencies, autoloads
- `runtime_handler.gd` — GDScript eval, runtime tree, node inspection, console
- `scene_handler.gd` — scene create/open/save/close/tree/duplicate/reload
- `script_handler.gd` — script CRUD, attach/detach, execute, search
- `shader_handler.gd` — shader create/edit/assign, parameters
- `signal_handler.gd` — signal list/connect/disconnect/emit
- `spatial_handler.gd` — layout analysis, placement, overlap detection
- `theme_handler.gd` — themes, colors, constants, styleboxes
- `tilemap_handler.gd` — tilemap cell operations, fill, clear

### `addons/godot_catalyst/util/` — Shared helpers
- `node_serializer.gd` — convert Godot `Node` trees to JSON-safe dicts and back
- `type_converter.gd` — Variant <-> JSON conversion for Vector2/3/4, Color, Transform, NodePath, etc.
- `undo_redo_helper.gd` — wraps `EditorUndoRedoManager` so handler actions land in the editor's undo stack

## Cross-references

- Full tool list (TypeScript side): `x:/source/repos/godot-catalyst/src/tools/`
- Handler-to-tool mapping: `x:/source/repos/godot-catalyst/CODE_INDEX.md`
- Protocol types: `x:/source/repos/godot-catalyst/src/protocol/`
