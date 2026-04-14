# Godot Catalyst (public addon repo)

Public distribution of the Godot EditorPlugin half of Godot Catalyst, an MCP server for Godot 4.x game development. 240+ tools across 39 categories.

## What this repo is

Only the GDScript plugin that runs inside Godot. The TypeScript MCP server, licensing, parsers, and build tooling live in the private source repo at `x:/source/repos/godot-catalyst/`. This repo exists so users can inspect the code that runs in their editor and so npm can pull the addon files into their project.

Do dev work in the private repo. Mirror addon changes here. Never push private-only files (src/, licensing, audit, dist) to this remote.

## Pricing

- $25 one-time purchase
- $54 bundle with eyehands ($20 off vs buying separately)
- 7-day free trial on first install, no account needed

Prices are hardcoded in several places across both repos. If you change them, grep `x:/source/repos/` for every occurrence.

## Distribution

- npm package `godot-catalyst` (published from the private repo's `dist/`)
- `npx godot-catalyst --install-addon <path>` copies `addons/godot_catalyst/` into the user's Godot project
- Purchase and license activation go through Keystone at portal.fireal.dev

## Layout

See `CODE_INDEX.md` for the file-by-file breakdown.
