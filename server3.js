const {
    ACTIONS,
    UNIT_TYPES,
    TileTypes,
    NUM_PLAYERS,
    MAX_PLAYERS,
    MAX_POWER_PER_UNIT,
    GRID_SIZE,
    actionOrder,
    hexDirections,
    cubeDirections,
    FACTIONS
  } = require('./gameConfig');
const WebSocket = require('ws');

const PORT = process.env.PORT || 8080;
const wss = new WebSocket.Server({ port: PORT });
//const wss = new WebSocket.Server({ host: '0.0.0.0', port: 8080 });

let game = {
    grid: {},  // Game grid
    players: [], // Array of player objects: { playerId, color, units, ws }
    turn: 1,
    playerActions: Array(NUM_PLAYERS).fill(null).map(() => []),  // Actions for each player
    //availableColors: ['#4CAF50', '#0000FF', '#FFA500', '#800080', '#FF0000', '#00FFFF'], //green, blue, orange, purple, red, cyan
    lastTurnActions: [], // Stores actions of the last turn
    delayedActions: [], // New array to store delayed actions
    actions: ACTIONS, // Add the ACTIONS object to the game state
    lastTurnDefeatedUnits: []
};

// Track connected clients (players)
const clients = [];

// Resource System
const resources = {}; // This will store all resource types and their properties

function createResource(name, attributes) {
    if (!resources[name]) {
        resources[name] = { ...attributes };
        console.log(`Resource '${name}' created with attributes`, attributes);
    }
}

// Create common resources (can be extended dynamically later)
createResource('gold', { description: 'Gold used for winning conditions', amount: 1 });
createResource('wood', { description: 'Wood used for building', amount: 2 });

// Tile Definition
class Tile {
    constructor(q, r, s, attributes = {}) {
        this.q = q;
        this.r = r;
        this.s = s;
        this.units = [];
        this.owner = null;
        this.resources = [];  // Can hold multiple resources like 'gold', 'wood', 'health'
        this.resourceQuantities = {}; // Resource quantities available for extraction
        this.resourceStorage = {}; // New: Store extracted resources
        this.type = attributes.type || 'default';  // **Added type property**
        this.color = attributes.color || '#e0e0e0';  // Default tile color
        this.actions = attributes.actions || [];  // List of actions this tile can perform (e.g., heal, spawn)
        this.height = attributes.height || 0;  // New property for height
        this.enterableFromDirections = [];  // Directions you can enter this tile from a lower height
    }

    // Add a resource to the tile
    addResource(resourceName, quantity = 0) {
        if (resources[resourceName]) {
            this.resources.push(resourceName);
            this.resourceQuantities[resourceName] = quantity;
            console.log(`Resource '${resourceName}' with quantity ${quantity} added to tile (${this.q}, ${this.r})`);
        }
    }

    extractResource(resourceName, amount) {
        if (this.resourceQuantities[resourceName] >= amount) {
            this.resourceQuantities[resourceName] -= amount;
            this.resourceStorage[resourceName] = (this.resourceStorage[resourceName] || 0) + amount;
            console.log(`Extracted ${amount} of ${resourceName} from tile (${this.q}, ${this.r}). Remaining: ${this.resourceQuantities[resourceName]}`);
        } else {
            console.log(`Not enough ${resourceName} to extract from tile (${this.q}, ${this.r}).`);
        }
    }
}

// Function to create a tile from a tile type
function createTileFromType(q, r, s, tileTypeKey, height, resourceQuantities) {
    const tileType = TileTypes[tileTypeKey] || TileTypes.default;  // Fallback to default if not found
    const tile = new Tile(q, r, s, {
        color: tileType.color,
        type: tileTypeKey,
        actions: tileType.actions || [],
        height: height || 0,  // Set the height here
        resourceQuantities: resourceQuantities,
    });

    // Add resources with specified quantities
    if (tileType.resources) {
        tileType.resources.forEach(resourceName => {
            const quantity = resourceQuantities[resourceName] || 0;
            tile.addResource(resourceName, quantity);
        });
    }

    return tile;
}

// Dynamically generate a grid with predefined tile types
function generateInitialGameState() {

    for (let q = -GRID_SIZE + 1; q <= GRID_SIZE - 1; q++) {
        for (let r = -GRID_SIZE + 1; r <= GRID_SIZE - 1; r++) {
            const s = -q - r;
            if (Math.abs(s) < GRID_SIZE) {
                let tileType = 'default';  // Default tile type
                let height = 0
                let resourceQuantities = null;

                // Define specific locations for tile types (this can be randomized or expanded)
                if (q === 0 && r === 0) {
                    tileType = 'gold';
                    resourceQuantities = { gold: 10 };
                    //height = 2;// Central tile is a gold tile
                } else if (q === -2 && r === 2) {
                    tileType = 'gold';
                    resourceQuantities = { gold: 5 };
                } else if (q === -2 && r === 0) {
                    tileType = 'gold';
                    resourceQuantities = { gold: 5 };
                } else if (q === 0 && r === -2) {
                    tileType = 'gold';
                    resourceQuantities = { gold: 5 };
                } else if (q === 2 && r === -2) {
                    tileType = 'gold';
                    resourceQuantities = { gold: 5 };
                } else if (q === 2 && r === 0) {
                    tileType = 'gold';
                    resourceQuantities = { gold: 5 };
                } else if (q === 0 && r === 2) {
                    tileType = 'gold';
                    resourceQuantities = { gold: 5 };
                }

                // Create the tile using the predefined type
                const tile = createTileFromType(q, r, s, tileType, height, resourceQuantities);
                game.grid[`${q},${r}`] = tile;
            }
        }
    }

    // Compute enterable directions after all tiles are created
    computeEnterableDirections();

    // Dynamically determine the starting positions based on the number of players
    const startPositions = getStartPositions(game.players.length);

    // Place initial units for each player based on their selected faction
    for (let i = 0; i < game.players.length; i++) {
        const [startQ, startR] = startPositions[i];
        const player = game.players[i];

        console.log(`Player ${player.playerId} chose faction: ${player.faction}`);

        // Use the faction's defined initial units from FACTIONS configuration
        const initialUnits = FACTIONS[player.faction].initialUnits;
        initialUnits.forEach((unitType) => {
        spawnUnit(player, startQ, startR, unitType);
        });
    }
}

// Function to calculate evenly distributed start positions based on the number of players
function getStartPositions(numPlayers) {
    const startPositions = [];
    const radius = GRID_SIZE - 1;

    switch (numPlayers) {
        case 2:
            startPositions.push([0, -radius]);
            startPositions.push([0, radius]);
            break;
        case 3:
            startPositions.push([0, -radius]);
            startPositions.push([-radius, radius]);
            startPositions.push([radius, 0]);
            break;
        case 4:
            startPositions.push([-1, -radius + 1]);
            startPositions.push([-radius, radius - 1]);
            startPositions.push([1, radius - 1]);
            startPositions.push([radius, -radius + 1]);
            break;
        case 5:
            startPositions.push([0, -radius]);
            startPositions.push([-radius, 1]);
            startPositions.push([-Math.floor(radius / 2), radius]);
            startPositions.push([Math.floor(radius / 2), Math.floor(radius / 2)]);
            startPositions.push([radius, -radius+1]);
            break;
        case 6:
            startPositions.push([0, -radius]);
            startPositions.push([-radius, 0]);
            startPositions.push([-radius, radius]);
            startPositions.push([0, radius]);
            startPositions.push([radius, 0]);
            startPositions.push([radius, -radius]);
            break;
        default:
            console.error(`Unsupported number of players: ${numPlayers}`);
            break;
    }

    return startPositions;
}

function computeEnterableDirections() {
    // For each tile in the grid
    for (const key in game.grid) {
        const tile = game.grid[key];
        tile.enterableFromDirections = [];  // Reset the array

        // For each of the 6 hex directions
        for (let dir = 0; dir < 6; dir++) {
            const direction = hexDirections[dir];
            const neighborQ = tile.q + direction.dq;
            const neighborR = tile.r + direction.dr;
            const neighborKey = `${neighborQ},${neighborR}`;
            const neighborTile = game.grid[neighborKey];

            if (neighborTile) {
                // Check if neighbor's height is one less
                if (neighborTile.height === tile.height - 1) {
                    // You can enter this tile from the neighbor in this direction
                    tile.enterableFromDirections.push(dir);
                }
            }
        }
    }
}

// Function to spawn new units on a tile for a player
function spawnUnit(player, q, r, unitTypeKey) {
    const unitType = UNIT_TYPES[unitTypeKey];
    if (!unitType) {
        console.log(`Invalid unit type: ${unitTypeKey}`);
        return;
    }
    const power = unitType.startingPower ? unitType.startingPower : 1;

    const tile = game.grid[`${q},${r}`];
    if (tile) {
        const newUnit = {
            unitId: generateUnitId(),
            playerId: player.playerId,
            strength: unitType.strength,
            tile: { q: tile.q, r: tile.r },
            power: power,
            type: unitTypeKey,
            color: unitType.color,
            actions: unitType.actions,
            passiveActions: unitType.passiveActions
        };
        tile.units.push(newUnit);
        player.units.push(newUnit);
        console.log(`Player ${player.playerId} spawned a ${unitType.name} unit on tile (${tile.q}, ${tile.r}).`);
    }
}

function calculateResources() {
    game.players.forEach(player => {
        // Initialize player's resources for this calculation
        player.resources = {};

        // Create a set to store the tiles controlled by the player
        const controlledTiles = new Set();

        // Determine which tiles are controlled by the player
        for (const key in game.grid) {
            const tile = game.grid[key];
            const exclusivelyControlled =
                tile.units.every(unit => unit.playerId === player.playerId) && tile.units.length > 0;

            if (exclusivelyControlled) {
                controlledTiles.add(tile);
            }
        }

        // Calculate resources accessible to the player from controlled tiles
        controlledTiles.forEach(tile => {
            for (const resourceName in tile.resourceStorage) {
                const amount = tile.resourceStorage[resourceName];
                if (amount > 0) {
                    player.resources[resourceName] = (player.resources[resourceName] || 0) + amount;
                }
            }
        });

        console.log(`Player ${player.playerId} now has resources:`, player.resources);

         // Check for custom win conditions after resource calculation
         if (winCondition(player)) {
            console.log(`Player ${player.playerId} meets the win conditions!`);
            endGame([player]);
            return; // Exit the loop early since the game is ending
        }
    });
}

// Helper function to find starting tiles around the initial position
function findStartingTiles(q, r, numUnits) {
    const directions = [
        [1, 0], [1, -1], [0, -1],
        [-1, 0], [-1, 1], [0, 1]
    ];

    const visited = new Set(); // Keep track of visited tiles to avoid duplicates
    const queue = [[q, r]]; // Start BFS with the starting position
    const tiles = [];

    visited.add(`${q},${r}`);

    // BFS to find the closest available tiles
    while (queue.length > 0 && tiles.length < numUnits) {
        const [currentQ, currentR] = queue.shift();
        const tileKey = `${currentQ},${currentR}`;

        // Only add valid tiles that are inside the game grid
        if (game.grid[tileKey]) {
            tiles.push([currentQ, currentR]);
        }

        // Explore neighboring tiles
        for (let i = 0; i < directions.length; i++) {
            const [dq, dr] = directions[i];
            const newQ = currentQ + dq;
            const newR = currentR + dr;
            const newTileKey = `${newQ},${newR}`;

            if (!visited.has(newTileKey)) {
                visited.add(newTileKey);
                queue.push([newQ, newR]);
            }
        }
    }

    return tiles.slice(0, numUnits); // Return only the number of required tiles
}

let unitIdCounter = 1;
function generateUnitId() {
    return unitIdCounter++;
}

wss.on('connection', function connection(ws) {
    console.log('A new player connected');

    ws.send(JSON.stringify({ type: 'request_username', message: 'Please enter your username to continue.' }));

    ws.on('message', function incoming(message) {
        const data = JSON.parse(message);
        console.log(data)

        if (data.type === 'username') {
            const username = data.username.trim();
            const existingPlayer = game.players.find(p => p.username === username);

            if (existingPlayer) {
                // Reconnection logic
                existingPlayer.ws = ws;
                ws.playerId = existingPlayer.playerId;
                clients[existingPlayer.playerId - 1] = ws;
                console.log(`Player ${username} reconnected.`);
                // 1) Let the client know they reconnected
                ws.send(JSON.stringify({
                    type: 'reconnected',
                    message: 'Welcome back!',
                    playerId: existingPlayer.playerId
                }));

                // 2) Send the actions_list again
                ws.send(JSON.stringify({
                    type: 'actions_list',
                    actions: game.actions, // Send actions list
                    action_order: actionOrder
                }));
                broadcastGameState();
            } else {
                // New connection logic
                if (clients.length >= MAX_PLAYERS) {
                    ws.send(JSON.stringify({ type: 'error', message: 'Game is full.' }));
                    ws.close();
                    return;
                }

                const playerId = clients.length + 1;
                // Initialize player with a null faction (to be selected next)
                const player = {
                    playerId: playerId,
                    username: username,
                    faction: null,       // Faction will be selected by the player
                    color: null,         // Will be assigned based on faction selection
                    units: [],
                    ws: ws,
                    resources: {}
                };
  

                game.players.push(player);
                clients.push(ws);
                ws.playerId = playerId;

                console.log(`Player ${username} joined the game.`);

                // Send welcome message with available factions for selection
                ws.send(JSON.stringify({
                    type: 'welcome',
                    playerId: playerId,
                    message: 'Welcome to the game! Please select a faction.',
                    availableFactions: FACTIONS
                }));
            }
        }
        
        if (data.type === 'faction_selection') {
            handleFactionSelection(ws.playerId, data);
        }

        if (data.type === 'action') {
            handleAction(ws.playerId, data.action);
        }

        if (data.type === 'restart') {
            handleRestart(ws.playerId);
        }
    });

    ws.on('close', function () {
        const player = game.players.find(p => p.playerId === ws.playerId);
        if (player) {
            console.log(`Player ${player.username} disconnected.`);
            handleDisconnect(ws.playerId);
        } else {
            console.log('A player disconnected, but no matching username was found.');
        }
    });
});

// --- NEW: Handle faction selection --- //
function handleFactionSelection(playerId, data) {
    const player = game.players.find(p => p.playerId === playerId);
    if (!player) return;
  
    const { faction } = data; // expecting data.faction to be a key such as 'red', 'purple', etc.
    if (!FACTIONS[faction]) {
      player.ws.send(JSON.stringify({ type: 'error', message: 'Invalid faction selection.' }));
      return;
    }
  
    // Assign faction to the player and set their color based on faction configuration
    player.faction = faction;
    player.color = FACTIONS[faction].color;
  
    console.log(`Player ${playerId} selected faction ${faction}`);
  
    // Notify the player that faction selection was successful along with faction details
    player.ws.send(JSON.stringify({ 
      type: 'faction_selected', 
      faction: faction, 
      factionInfo: FACTIONS[faction] 
    }));
  
    // (Optionally, you can broadcast to other players that this player has selected a faction)
  
    // If all players have selected a faction, start the game
    if (game.players.every(p => p.faction)) {
      game.playerActions = Array(game.players.length).fill(null).map(() => []);
      initializeGame();        
    }
}


function initializeGame() {
    console.log("All players have selected colors. Initializing game...");

    // Additionally, send the ACTIONS list to all clients
    broadcast({
        type: 'actions_list',
        actions: game.actions, // Send actions list
        action_order: actionOrder
    });

    // Initialize game grid and units
    generateInitialGameState();

    // Broadcast initial game state to all players
    broadcastGameState();

    console.log("ACTIONS list sent to all clients.");
}

// Ensure handleAction can handle the new action type
function handleAction(playerId, action) {
    const playerIndex = playerId - 1;

    if (!game.playerActions[playerIndex]) {
        game.playerActions[playerIndex] = [];
    }

    console.log(action)
    const actionKey = action.actionKey;

    // Step 1: Validate actionKey exists in server's ACTIONS
    const serverActionDef = ACTIONS[actionKey];
    if (!serverActionDef) {
        console.log(`Invalid action key received: ${actionKey}`);
        game.players[playerIndex].ws.send(JSON.stringify({ type: 'error', message: `Invalid action key: ${actionKey}` }));
        return;
    }

    // Step 2: Validate action parameters
    const unit = findUnitById(action.unitId);
    if (!unit) {
        console.log(`Unit ${action.unitId} not found.`);
        game.players[playerIndex].ws.send(JSON.stringify({ type: 'error', message: `Unit ${action.unitId} not found.` }));
        return;
    }

    // Step 3: Validate if the unit can perform the action
    if (!unit.actions.includes(actionKey)) {
        console.log(`Unit ${unit.unitId} cannot perform action ${actionKey}.`);
        game.players[playerIndex].ws.send(JSON.stringify({ type: 'error', message: `Unit cannot perform action: ${actionKey}` }));
        return;
    }

    // Step 4: Check if the unit has enough power
    if (unit.power < serverActionDef.powerConsumption) {
        console.log(`Unit ${action.unitId} does not have enough power for action ${actionKey}.`);
        game.players[playerIndex].ws.send(JSON.stringify({ type: 'error', message: `Not enough power for action ${actionKey}.` }));
        return;
    }

    // Step 5: Check if the tile has the required resources
    const tile = game.grid[`${unit.tile.q},${unit.tile.r}`];
    if (!tile) {
        console.log(`Tile (${unit.tile.q}, ${unit.tile.r}) not found.`);
        game.players[playerIndex].ws.send(JSON.stringify({ type: 'error', message: `Invalid tile: (${unit.tile.q}, ${unit.tile.r}).` }));
        return;
    }

    if (serverActionDef.resourceCost) {
        for (const [resource, amount] of Object.entries(serverActionDef.resourceCost)) {
            if ((tile.resourceStorage[resource] || 0) < amount) {
                console.log(`Not enough ${resource} on tile (${tile.q}, ${tile.r}).`);
                game.players[playerIndex].ws.send(JSON.stringify({ type: 'error', message: `Not enough ${resource} on tile.` }));
                return;
            }
        }

        // Deduct resources from the tile
        for (const [resource, amount] of Object.entries(serverActionDef.resourceCost)) {
            tile.resourceStorage[resource] -= amount;
            console.log(`Deducted ${amount} ${resource} from tile (${tile.q}, ${tile.r}). Remaining: ${tile.resourceStorage[resource]}`);
        }
    }

    // For actions with maxRange > 0, validate action.path
    if (serverActionDef.maxRange > 0) {
        // Validate action.path
        if (!Array.isArray(action.path) || action.path.length < 2) {
            game.players[playerIndex].ws.send(JSON.stringify({ type: 'error', message: `Invalid action path for action: ${actionKey}` }));
            return;
        }

        // Validate path length
        if (action.path.length - 1 > serverActionDef.maxRange) {
            game.players[playerIndex].ws.send(JSON.stringify({ type: 'error', message: `Action path exceeds maximum range.` }));
            return;
        }

        // Validate each step in the path
        if (validateMovement(unit, action.path) === false){
            return;
        }
    }

    // Store the action
    const existingActionIndex = game.playerActions[playerIndex].findIndex(a => a.unitId === action.unitId);
    if (existingActionIndex !== -1) {
        // Replace existing action
        game.playerActions[playerIndex][existingActionIndex] = action;
        console.log(`Replaced action for unit ${action.unitId} with new action`, action);
    } else {
        // Add new action
        game.playerActions[playerIndex].push(action);
        console.log(`Stored new action for unit ${action.unitId}`, action);
    }
    const playerAction = game.playerActions[playerIndex]

    // Check if all players are ready
    if (areAllPlayersReady()) {
        console.log(`All Players Ready. Executing Turn ${game.turn}...`);
        executeTurn();
    } else {
        broadcast({
            type: 'player_action',
            action: {
                playerId,
                playerAction
            }
        });
    }
}

function validateMovement(unit, path) {
    let currentTile = game.grid[`${unit.tile.q},${unit.tile.r}`];

    for (let i = 1; i < path.length; i++) {
        const nextCoords = path[i];
        const nextTile = game.grid[`${nextCoords.q},${nextCoords.r}`];

        if (!nextTile) {
            console.log(`Tile (${nextCoords.q}, ${nextCoords.r}) does not exist.`);
            return false;
        }

        const distance = hexDistance(currentTile, nextTile);
        if (distance !== 1) {
            console.log(`Tiles (${currentTile.q}, ${currentTile.r}) and (${nextTile.q}, ${nextTile.r}) are not adjacent.`);
            return false;
        }

        // Calculate direction from currentTile to nextTile
        const direction = getDirectionIndex(currentTile, nextTile);

        // Check height difference and enterable directions
        if (nextTile.height > currentTile.height + 1) {
            console.log(`Cannot move from tile (${currentTile.q}, ${currentTile.r}) to higher tile (${nextTile.q}, ${nextTile.r}). Height difference too great.`);
            return false;
        } else if (nextTile.height === currentTile.height + 1) {
            // Moving uphill by one
            if (!nextTile.enterableFromDirections.includes((direction + 3) % 6)) {
                console.log(`Cannot enter tile (${nextTile.q}, ${nextTile.r}) from direction ${direction}.`);
                return false;
            }
        }

        currentTile = nextTile;
    }
    return true;
}

function hexDistance(tile1, tile2) {
    return (Math.abs(tile1.q - tile2.q) + Math.abs(tile1.r - tile2.r) + Math.abs((-tile1.q - tile1.r) - (-tile2.q - tile2.r))) / 2;
}

function findUnitById(unitId) {
    for (let player of game.players) {
        for (let unit of player.units) {
            if (unit.unitId === unitId) {
                return unit;
            }
        }
    }
    return null;
}

function areAllPlayersReady() {
    for (let i = 0; i < game.players.length; i++) {
        const player = game.players[i];
        const actions = game.playerActions[i];
        const unitCount = player.units.length;
        const actionCount = actions.length;

        // Check if the number of actions equals the number of units
        if (actionCount !== unitCount) {
            return false;
        }

        // Additionally, ensure each unit has one action
        const unitsWithActions = new Set(actions.map(a => a.unitId));
        if (unitsWithActions.size !== unitCount) {
            return false;
        }
    }
    return true;
}

function executeTurn() {
    console.log(`Executing Turn ${game.turn}...`);

    // Add passive actions for all units
    addPassiveActions();

    

    // Initialize arrays to store current turn's actions
    game.lastTurnActions = [];

    // Validate and prepare all player actions
    const validActions = [];
    game.playerActions.forEach((playerActions, playerIndex) => {
        playerActions.forEach(action => {
            const result = validateAndPrepareAction(action);
            if (result) {
                validActions.push(result); // Store valid actions for processing
            } else {
                console.log(`Action ${action.actionKey} from Player ${game.players[playerIndex].playerId} is invalid.`);
                // Optionally notify the player about invalid actions here
                game.players[playerIndex].ws.send(JSON.stringify({
                    type: 'error',
                    message: `Invalid action: ${action.actionKey}`
                }));
            }
        });
    });

    const immediateActions = [];
    validActions.forEach(actionData => {
        const actionDefinition = actionData.actionDefinition;

        if (actionDefinition.duration && actionDefinition.duration > 0) {
            console.log(`Action '${actionDefinition.key}' has a duration of ${actionDefinition.duration} turns.`);
    
            // Push the action to immediateActions for current execution
            immediateActions.push(actionData);
    
            // Schedule the action for each turn within the duration
            for (let i = 1; i <= actionDefinition.duration; i++) {
                game.delayedActions.push({
                    turn: game.turn + i, // Schedule for future turns
                    actionData
                });
                console.log(`Scheduled delayed action '${actionDefinition.key}' for turn ${game.turn + i}`);
            }
        } else if (actionDefinition.delay && actionDefinition.delay > 0) {
            console.log(`Action '${actionDefinition.key}' delayed for ${actionDefinition.delay} turns.`);

            // Reconstruct the path and validate adjacency
            let pathTiles = [];
            pathTiles = getPathTiles(actionData.path);

            // Set currentTile and targetTile based on the path
            const currentTile = pathTiles[0];
            const targetTile = pathTiles[pathTiles.length - 1];
            let fromTile;
            if (pathTiles.length === 1) {
                fromTile = currentTile; // Self-targeting
            } else {
                fromTile = pathTiles[pathTiles.length - 2];
            }

            const aoeTiles = getAoETiles(fromTile, targetTile, actionDefinition.areaOfEffect);

            // Store the delayed action in the game state
            game.delayedActions.push({
                turn: game.turn + actionDefinition.delay, // Execute after delay
                actionData,
                aoeTiles
            });
        } else {
            immediateActions.push(actionData);
        }
    });

    // Add delayed actions to player actions
    addDelayedActions();

    // **Combine Immediate Actions and Delayed Actions for Processing**
    let actionsToProcess = immediateActions.concat(game.currentTurnDelayedActions || []);
    delete game.currentTurnDelayedActions; // Clear for the next turn

    // Organize actions by type for processing
    const actionsByType = {};
    actionsToProcess.forEach(actionData => {
        const actionType = actionData.actionDefinition.type;
        if (!actionsByType[actionType]) {
            actionsByType[actionType] = [];
        }
        actionsByType[actionType].push(actionData);
    });

    actionOrder.forEach(({ type, color }) => {
        // type: e.g. 'move', 'attack', ...
        // color: e.g. '#0000FF', ...
        const actions = actionsByType[type] || [];
        switch (type) {
            case 'fast move':
            case 'move':
            case 'slow move':
                processMovementActions(actions);
                break;
            case 'fast attack':
            case 'attack':
            case 'slow attack':
                    processAttackActions(actions);
                    break;
            case 'stun':
                processStunActions(actions, actionsByType);
                break;
            case 'spawn':
                actions.forEach(actionData => {
                    processSpawnAction(actionData);
                });
                break;
            case 'reload':
                processReloadActions(actions);
                break;
            case 'extract':
                processExtractResourceActions(actions);
                break;
            case 'evolve':
                processEvolveActions(actions);
                break;
            // Add more cases here for new action types
            default:
                console.log(`Unhandled action type: ${actionType}`);
        }
    });

    // After processing all actions, remove defeated units and calculate resources
    removeDefeatedUnits();
    calculateResources();

    // Grow resources on tiles
    growResources();

    // Clear player actions for the next turn
    game.playerActions = Array(game.players.length).fill(null).map(() => []);

    // Increment turn
    game.turn += 1;

    // Broadcast the updated game state to all players
    broadcastGameState();
}

function addPassiveActions() {
    console.log("Adding passive actions for all units...");

    game.players.forEach((player, playerIndex) => {
        player.units.forEach(unit => {
            const unitType = UNIT_TYPES[unit.type];
            if (!unitType || !unitType.passiveActions || unitType.passiveActions.length === 0) {
                return;
            }

            unitType.passiveActions.forEach(actionKey => {
                const actionDef = ACTIONS[actionKey];
                if (!actionDef) {
                    console.log(`Invalid action key '${actionKey}' in passiveActions for unit type '${unit.type}'`);
                    return;
                }

                // Create a passive action entry
                const passiveAction = {
                    actionKey: actionKey,
                    unitId: unit.unitId
                };

                // Add the passive action to the player's actions
                game.playerActions[playerIndex].push(passiveAction);
                console.log(`Added passive action '${actionKey}' for unit ${unit.unitId} of player ${player.playerId}`);
            });
        });
    });

    console.log("Passive actions added.");
}

function addDelayedActions() {
    console.log("Adding delayed actions to current turn's actions...");

    // Filter actions that should be executed this turn
    const actionsToAdd = game.delayedActions.filter(action => action.turn === game.turn);

    // Remove the actions that are being processed this turn
    game.delayedActions = game.delayedActions.filter(action => action.turn > game.turn);

    // Prepare an array to hold delayed actions for this turn
    game.currentTurnDelayedActions = [];

    actionsToAdd.forEach(delayedAction => {
        const { actionData } = delayedAction;

        // Since actions were already validated, we can use them directly
        game.currentTurnDelayedActions.push(actionData);

        console.log(`Added delayed action '${actionData.actionDefinition.name}' for execution on turn ${game.turn}`);
    });
}

function getAffectedUnits(attacker, targetTile, actionDefinition) {
    let affectedUnits = targetTile.units;

    // Filter units based on applyTo
    switch (actionDefinition.applyTo) {
        case 'friendly':
            affectedUnits = affectedUnits.filter(unit => unit.playerId === attacker.playerId);
            break;
        case 'enemies':
            affectedUnits = affectedUnits.filter(unit => unit.playerId !== attacker.playerId);
            break;
        case 'all':
            // No filtering needed
            break;
        case 'none':
            affectedUnits = [];
            break;
        default:
            affectedUnits = [];
            break;
    }

    // Include the attacker if self is true
    if (actionDefinition.self && targetTile.units.includes(attacker)) {
        if (!affectedUnits.includes(attacker)) {
            affectedUnits.push(attacker);
        }
    }

    return affectedUnits;
}

function validateAndPrepareAction(actionData) {
    const unit = findUnitById(actionData.unitId);
    if (!unit) {
        console.log(`Unit ${actionData.unitId} not found.`);
        return null;
    }

    const actionDefinition = ACTIONS[actionData.actionKey];
    if (!actionDefinition) {
        console.log(`Action definition for '${actionData.actionKey}' not found.`);
        return null;
    }
    
    // Attach actionDefinition to actionData for later use
    actionData.unit = unit;
    actionData.actionDefinition = actionDefinition;

    // Check if the unit has enough power
    if (unit.power < actionDefinition.powerConsumption) {
        console.log(`Unit ${unit.unitId} does not have enough power for action ${actionData.actionKey}.`);
        return null;
    }

    // Deduct power
    unit.power -= actionDefinition.powerConsumption;
    console.log(`Unit ${unit.unitId} power deducted by ${actionDefinition.powerConsumption}. New power: ${unit.power}`);

    return { ...actionData, unit, actionDefinition };
}

function processStunActions(stunActions, actionsByType) {
    if (stunActions.length === 0) {
        return;
    }

    console.log(`Processing ${stunActions.length} stun actions...`);

    let stunnedUnitsMap = new Map();

    stunActions.forEach(actionData => {
        const { unit: attacker, actionDefinition } = actionData;

        // Validate the action path
        let path = actionData.path;
        if (!Array.isArray(path) || path.length < 1) {
            console.log(`No path provided for unit ${attacker.unitId}. Defaulting to current tile for ${actionDefinition.key}.`);
            path = [{ q: attacker.tile.q, r: attacker.tile.r }];
        }

        // Reconstruct the path and validate adjacency
        let pathTiles = [];
        let currentTile = game.grid[`${path[0].q},${path[0].r}`];

        if (!currentTile) {
            console.log(`Starting tile (${path[0].q}, ${path[0].r}) does not exist.`);
            return;
        }

        pathTiles.push(currentTile);

        for (let i = 1; i < path.length; i++) {
            const nextCoords = path[i];
            const nextTile = game.grid[`${nextCoords.q},${nextCoords.r}`];

            if (!nextTile) {
                console.log(`Tile (${nextCoords.q}, ${nextCoords.r}) does not exist.`);
                return;
            }

            const distance = hexDistance(currentTile, nextTile);
            if (distance !== 1) {
                console.log(`Tiles (${currentTile.q}, ${currentTile.r}) and (${nextTile.q}, ${nextTile.r}) are not adjacent.`);
                return;
            }

            currentTile = nextTile;
            pathTiles.push(currentTile);
        }

        // Set targetTile based on the path
        const targetTile = pathTiles[pathTiles.length - 1];

        // Identify units to be stunned
        let affectedUnits = targetTile.units;

        affectedUnits = getAffectedUnits(attacker, targetTile, actionDefinition);

        if (affectedUnits.length === 0) {
            console.log(`No valid targets on tile (${targetTile.q}, ${targetTile.r}).`);
            return;
        }

        affectedUnits.forEach(unit => {
            if (!stunnedUnitsMap.has(unit.unitId)) {
                stunnedUnitsMap.set(unit.unitId, new Set());
            }
            const disabledActions = actionDefinition.disableActions || [];
            disabledActions.forEach(disabledActionType => {
                stunnedUnitsMap.get(unit.unitId).add(disabledActionType);
            });
            console.log(`Unit ${unit.unitId} will have actions ${[...stunnedUnitsMap.get(unit.unitId)]} disabled.`);
        });

        // Record the stun action for visualization
        game.lastTurnActions.push({
            type: actionDefinition.key,
            unitId: attacker.unitId,
            from: { q: attacker.tile.q, r: attacker.tile.r },
            to: { q: targetTile.q, r: targetTile.r },
            playerId: attacker.playerId
        });
    });

    // Update actionsByType to remove disabled actions for stunned units
    for (const [actionType, actions] of Object.entries(actionsByType)) {
        actionsByType[actionType] = actions.filter(actionData => {
            const unitId = actionData.unit.unitId;
            const actionDef = actionData.actionDefinition;

            // Check if the unit is stunned and the action is disabled
            if (stunnedUnitsMap.has(unitId)) {
                const disabledActionTypes = stunnedUnitsMap.get(unitId);
                if (disabledActionTypes.has(actionDef.type)) {
                    console.log(`Removing action '${actionDef.key}' for stunned unit ${unitId}.`);
                    return false; // Remove this action
                }
            }
            return true; // Keep this action
        });
    }
}

// 3. Refactor common code into helper functions
function moveUnit(unit, targetTile) {
    const currentTileKey = `${unit.tile.q},${unit.tile.r}`;
    const currentTile = game.grid[currentTileKey];

    // Remove unit from its current tile
    const unitIndex = currentTile.units.findIndex(u => u.unitId === unit.unitId);
    if (unitIndex !== -1) {
        currentTile.units.splice(unitIndex, 1);
    }

    // Add unit to the target tile
    targetTile.units.push(unit);
    unit.tile = { q: targetTile.q, r: targetTile.r }; // Update unit's tile coordinates

    // Update tile ownership
    targetTile.owner = unit.playerId;
}

function applyAttack(attacker, targetTile, actionDefinition, actionData, currentTile) {

    // Handle AoE effects
    if (actionDefinition.areaOfEffect) {
        const aoeTiles = getAoETiles(currentTile, targetTile, actionDefinition.areaOfEffect);

        // Record the attack_blast action
        game.lastTurnActions.push({
            type: actionDefinition.key, // 'attack_blast'
            unitId: attacker.unitId,
            from: { q: attacker.tile.q, r: attacker.tile.r },
            to: { q: targetTile.q, r: targetTile.r },
            aoeTiles: aoeTiles.map(tile => ({ q: tile.q, r: tile.r })),
            playerId: attacker.playerId
        });

        // Apply effects to the primary target
        applyEffectToTile(attacker, targetTile, actionDefinition);

        // Apply AoE effects
        aoeTiles.forEach(tile => {
            applyEffectToTile(attacker, tile, actionDefinition);
        });
    } else {
        // Non-AoE attack, Record normal attack
        game.lastTurnActions.push({
            type: actionDefinition.key, // e.g., 'attack_short'
            unitId: attacker.unitId,
            from: { q: attacker.tile.q, r: attacker.tile.r },
            to: { q: targetTile.q, r: targetTile.r },
            playerId: attacker.playerId
        });

        applyEffectToTile(attacker, targetTile, actionDefinition);
    }
}

function applyEffectToTile(attacker, tile, actionDefinition) {
    // Get all units on the target tile
    let affectedUnits = tile.units;

    affectedUnits = getAffectedUnits(attacker, tile, actionDefinition);

    if (affectedUnits.length === 0) {
        console.log(`No valid targets on tile (${tile.q}, ${tile.r}).`);
        return;
    }

    // Apply the strength impact or any other defined impacts to the units
    affectedUnits.forEach(unit => {
        if (actionDefinition.strengthImpact !== undefined) {
            unit.strength += actionDefinition.strengthImpact;
            console.log(
                `Unit ${attacker.unitId} affected Unit ${unit.unitId}. New strength: ${unit.strength}`
            );
        }
    });
}

function getAoETiles(currentTile, targetTile, areaOfEffect) {
    const directions = areaOfEffect.directions;
    const distance = areaOfEffect.distance || 1;

    const directionIndex = getDirectionIndex(currentTile, targetTile);
    if (directionIndex === null) {
        console.log('Cannot determine direction from current tile to target tile.');
        return [];
    }

    if (directionIndex === -1) {
        // Self-targeting: Define a default AoE or skip
        // For example, AoE around self in all directions
        console.log('Self-targeting attack. Applying AoE around the unit.');
        const allAoETiles = [];

        // Iterate through all six directions to gather AoE tiles
        for (let i = 0; i < 6; i++) {
            let dirIndex = i;
            let tile = currentTile;
            for (let d = 0; d < distance; d++) {
                const dir = hexDirections[dirIndex];
                const neighborQ = tile.q + dir.dq;
                const neighborR = tile.r + dir.dr;
                tile = game.grid[`${neighborQ},${neighborR}`];
                if (!tile) {
                    break; // Out of bounds
                }
            }
            if (tile) {
                allAoETiles.push(tile);
            }
        }

        return allAoETiles;
    }

    console.log(`target tile: ${targetTile.q}, ${targetTile.r}, current tile: ${currentTile.q}, ${currentTile.r}`);

    const aoeTiles = [];

    directions.forEach(relativeDir => {
        let dirIndex = (directionIndex + relativeDir + 6) % 6; // Ensure it's between 0 and 5

        let tile = targetTile;
        for (let i = 0; i < distance; i++) {
            const dir = hexDirections[dirIndex];
            const neighborQ = tile.q + dir.dq;
            const neighborR = tile.r + dir.dr;
            tile = game.grid[`${neighborQ},${neighborR}`];
            if (!tile) {
                break; // Out of bounds
            }
        }
        if (tile) {
            aoeTiles.push(tile);
        }
    });

    return aoeTiles;
}

function getDirectionIndex(fromTile, toTile) {
    // If attacking self, return a default value (e.g., -1)
    if (fromTile.q === toTile.q && fromTile.r === toTile.r) {
        return -1; // Indicates no direction
    }

    const fromCube = { x: fromTile.q, y: -fromTile.q - fromTile.r, z: fromTile.r };
    const toCube = { x: toTile.q, y: -toTile.q - toTile.r, z: toTile.r };

    const dx = toCube.x - fromCube.x;
    const dy = toCube.y - fromCube.y;
    const dz = toCube.z - fromCube.z;

    // Calculate the projections onto the cube directions
    let maxDot = -Infinity;
    let bestDirection = null;

    for (let i = 0; i < cubeDirections.length; i++) {
        const dir = cubeDirections[i];
        const dot = dx * dir.x + dy * dir.y + dz * dir.z;
        if (dot > maxDot) {
            maxDot = dot;
            bestDirection = i;
        }
    }

    return bestDirection;
}


// Update processMovementActions to use moveUnit
function processMovementActions(movementActions) {
    if (movementActions.length === 0) {
        return;
    }

    console.log(`Processing ${movementActions.length} movement actions...`);

    movementActions.forEach(action => {
        const { unit, actionDefinition } = action;

        // Validate and process the movement path
        const path = action.path;
        if (!Array.isArray(path) || path.length === 0) {
            console.log(`No path provided for unit ${attacker.unitId}. Defaulting to current tile for ${actionDefinition.key}.`);
            path = [{ q: unit.tile.q, r: unit.tile.r }];
        }

        let pathTiles = getPathTiles(path);

        // Start from the unit's current tile
        let currentTile = pathTiles[0];
        for (let i = 1; i < pathTiles.length; i++) {
            const nextTile = pathTiles[i];

            // Move the unit step by step
            moveUnit(unit, nextTile);

            // If the action involves moving resources, transfer them to the new tile
            if (actionDefinition.movesResources === true) {
                Object.keys(currentTile.resourceStorage).forEach(resourceName => {
                    const quantity = currentTile.resourceStorage[resourceName] || 0;
                    nextTile.resourceStorage[resourceName] = (nextTile.resourceStorage[resourceName] || 0) + quantity;
                    currentTile.resourceStorage[resourceName] = 0; // Clear the resource on the original tile
                    console.log(`Moved ${quantity} of ${resourceName} from (${currentTile.q}, ${currentTile.r}) to (${nextTile.q}, ${nextTile.r}).`);
                });
            }

            // Record movement for visualization
            game.lastTurnActions.push({
                type: actionDefinition.key,
                unitId: unit.unitId,
                from: { q: currentTile.q, r: currentTile.r },
                to: { q: nextTile.q, r: nextTile.r },
                playerId: unit.playerId
            });

            currentTile = nextTile;
        }
    });
}

function processReloadActions(reloadActions) {
    if (reloadActions.length === 0) {
        return;
    }

    console.log(`Processing ${reloadActions.length} reload actions...`);

    // Loop through all reload actions and reload the power of the units
    reloadActions.forEach(action => {
        const { unit, actionDefinition } = action;

        // Instead, add power based on strengthImpact
        unit.power += actionDefinition.strengthImpact;
        unit.power = Math.min(unit.power, MAX_POWER_PER_UNIT); // Ensure it doesn't exceed max
        console.log(`Unit ${unit.unitId} reloaded by ${actionDefinition.strengthImpact}. New power: ${unit.power}`);

        // Record the reload for visualization
        game.lastTurnActions.push({
            type: actionDefinition.key,
            unitId: unit.unitId,
            tile: { q: unit.tile.q, r: unit.tile.r },
            amount: actionDefinition.strengthImpact
        });
    });
}

function processAttackActions(attackActions) {
    if (attackActions.length === 0) {
        return;
    }

    console.log(`Processing ${attackActions.length} attack actions...`);

    attackActions.forEach(actionData => {
        const { unit: attacker, actionDefinition } = actionData;

        // Validate the action path
        let path = actionData.path;
        if (!Array.isArray(path) || path.length < 1) {
            console.log(`No path provided for unit ${attacker.unitId}. Defaulting to current tile for ${actionDefinition.key}.`);
            path = [{ q: attacker.tile.q, r: attacker.tile.r }];
        }

        // Reconstruct the path and validate adjacency
        let pathTiles = [];

        pathTiles = getPathTiles(path);
        const currentTile = pathTiles[0];

        // Set currentTile and targetTile based on the path
        const targetTile = pathTiles[pathTiles.length - 1];
        let fromTile;
        if (path.length === 1) {
            fromTile = currentTile; // Self-targeting
        } else {
            fromTile = pathTiles[pathTiles.length - 2];
        }

        // Apply the attack using the fromTile and targetTile
        applyAttack(attacker, targetTile, actionDefinition, actionData, fromTile);
    });
}

function processExtractResourceActions(extractActions) {
    if (extractActions.length === 0) {
        return;
    }

    console.log(`Processing ${extractActions.length} extract resource actions...`);

    extractActions.forEach(actionData => {
        const { unit, actionDefinition } = actionData;

        // Extract target tile from action
        const tileKey = `${unit.tile.q},${unit.tile.r}`;
        const tile = game.grid[tileKey];

        if (!tile) {
            console.log(`Tile (${unit.tile.q}, ${unit.tile.r}) not found.`);
            return;
        }

        const resourceName = tile.resources[0]; // Assuming single-resource extraction
        if (!resourceName) {
            console.log(`No resource found on tile (${tile.q}, ${tile.r}).`);
            return;
        }

        // Extract resources
        const amount = actionData.amount || 1; // Default to 1 if not specified

        tile.extractResource(resourceName, amount);

        // Record the action for visualization
        game.lastTurnActions.push({
            type: actionDefinition.key,
            unitId: unit.unitId,
            tile: { q: tile.q, r: tile.r },
            resourceName: resourceName,
            amount: amount,
            playerId: unit.playerId
        });
    });
}

function processEvolveActions(evolveActions) {
    if (evolveActions.length === 0) return;
  
    console.log(`Processing ${evolveActions.length} evolve actions...`);
  
    evolveActions.forEach(actionData => {
      const { unit, actionDefinition } = actionData;
      
      // 1) Get the target type from the action definition
      const newUnitTypeKey = actionDefinition.transformUnitType;
      const newUnitType = UNIT_TYPES[newUnitTypeKey];
  
      if (!newUnitType) {
        console.log(`No definition found for target type '${newUnitTypeKey}'.`);
        return;
      }
      
      // 2) Transform the unit
      console.log(
        `Unit ${unit.unitId} (type: ${unit.type}) evolves into '${newUnitType.name}'.`
      );
  
      // Update the unit’s type, name, strength, actions, etc.
      unit.type = newUnitTypeKey;
      unit.actions = [...newUnitType.actions];
      unit.passiveActions = [...newUnitType.passiveActions];
      unit.color = newUnitType.color;
      
      // 3) Record the evolve action in lastTurnActions for the client
      game.lastTurnActions.push({
        type: actionDefinition.key, // e.g., "baneling_evolve"
        unitId: unit.unitId,
        fromType: unit.type,   // if you want to log old/new
        toType: newUnitTypeKey,
        playerId: unit.playerId,
        tile: { q: unit.tile.q, r: unit.tile.r }
      });
    });
  }

function getPathTiles(path){
    let currentTile = game.grid[`${path[0].q},${path[0].r}`];

    if (!currentTile) {
        console.log(`Starting tile (${path[0].q}, ${path[0].r}) does not exist.`);
        return;
    }

    let pathTiles = [];
    pathTiles.push(currentTile);

    for (let i = 1; i < path.length; i++) {
        const nextCoords = path[i];
        const nextTile = game.grid[`${nextCoords.q},${nextCoords.r}`];

        if (!nextTile) {
            console.log(`Tile (${nextCoords.q}, ${nextCoords.r}) does not exist.`);
            return;
        }

        const distance = hexDistance(currentTile, nextTile);
        if (distance !== 1) {
            console.log(`Tiles (${currentTile.q}, ${currentTile.r}) and (${nextTile.q}, ${nextTile.r}) are not adjacent.`);
            return;
        }

        currentTile = nextTile;
        pathTiles.push(currentTile);
    }

    return pathTiles;
}

function growResources() {
    console.log("Growing resources on tiles with growthFrequency...");

    // Iterate over all tiles in the game grid
    for (const key in game.grid) {
        const tile = game.grid[key];

        // Check if the tile type has a growthFrequency and maxResource
        const tileType = TileTypes[tile.type];
        if (tileType && tileType.growthFrequency && tileType.maxResource) {
            // Calculate the growth condition based on the current turn
            if (game.turn % tileType.growthFrequency === 0) {
                tile.resources.forEach(resourceName => {
                    const currentQuantity = tile.resourceQuantities[resourceName] || 0;

                    // Only grow the resource if it's below maxResource
                    if (currentQuantity < tileType.maxResource) {
                        tile.resourceQuantities[resourceName] = Math.min(
                            currentQuantity + 1,
                            tileType.maxResource
                        );
                        console.log(
                            `Resource '${resourceName}' on tile (${tile.q}, ${tile.r}) grew to ${tile.resourceQuantities[resourceName]}`
                        );
                    }
                });
            }
        }
    }
}

function processSpawnAction(actionData) {
    const { unit: attacker, actionDefinition } = actionData;

    // Validate the action path
    let path = actionData.path;
    if (!Array.isArray(path) || path.length < 1) {
        console.log(`No path provided for unit ${attacker.unitId}. Defaulting to current tile for ${actionDefinition.key}.`);
        path = [{ q: attacker.tile.q, r: attacker.tile.r }];
    }

    const player = game.players.find(p => p.playerId === findUnitById(actionData.unitId).playerId);
    if (!player) {
        console.log(`Player not found for spawning.`);
        return;
    }

    // Convert the path array into actual Tile objects and validate adjacency
    let pathTiles = getPathTiles(path);
    if (!pathTiles) {
        console.log('Invalid path for spawn action.');
        return;
    }

    // The last tile in the path is where the new unit will be spawned
    const targetTile = pathTiles[pathTiles.length - 1];

    const unitType = actionDefinition.unitType;
    // Actually spawn the unit on the target tile instead of attacker’s tile
    spawnUnit(player, targetTile.q, targetTile.r, unitType);
    console.log(`Player ${player.playerId} spawned a ${unitType} unit on tile (${targetTile.q}, ${targetTile.r}).`);

    // Record the spawn for visualization
    game.lastTurnActions.push({
        type: actionDefinition.key,
        playerId: player.playerId,
        tile: { q: attacker.tile.q, r: attacker.tile.r },
        unitId: player.units[player.units.length - 1].unitId,
        unitType: unitType
    });
}

function removeDefeatedUnits() {
    console.log("Removing defeated units...");
    game.lastTurnDefeatedUnits = []; // Reset defeated units for the turn

    game.players.forEach(player => {
        player.units.forEach(unit => {
            // Get the max strength for the unit type from UNIT_TYPES
            const unitType = UNIT_TYPES[unit.type];
            const maxStrength = unitType ? unitType.strength : null;

            if (maxStrength !== null) {
                // If unit strength exceeds its type's max strength, reset to max strength
                if (unit.strength > maxStrength) {
                    console.log(`Unit ${unit.unitId} exceeds max strength. Resetting to ${maxStrength}.`);
                    unit.strength = maxStrength;
                }
            } else {
                console.warn(`Unit type '${unit.type}' not found in UNIT_TYPES.`);
            }
        });

        // Filter out defeated units
        const defeatedUnits = player.units.filter(unit => unit.strength <= 0);
        defeatedUnits.forEach(unit => {
            console.log(`Removing Unit ${unit.unitId} of Player ${unit.playerId} due to 0 strength.`);
            game.lastTurnDefeatedUnits.push({
                unitId: unit.unitId,
                playerId: unit.playerId,
                type: unit.type,
                color: unit.color,
                tile: { q: unit.tile.q, r: unit.tile.r }
            });
            removeUnit(unit);
        });
    });

    console.log("Defeated units this turn:", game.lastTurnDefeatedUnits);
}

function removeUnit(unit) {
    const player = game.players.find(p => p.playerId === unit.playerId);
    if (player) {
        const index = player.units.findIndex(u => u.unitId === unit.unitId);
        if (index !== -1) {
            player.units.splice(index, 1);
        }
    }
    // Construct the tile key using the unit's tile coordinates
    const tileKey = `${unit.tile.q},${unit.tile.r}`;
    const tile = game.grid[tileKey];

    if (tile) {
        const unitIndex = tile.units.findIndex(u => u.unitId === unit.unitId);
        if (unitIndex !== -1) {
            tile.units.splice(unitIndex, 1);
        }
        // Optionally update ownership based on remaining units
        if (tile.units.length === 0) {
            tile.owner = null;
        } else {
            // If units remain, set ownership to the player of the first unit
            tile.owner = tile.units[0].playerId;
        }
    }
}

// Modify the broadcastGameState function to include new action logs

function broadcastGameState() {
    const cleanState = {
        grid: {},
        players: game.players.map(player => ({
            playerId: player.playerId,
            username: player.username, // Include username
            color: player.color,
            units: player.units.map(unit => ({
                unitId: unit.unitId,
                playerId: unit.playerId,
                strength: unit.strength,
                power: unit.power,
                type: unit.type,
                color: unit.color,
                actions: unit.actions,
                passiveActions: unit.passiveActions,
                tile: { q: unit.tile.q, r: unit.tile.r }
            })),
            resources: player.resources
        })),
        turn: game.turn,
        playerActions: game.playerActions, 
        lastTurnActions: game.lastTurnActions,
        lastTurnDefeatedUnits: game.lastTurnDefeatedUnits, // Include defeated units
        delayedActions: game.delayedActions,
        actions: game.actions                 // Include ACTIONS list
    };

    // Create a clean copy of the grid without unit references
    for (const key in game.grid) {
        const tile = game.grid[key];
        cleanState.grid[key] = {
            q: tile.q,
            r: tile.r,
            owner: tile.owner,
            color: tile.color,          // **Added color property**
            type: tile.type,            // **Added type property**
            actions: tile.actions,      // **Added actions property**
            resources: tile.resources,  // **Added resources property**
            resourceStorage: tile.resourceStorage, // Include stored resources
            resourceQuantities: tile.resourceQuantities,
            height: tile.height,  // Include the height
            enterableFromDirections: tile.enterableFromDirections,  // Include the enterable directions
            units: tile.units.map(unit => ({
                unitId: unit.unitId,
                playerId: unit.playerId,
                strength: unit.strength,
                power: unit.power,
                type: unit.type,
                color: unit.color,
                actions: unit.actions,
                passiveActions: unit.passiveActions,
                tile: { q: tile.q, r: tile.r }
                // Exclude circular references if any
            }))
        };
    }

    broadcast({
        type: 'update',
        state: cleanState
    });
}

function handleDisconnect(playerId) {
    console.log(`Player ${playerId} disconnected. Waiting for possible reconnection.`);
    const player = game.players.find(p => p.playerId === playerId);

    if (player) {
        player.ws = null; // Nullify WebSocket for reconnection
    }
}

function handleRestart(playerId) {
    // Only allow restarting if initiated by all players or a specific condition
    if (game.players.length === game.players.length) {
        console.log("Restarting game...");
        resetGame();
        broadcastGameState();
    }
}

function resetGame() {
    // Reset game state
    game.grid = {};
    game.players.forEach(player => {
        player.units = [];
    });
    game.turn = 1;
    game.playerActions = Array(game.players.length).fill(null).map(() => []);
    game.lastTurnActions = [];

    // Resend the ACTIONS list
    broadcast({
        type: 'actions_list',
        actions: game.actions, // Send actions list
        action_order: actionOrder
    });

    // Reinitialize the game grid and units
    generateInitialGameState();

    // Broadcast updated game state
    broadcastGameState();

    console.log("Game has been reset and ACTIONS list resent to all clients.");
}

function endGame(winningPlayers) {
    if (winningPlayers.length === 1) {
        const winner = winningPlayers[0];
        console.log(`Player ${winner.playerId} wins the game!`);
        broadcast({
            type: 'game_over',
            winner: winner.playerId,
            message: `Player ${winner.playerId} wins by satisfying win conditions!`
        });
    } else {
        console.log(`Game ended in a draw.`);
        broadcast({
            type: 'game_over',
            winner: null
        });
    }
}

function winCondition(player) {
    // Check if all opponents have been eliminated
    const opponents = game.players.filter(p => p.playerId !== player.playerId);
    const allOpponentsDefeated = opponents.every(opponent => opponent.units.length === 0);

    if (allOpponentsDefeated) {
        console.log(`Player ${player.playerId} wins by eliminating all opponents!`);
        return true; // Win by elimination
    }

    // Check if the player has at least 10 gold
    const playerGold = player.resources['gold'] || 0; // Default to 0 if gold is undefined
    if (playerGold >= 20) {
        console.log(`Player ${player.playerId} wins by collecting 10 gold!`);
        return true; // Win by resource collection
    }

    // No win condition met
    return false;
}

function broadcast(message) {
    clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify(message));
        }
    });
}

console.log(`WebSocket server is running on port: ${PORT}`);
