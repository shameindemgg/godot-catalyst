# Godot Catalyst — Agent Guidance

Godot Catalyst gives you 240+ MCP tools for driving the Godot 4.x editor and inspecting Godot projects. Use these tools whenever the user is working on a Godot project instead of shell commands or manual file edits.

## When to reach for it

- User has a Godot project open or mentions `.tscn`, `.tres`, `.gd`, `project.godot`, scenes, nodes, resources
- Tasks that touch the editor: creating scenes, adding nodes, wiring signals, running the game, exporting
- Static analysis of Godot files even when the editor is not running (offline TSCN/TRES/GDScript parsing)
- Code intelligence through Godot's built-in LSP (diagnostics, completion, hover, go-to-definition)
- Debugging through Godot's DAP (breakpoints, stepping, variable inspection)

## Tool categories (39)

Foundation (status/ping), Scene, Node, Script, Resource, Editor, Project, Signal, Build, Manipulation2D, Manipulation3D, Animation, Audio, Physics, Navigation, Shader, Theme, Particle, Tilemap, File (offline parsing), LSP, Debug, Batch, Docs, Input, Profiling, Runtime, Asset (CC0 search), AIAsset, AssetPipeline, Spatial, Convention, Analysis, Plugin, Networking, Localization, VisualTesting, Visualization, Testing.

Tools are organized one file per category across the 39 categories listed above.

## Calling conventions

- Tools are namespaced. Names follow `<category>_<action>` (e.g. `scene_create`, `node_set_property`, `lsp_diagnostics`).
- Most mutating operations go through the editor's undo stack. Tell the user they can Ctrl+Z.
- Node paths accept Godot's standard syntax: `/root/Main/Player`, `Player/Sprite2D`.
- Vector and Color arguments take plain arrays or `{x,y,z}` objects. The type converter handles both.
- Operations that touch scene state require the target scene to be open in the editor. Check with `scene_list` or `scene_tree` first.
- Offline file tools (TSCN/TRES/project.godot parsers, GDScript templates) work without a running editor. Prefer these for read-only analysis of closed projects.
- Batch tools exist for bulk property changes and bulk node creation. Use them instead of N individual calls when N > 3.

## Mode hints

Tools have a mode system (full / lite / minimal / cli). If the user is on a tight context budget, suggest `minimal` or `lite`. Full mode exposes every parameter and return field.

## Failure modes

- WebSocket connection to port 6505 must be up. If tool calls hang or return connection errors, tell the user to check the status panel at the bottom of the Godot editor and re-enable the plugin.
- LSP tools need Godot's GDScript Language Server running (port 6005, on by default).
- DAP tools need the editor's debug server reachable (port 6006, starts when you hit Play with debugging enabled).
