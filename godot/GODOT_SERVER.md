# Moving the Server into Godot

At some point you can run the **server logic inside Godot** too, so you have one engine for both client and server and can share types/constants (hex math, actions, unit types).

## Why move the server to Godot?

- **Single codebase** – Same language (GDScript), same hex/action logic, no Node.js dependency for the server.
- **Easier iteration** – Change a rule once, use it in both client and server.
- **Deploy options** – Export a Godot “server” build (headless or with `--headless`) and run it on a VPS, or run a second Godot instance as the host.

## Two approaches

### 1. WebSocket server in Godot (same protocol)

Keep the **exact same JSON protocol** as `server3.js`. The Godot server listens with `WebSocketServer`, parses JSON, updates game state, and broadcasts the same message types (`welcome`, `update`, `game_over`, etc.). Your **existing HTML client** and the **Godot client** can both connect without changes.

- **Pros:** Drop-in replacement for Node; HTML client still works.
- **Cons:** You reimplement all turn logic (movement, attacks, win conditions) in GDScript.

### 2. Godot Multiplayer API (Godot-only)

Use Godot’s built-in **multiplayer** (e.g. `MultiplayerAPI`, `ENetMultiplayerPeer` or WebSocket as transport). The “server” is the host peer; clients connect and call RPCs. You’d define custom RPCs instead of raw JSON (`submit_action`, `request_state`, etc.).

- **Pros:** Native sync, less manual serialization, good for Godot-only games.
- **Cons:** HTML client can’t connect unless you add a small bridge; more refactor of the current client.

**Recommendation for you:** Start with **option 1** (WebSocket + same JSON protocol) so the current HTML and Godot clients keep working. You can later add a Godot-only mode with the Multiplayer API if you want.

## What to port from `server3.js`

1. **WebSocket server** – Listen on a port, accept connections, assign `playerId`, send `welcome` (and handle `request_username` if your deploy does).
2. **Game state** – Same structures: `grid` (tiles by key), `players` (id, color, units, resources), `turn`, `playerActions`, `lastTurnActions`, `delayedActions`, `winConditions`, etc.
3. **Constants** – `ACTIONS`, `UNIT_TYPES`, `TileTypes`, `GameTypes`, hex directions, `GRID_SIZE`, `MAX_POWER_PER_UNIT`.
4. **Turn flow** – When all players have chosen color → `generateInitialGameState()`; when all have submitted actions → `executeTurn()` (movement, attacks, reload, extract, spawn, stun, delayed actions, remove defeated units, `calculateResources()`, win check).
5. **Validation** – Same rules: path adjacency, height/enterable directions, action key and power checks, etc.
6. **Broadcast** – On `update`, send the same `cleanState` shape so clients don’t need to change.

A practical order: get the Godot **WebSocket server** accepting connections and sending `welcome` (and optionally `request_username`), then port state and turn execution step by step, testing with the current Godot client.

## Minimal Godot WebSocket server (starter)

See `scripts/server/game_server.gd` for a minimal listener that:

- Listens on a port (e.g. 8080).
- Accepts WebSocket peers and assigns IDs.
- Sends `welcome` (and can send `request_username` first if you want).
- Reads JSON from each peer and echoes or dispatches by `type` (you’d plug in your game logic here).

You run this in a **separate Godot project** (or a dedicated “server” scene) that only runs the server script and has no UI, or run the same project with a “host” mode that starts the server and then opens the client scene.

## Running client vs server

- **Client-only:** Open the current project, run main scene → connects to Node or Godot server via URL in `game_state.gd`.
- **Server-only:** Run a Godot instance with the server scene/script, or export a headless build and run `./game_server --headless` (if you wire command-line or export to run server).
- **Local test:** Start the Godot server (e.g. port 8080), set `SERVER_URL = "ws://127.0.0.1:8080"` in the client, run the client in another Godot instance or from the editor.

Once the server logic lives in Godot, you can share `hex_grid.gd`, action keys, and unit/tile definitions between client and server and only maintain one codebase.
