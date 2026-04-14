# Godot Catalyst

MCP server for [Godot 4.x](https://godotengine.org/) game development. 240+ tools across 39 categories. Works with Claude Code, Cursor, Windsurf, Copilot, Cline, and any other MCP client.

**$25 one-time purchase** — [portal.fireal.dev/godot-catalyst/](https://portal.fireal.dev/godot-catalyst/)

7-day free trial on first install. No account needed to try it.

## How it compares

| Feature | Godot Catalyst | GoPeak | godot-mcp-pro | Coding-Solo |
|---------|:-:|:-:|:-:|:-:|
| **Total tools** | **240+** | 110 | 169 | 15 |
| **Price** | **$25** | Free | $5 | Free |
| **LSP code intelligence** | Yes | Yes | No | No |
| **DAP debugging** | Yes | Yes | No | No |
| **Offline file parsing** | Yes | No | No | No |
| **CC0 asset search** | Yes | Yes | No | No |
| **AI asset generation** | Yes | No | No | No |
| **Input simulation** | Yes | No | Yes | No |
| **Performance profiling** | Yes | No | No | No |
| **Spatial intelligence** | Yes | No | No | No |
| **Convention enforcement** | Yes | No | No | No |
| **Networking tools** | Yes | No | No | No |
| **Localization tools** | Yes | No | No | No |
| **Visual testing** | Yes | No | No | No |
| **Dynamic tool modes** | Yes | Yes | Yes | No |
| **Batch operations** | Yes | No | No | No |

## Install

Requires [Node.js](https://nodejs.org/) >= 18 and Godot 4.x.

```bash
npx godot-catalyst --install-addon /path/to/your/godot-project
```

This installs the Godot plugin into your project's `addons/` folder. Open Godot, go to **Project > Project Settings > Plugins**, enable **Godot Catalyst**.

## Activate

The first install starts a 7-day trial. To activate a purchased license:

```bash
npx godot-catalyst --activate <your-license-key>
```

License keys arrive by email after purchase. Each license activates on up to 3 machines.

To deactivate a machine (freeing a slot):

```bash
npx godot-catalyst --deactivate
```

## Configure your MCP client

<details>
<summary><strong>Claude Code</strong></summary>

Add to `~/.claude/settings.json` or project `.claude/settings.json`:

```json
{
  "mcpServers": {
    "godot": {
      "command": "npx",
      "args": ["godot-catalyst"],
      "env": {
        "GODOT_PROJECT_PATH": "/path/to/your/godot/project"
      }
    }
  }
}
```
</details>

<details>
<summary><strong>Cursor</strong></summary>

Add to `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "godot": {
      "command": "npx",
      "args": ["godot-catalyst"],
      "env": {
        "GODOT_PROJECT_PATH": "/path/to/your/godot/project"
      }
    }
  }
}
```
</details>

<details>
<summary><strong>Windsurf / Cline / other MCP clients</strong></summary>

Most MCP clients share the same config format:

- **Command:** `npx`
- **Args:** `["godot-catalyst"]`
- **Env:** `GODOT_PROJECT_PATH` set to your Godot project root

Check your client's docs for the config file location.
</details>

### Enable LSP/DAP (optional, for code intelligence and debugging)

In Godot: **Editor > Editor Settings > Network > Language Server > Enable** (port 6005) and **Debug Adapter > Enable** (port 6006).

## What's in it

240+ tools spanning the full Godot editor surface:

| Category | Tools | Examples |
|----------|-------|----------|
| Foundation | 2 | Connection, ping |
| Scenes | 12 | Create, open, save, duplicate, reload |
| Nodes | 14 | CRUD, properties, search, groups, instancing |
| Scripts | 10 | Create, edit, attach, execute GDScript |
| Resources | 8 | CRUD, imports, dependencies, autoloads |
| Editor | 12 | Selection, undo/redo, settings, screenshots |
| Project | 10 | Settings, filesystem, input actions, stats |
| Signals | 6 | List, connect, disconnect, emit |
| Build | 6 | Play/stop, export |
| 2D | 8 | Sprites, collision, tilemap, camera, parallax |
| 3D | 10 | Meshes, materials, lights, CSG, environment |
| Animation | 10 | Tracks, keyframes, AnimationTree |
| Audio | 6 | Players, buses, effects |
| Physics | 6 | Bodies, shapes, raycasts |
| Navigation | 5 | Regions, agents, baking |
| Shaders | 6 | Create/edit/assign, parameters |
| Themes | 6 | Resources, colors, constants, styleboxes |
| Particles | 5 | GPU particles, materials, gradients |
| TileMaps | 6 | Cell operations, fill, clear |
| File Ops | 10 | Offline TSCN/TRES parsing, GDScript templates |
| LSP | 10 | Diagnostics, completion, hover, rename, format |
| Debug | 10 | Launch, breakpoints, step, stack, variables |
| Batch | 5 | Bulk get/set, create/delete |
| Docs | 4 | Offline class reference search |
| Input Simulation | 7 | Keyboard, mouse, touch, gamepad, record/replay |
| Profiling | 4 | FPS, memory, draw calls, bottleneck detection |
| Runtime | 4 | Live GDScript eval, tree inspection, console |
| CC0 Assets | 5 | Poly Haven, AmbientCG, Kenney search |
| AI Assets | 3 | Meshy/Tripo 3D generation |
| Asset Pipeline | 2 | Reimport, import settings |
| Spatial | 4 | Layout analysis, placement, overlap |
| Conventions | 3 | Naming/structure checks, auto-fix |
| Analysis | 3 | Architecture overview, dead code, dependencies |
| Plugins | 2 | Detect installed plugins |
| Networking | 6 | HTTP, WebSocket, multiplayer, RPC |
| Localization | 4 | CSV translations, locales |
| Visual Testing | 4 | Screenshots, pixel-diff, video, sequences |
| Visualization | 2 | Project maps, Mermaid/DOT diagrams |
| Integration Testing | 2 | GUT test runner, results |

## Tool modes

Some MCP clients can't handle 240+ tools. Set `GODOT_TOOL_MODE` to limit:

| Mode | Tools | When to use |
|------|-------|-------------|
| `full` | ~240 | Claude Code, Cursor (default) |
| `lite` | ~80 | Clients with moderate tool limits |
| `minimal` | ~30 | Copilot Chat, constrained clients |
| `cli` | ~14 | Offline-only, no Godot needed |

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GODOT_PROJECT_PATH` | (none) | Absolute path to your Godot project root (required) |
| `GODOT_TOOL_MODE` | `full` | Tool filter: `full`, `lite`, `minimal`, `cli` |
| `GODOT_WS_PORT` | `6505` | WebSocket port for the Godot plugin |
| `GODOT_WS_HOST` | `127.0.0.1` | WebSocket host |
| `GODOT_PATH` | `godot` | Path to the Godot executable |
| `GODOT_LSP_PORT` | `6005` | GDScript Language Server port |
| `GODOT_DAP_PORT` | `6006` | Debug Adapter Protocol port |
| `GODOT_DOCS_PATH` | (none) | Path to Godot XML class reference |
| `MESHY_API_KEY` | (none) | Meshy 3D model generation key |
| `TRIPO_API_KEY` | (none) | Tripo 3D model generation key |

## Support

Email: [support@fireal.dev](mailto:support@fireal.dev)

## License

The MCP server is proprietary — see [LICENSE](LICENSE). Purchase at [portal.fireal.dev/godot-catalyst/](https://portal.fireal.dev/godot-catalyst/).

The Godot editor plugin in this repo (`addons/godot_catalyst/`) is MIT-licensed.
