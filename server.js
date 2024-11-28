const WebSocket = require('ws');

const wss = new WebSocket.Server({ port: 8080 });
//const wss = new WebSocket.Server({ host: '0.0.0.0', port: 8080 });


const NUM_PLAYERS = 2;
// Add this near the top of your server file
const MAX_UNITS_PER_PLAYER = 4;  // Existing constant
const MAX_STRENGTH_PER_UNIT = 100; // New constant for maximum unit strength
const MAX_POWER_PER_UNIT = 4; // Set this to your desired maximum power per unit



// server.js

const ACTIONS = {
    move_short: {
        key: 'move_short',       // Unique action key
        type: 'move',            // Action type
        name: 'Move',            // Display name for the client
        minRange: 1,
        maxRange: 1,
        color: '#0000FF',        // Blue
        powerConsumption: 1,
        strengthImpact: 0,       // No direct strength impact
        applyTo: 'unit'
    },
    move_long: {
        key: 'move_long',
        type: 'move',
        name: 'Long Move',
        minRange: 2,
        maxRange: 2,
        color: '#0000FF',
        powerConsumption: 2,
        strengthImpact: 0,
        applyTo: 'unit'
    },
    attack_short: {
        key: 'attack_short',
        type: 'attack',
        name: 'Attack',
        minRange: 1,
        maxRange: 1,
        color: '#FF0000',        // Red
        powerConsumption: 2,
        strengthImpact: -50,     // Reduces defender's strength
        applyTo: 'unit'
    },
    attack_long: {
        key: 'attack_long',
        type: 'attack',
        name: 'Long Attack',
        minRange: 2,
        maxRange: 2,
        color: '#FF0000',        // Red
        powerConsumption: 3,
        strengthImpact: -50,     // Reduces defender's strength
        applyTo: 'unit'
    },
    reload: {
        key: 'reload',
        type: 'reload',
        name: 'Rest',
        minRange: 0,
        maxRange: 0,
        color: '#9C27B0',        // Purple
        powerConsumption: 1,
        strengthImpact: 0,
        applyTo: 'unit'
    },/*
    heal: {
        key: 'heal',
        type: 'heal',
        name: 'Heal',
        minRange: 0,
        maxRange: 2,
        color: '#FF6347',        // Tomato
        powerConsumption: 2,
        strengthImpact: 10,      // Increases unit's strength
        applyTo: 'unit'
    },*/
    spawn: {
        key: 'spawn',
        type: 'spawn',
        name: 'Spawn',
        minRange: 0,
        maxRange: 0,
        color: '#FFD700',        // Gold
        powerConsumption: 3,
        strengthImpact: 0,
        applyTo: 'tile'
    }
    // Add more actions here as needed
};

let game = {
    grid: {},  // Game grid
    players: [], // Array of player objects: { playerId, color, units, ws }
    turn: 1,
    playerActions: Array(NUM_PLAYERS).fill(null).map(() => []),  // Actions for each player
    availableColors: ['#4CAF50', '#0000FF', '#FFA500', '#800080', '#FF0000', '#00FFFF'],
    trails: [],
    fires: [],
    attackLines: [],
    lastTurnMovements: [], // Stores movement actions of the last turn
    lastTurnAttacks: [],
    lastTurnReloads: [],   // Stores attack actions of the last turn
    winConditions: {
        type: 'custom',  // Can be 'elimination', 'resource', or 'custom'
        conditions: {
            gold: 10,   // Example: Player needs to collect 10 gold
            science: 5, // Example: New win condition based on science points
        }
    },
    actions: ACTIONS // Add the ACTIONS object to the game state
};

// Track connected clients (players)
const clients = [];

function setGameType(gameTypeKey) {
    const selectedGameType = GameTypes[gameTypeKey];
    if (selectedGameType) {
        game.winConditions.type = gameTypeKey;
        game.winConditions.conditions = selectedGameType.winConditions;
        console.log(`Game type set to ${selectedGameType.name} with win conditions:`, game.winConditions.conditions);
    } else {
        console.log('Invalid game type selected');
    }
}


const GameTypes = {
    'elimination': {
        name: 'Elimination',
        description: 'Eliminate all opponent units to win.',
        winConditions: {
            elimination: true // No specific resources, just elimination of all units
        }
    },
    'goldRush': {
        name: 'Gold Rush',
        description: 'First player to accumulate 10 gold wins.',
        winConditions: {
            gold: 10
        }
    },
    'scienceRace': {
        name: 'Science Race',
        description: 'First player to accumulate 5 science points wins.',
        winConditions: {
            science: 5
        }
    },
    'mixed': {
        name: 'Mixed Objectives',
        description: 'Win by either accumulating 10 gold or 5 science points.',
        winConditions: {
            gold: 10,
            science: 5
        }
    }
};


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
        this.type = attributes.type || 'default';  // **Added type property**
        this.color = attributes.color || '#e0e0e0';  // Default tile color
        this.actions = attributes.actions || [];  // List of actions this tile can perform (e.g., heal, spawn)
    }

    // Add a resource to the tile
    addResource(resourceName) {
        if (resources[resourceName]) {
            this.resources.push(resourceName);
            console.log(`Resource '${resourceName}' added to tile (${this.q}, ${this.r})`);
        }
    }

    // Perform actions on units (heal, spawn, etc.)
    performActionsOnUnits(player) {
        this.units.forEach(unit => {
            this.actions.forEach(action => {
                if (action.type === 'heal') {
                    unit.strength = Math.min(MAX_STRENGTH_PER_UNIT, unit.strength + action.healAmount);
                    console.log(`Unit ${unit.unitId} healed by ${action.healAmount}. New strength: ${unit.strength}`);
                }
                if (action.type === 'spawn' && player.units.length < MAX_UNITS_PER_PLAYER) {
                    spawnUnit(player, this.q, this.r);
                    console.log(`Unit spawned for player ${player.playerId} on tile (${this.q}, ${this.r})`);
                }
            });
        });
    }
}

// Tile Type Library
const TileTypes = {
    wood: {
        color: '#8B4513', // Brown color for wood tile
        resources: ['wood'],
    },
    gold: {
        color: '#ffd700', // Gold color for gold tile
        resources: ['gold'],
    },
    healing: {
        color: '#ff6347', // Red color for healing tile
        actions: [{ type: 'heal', healAmount: 15 }],
    },
    spawn: {
        color: '#6495ED', // Blue color for spawning tile
        actions: [{ type: 'spawn', spawnUnits: 1 }],
    },
    default: {
        color: '#e0e0e0', // Default gray tile
        resources: [],
        actions: [],
    },
    // Adding a "water" tile type that has a blue hue and no resources but might heal units slightly
    water: {
        color: '#00BFFF', // Light blue color for water tile
        actions: [{ type: 'heal', healAmount: 5 }],  // Minor healing action
    },
    // Adding a "forest" tile type that provides both wood and heals units slightly
    forest: {
        color: '#228B22',  // Forest green color
        resources: ['wood'],  // Provides wood resource
        actions: [{ type: 'heal', healAmount: 10 }]  // Minor healing
    }

};

// Function to create a tile from a tile type
function createTileFromType(q, r, s, tileTypeKey) {
    const tileType = TileTypes[tileTypeKey] || TileTypes.default;  // Fallback to default if not found
    const tile = new Tile(q, r, s, {
        color: tileType.color,
        type: tileTypeKey,
        actions: tileType.actions || [],
    });

    // Add resources from the tile type
    if (tileType.resources) {
        tileType.resources.forEach(resource => tile.addResource(resource));
    }

    return tile;
}

// Dynamically generate a grid with predefined tile types
function generateInitialGameState() {
    const GRID_SIZE = 4;

    for (let q = -GRID_SIZE + 1; q <= GRID_SIZE - 1; q++) {
        for (let r = -GRID_SIZE + 1; r <= GRID_SIZE - 1; r++) {
            const s = -q - r;
            if (Math.abs(s) < GRID_SIZE) {
                let tileType = 'default';  // Default tile type

                // Define specific locations for tile types (this can be randomized or expanded)
                if (q === 0 && r === 0) {
                    tileType = 'gold';  // Central tile is a gold tile
                } /*else if (q === 1 && r === -1) {
                    tileType = 'wood';  // Wood tile
                } else if (q === -1 && r === 1) {
                    tileType = 'healing';  // Healing tile
                } else if (q === 2 && r === -2) {
                    tileType = 'spawn';  // Spawning tile
                }*/

                // Create the tile using the predefined type
                const tile = createTileFromType(q, r, s, tileType);
                game.grid[`${q},${r}`] = tile;
            }
        }
    }

    // Define starting positions for players
    const startPositions = [
        [0, -GRID_SIZE + 1], 
        [0, GRID_SIZE - 1]
    ];

    // Place initial units for each player
    for (let i = 0; i < NUM_PLAYERS; i++) {
        const [startQ, startR] = startPositions[i];
        const player = game.players[i];
        const numUnits = player.numUnits;

        // Find tiles to place units near the starting position
        const tilesToPlace = findStartingTiles(startQ, startR, numUnits);

        tilesToPlace.forEach(([q, r]) => {
            const tile = game.grid[`${q},${r}`];
            if (tile) {  // Ensure tile exists
                const unit = {
                    unitId: generateUnitId(),
                    playerId: player.playerId,
                    strength: player.strength,
                    tile: { q: tile.q, r: tile.r },  // Assign the tile's position to the unit
                    power: 1, // Initialize power units to one for attacks
                    isMoving: false,
                };
                tile.units.push(unit);         // Add unit to the units array
                player.units.push(unit);
                console.log(`Player ${player.playerId} unit placed at (${q}, ${r})`);
            }
        });        
    }
}

// Function to spawn new units on a tile for a player
function spawnUnit(player, q, r) {
    const tile = game.grid[`${q},${r}`];
    if (tile && player.units.length < MAX_UNITS_PER_PLAYER) {
        const newUnit = {
            unitId: generateUnitId(),
            playerId: player.playerId,
            strength: player.strength,
            tile: { q: tile.q, r: tile.r },
            power: 1,
        };
        tile.units.push(newUnit);
        player.units.push(newUnit);
    }
}

// Modify the accumulateGold function to be a general resource collector
function accumulateResources() {
    game.players.forEach(player => {
        player.units.forEach(unit => {
            const tileKey = `${unit.tile.q},${unit.tile.r}`;
            const tile = game.grid[tileKey];

            if (tile) {
                // Accumulate resources from tiles
                tile.resources.forEach(resourceName => {
                    const resource = resources[resourceName];
                    if (resource) {
                        // Correctly update within player.resources
                        player.resources[resourceName] = (player.resources[resourceName] || 0) + resource.amount;
                        console.log(`Player ${player.playerId} collected ${resource.amount} ${resourceName}. Total: ${player.resources[resourceName]}`);

                        // Check for victory based on custom conditions
                        if (checkCustomWinConditions(player)) {
                            endGame([player]); // End the game if the player meets win conditions
                            return;
                        }
                    }
                });

                // Perform any tile-specific actions like healing or spawning
                tile.performActionsOnUnits(player);
            }
        });
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

    // Assign player ID
    if (clients.length >= NUM_PLAYERS) {
        ws.send(JSON.stringify({ type: 'error', message: 'Game is full.' }));
        ws.close();
        return;
    }

    const playerId = clients.length + 1;
    const player = {
        playerId: playerId,
        color: null,
        units: [],
        ws: ws,
        resources: {}
    };

    game.players.push(player);
    clients.push(ws);

    // Send welcome message with assigned playerId and available colors
    ws.send(JSON.stringify({
        type: 'welcome',
        playerId: playerId,
        availableColors: game.availableColors,
        gameTypes: Object.keys(GameTypes).map(typeKey => ({
            typeKey: typeKey,
            name: GameTypes[typeKey].name,
            description: GameTypes[typeKey].description
        }))
    }));

    ws.on('message', function incoming(message) {
        const data = JSON.parse(message);

        // Add this section to handle game type selection
        if (data.type === 'game_type_selection' && playerId === 1) {
            // Player 1 chooses the game type
            const selectedGameType = GameTypes[data.gameType];
            if (selectedGameType) {
                setGameType(data.gameType);
                console.log(`Game type set to ${selectedGameType.name}`);
                broadcast({ type: 'game_type_selected', gameType: selectedGameType.name });
            } else {
                ws.send(JSON.stringify({ type: 'error', message: 'Invalid game type selected' }));
            }
            return;  // Return early to prevent further processing
        }

        if (data.type === 'color_selection') {
            handleColorSelection(playerId, data);
        }

        if (data.type === 'action') {
            handleAction(playerId, data.action);
        }

        if (data.type === 'restart') {
            handleRestart(playerId);
        }
    });

    ws.on('close', function () {
        console.log(`Player ${playerId} disconnected`);
        handleDisconnect(playerId);
    });
});

function handleColorSelection(playerId, data) {
    const player = game.players.find(p => p.playerId === playerId);
    if (!player) return;

    const { color, numUnits, strength } = data;

    // Validate color availability
    if (!game.availableColors.includes(color)) {
        player.ws.send(JSON.stringify({ type: 'error', message: 'Color not available.' }));
        return;
    }

    // Validate number of units
    if (isNaN(numUnits) || numUnits < 1 || numUnits > MAX_UNITS_PER_PLAYER) {
        player.ws.send(JSON.stringify({ type: 'error', message: 'Invalid number of units. Please select between 1 and ' + MAX_UNITS_PER_PLAYER + ' units.' }));
        return;
    }

    // Validate strength
    if (isNaN(strength) || strength < 1 || strength > MAX_STRENGTH_PER_UNIT) {
        player.ws.send(JSON.stringify({ type: 'error', message: `Invalid unit strength. Please select a strength between 1 and ${MAX_STRENGTH_PER_UNIT}.` }));
        return;
    }

    // Assign color, number of units, and strength to the player
    player.color = color;
    player.numUnits = numUnits;
    player.strength = strength;
    game.availableColors = game.availableColors.filter(c => c !== color);

    console.log(`Player ${playerId} selected color ${color}, ${numUnits} units with strength ${strength}`);

    // Notify player that color selection was successful
    player.ws.send(JSON.stringify({ type: 'color_selected', color: color }));

    // Check if all players have selected colors, units, and strength
    if (game.players.every(p => p.color && p.numUnits && p.strength)) {
        initializeGame();
    }
}


function initializeGame() {
    console.log("All players have selected colors. Initializing game...");

    // Initialize game grid and units
    generateInitialGameState();

    // Broadcast initial game state to all players
    broadcastGameState();

    // Additionally, send the ACTIONS list to all clients
    broadcast({
        type: 'actions_list',
        actions: game.actions
    });

    console.log("ACTIONS list sent to all clients.");
}

// Modify the handleAction function
// server.js

function handleAction(playerId, action) {
    const playerIndex = playerId - 1;

    if (!game.playerActions[playerIndex]) {
        game.playerActions[playerIndex] = [];
    }

    console.log(action)
    const actionKey = action.actionKey;
    const targetTile = action.targetTile;

    // Step 1: Validate actionKey exists in server's ACTIONS
    const serverActionDef = ACTIONS[actionKey];
    if (!serverActionDef) {
        console.log(`Invalid action key received: ${actionKey}`);
        game.players[playerIndex].ws.send(JSON.stringify({ type: 'error', message: `Invalid action key: ${actionKey}` }));
        return;
    }

    // Step 2: Validate targetTile if applicable
    if (serverActionDef.applyTo === 'unit') {
        if (!targetTile) {
            game.players[playerIndex].ws.send(JSON.stringify({ type: 'error', message: `Target tile required for action: ${actionKey}` }));
            return;
        }

        const unit = findUnitById(action.unitId);
        if (!unit) {
            console.log(`Unit ${action.unitId} not found.`);
            game.players[playerIndex].ws.send(JSON.stringify({ type: 'error', message: `Unit ${action.unitId} not found.` }));
            return;
        }

        const currentTile = game.grid[`${unit.tile.q},${unit.tile.r}`];
        const targetTileObj = game.grid[`${targetTile.q},${targetTile.r}`];
        if (!currentTile || !targetTileObj) {
            game.players[playerIndex].ws.send(JSON.stringify({ type: 'error', message: `Invalid tile coordinates.` }));
            return;
        }

        const distance = hexDistance(currentTile, targetTileObj);
        if (distance < serverActionDef.minRange || distance > serverActionDef.maxRange) {
            console.log(`Action ${actionKey} out of range. Distance: ${distance}. Min Range: ${serverActionDef.minRange}. Max Range: ${serverActionDef.maxRange}`);
            game.players[playerIndex].ws.send(JSON.stringify({ type: 'error', message: `Action ${actionKey} out of range.` }));
            return;
        }
    } else if (serverActionDef.applyTo === 'tile') {
        if (!targetTile) {
            game.players[playerIndex].ws.send(JSON.stringify({ type: 'error', message: `Target tile required for action: ${actionKey}` }));
            return;
        }

        const tileObj = game.grid[`${targetTile.q},${targetTile.r}`];
        if (!tileObj) {
            game.players[playerIndex].ws.send(JSON.stringify({ type: 'error', message: `Invalid tile coordinates.` }));
            return;
        }

        // Additional validations for tile-based actions can be added here
    }

    // Step 3: Check if the unit has enough power
    const unit = findUnitById(action.unitId);
    if (!unit) {
        console.log(`Unit ${action.unitId} not found.`);
        game.players[playerIndex].ws.send(JSON.stringify({ type: 'error', message: `Unit ${action.unitId} not found.` }));
        return;
    }

    if (unit.power < serverActionDef.powerConsumption) {
        console.log(`Unit ${action.unitId} does not have enough power for action ${actionKey}.`);
        game.players[playerIndex].ws.send(JSON.stringify({ type: 'error', message: `Not enough power for action ${actionKey}.` }));
        return;
    }

    // Step 4: Store the action
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

    // Step 5: Check if all players have planned their actions
    if (areAllPlayersReady()) {
        console.log(`All Players Ready. Executing Turn ${game.turn}...`);
        executeTurn();
    } else {
        broadcastGameState();
    }
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
    for (let i = 0; i < NUM_PLAYERS; i++) {
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

    // Clear previous turn's trails, fires, and attackLines
    game.trails = [];
    game.fires = [];
    game.attackLines = [];

    // Initialize arrays to store current turn's actions
    game.lastTurnMovements = [];
    game.lastTurnAttacks = [];
    game.lastTurnHeals = [];
    game.lastTurnSpawns = [];
    game.lastTurnReloads = [];

    // Define processing order based on action types
    const actionOrder = ['move', 'spawn', 'reload', 'attack', 'heal'];

    actionOrder.forEach(actionType => {
        for (let i = 0; i < NUM_PLAYERS; i++) {
            // Filter actions of the current actionType
            const actionsToProcess = game.playerActions[i].filter(actionData => {
                const actionDef = ACTIONS[actionData.actionKey];
                return actionDef && actionDef.type === actionType;
            });

            switch (actionType) {
                case 'move':
                    processMovementActions(actionsToProcess, () => {});
                    break;
                case 'spawn':
                    actionsToProcess.forEach(actionData => {
                        processSpawnAction(actionData);
                    });
                    break;
                case 'reload':
                    processReloadActions(actionsToProcess, () => {});
                    break;
                case 'attack':
                    processAttackActions(actionsToProcess, () => {});
                    break;
                case 'heal':
                    actionsToProcess.forEach(actionData => {
                        processHealAction(actionData);
                    });
                    break;
                // Add more cases here for new action types
                default:
                    console.log(`Unhandled action type: ${actionType}`);
            }
        }
    });

    // After processing all actions, remove defeated units and accumulate resources
    removeDefeatedUnits();
    accumulateResources();

    // **Power Regeneration Starts Here**
    regenerateUnitPower();
    // **Power Regeneration Ends Here**

    // Clear player actions for the next turn
    game.playerActions = Array(NUM_PLAYERS).fill(null).map(() => []);

    // Increment turn
    game.turn += 1;

    // Broadcast the updated game state to all players
    broadcastGameState();
}

function regenerateUnitPower() {
    console.log("Regenerating power for all units...");

    game.players.forEach(player => {
        player.units.forEach(unit => {
            if (unit.power < MAX_POWER_PER_UNIT) {
                unit.power += 1;
                // Ensure power does not exceed the maximum
                if (unit.power > MAX_POWER_PER_UNIT) {
                    unit.power = MAX_POWER_PER_UNIT;
                }
                console.log(`Unit ${unit.unitId} regenerated power to ${unit.power}.`);
            }
        });
    });

    console.log("Power regeneration completed.");
}

function processMovementActions(movementActions, callback) {
    if (movementActions.length === 0) {
        callback();
        return;
    }

    console.log(`Processing ${movementActions.length} movement actions...`);

    // Loop through all movement actions and move units to their target tiles
    movementActions.forEach(action => {
        const unit = findUnitById(action.unitId);
        if (!unit) {
            console.log(`Unit ${action.unitId} not found.`);
            return;
        }

        const actionDefinition = ACTIONS[action.actionKey];
        if (!actionDefinition) {
            console.log(`Action definition for '${action.actionKey}' not found.`);
            return;
        }

        // Deduct power here
        unit.power -= actionDefinition.powerConsumption;
        console.log(`Unit ${unit.unitId} power deducted by ${actionDefinition.powerConsumption}. New power: ${unit.power}`);

        const targetKey = `${action.targetTile.q},${action.targetTile.r}`;
        const targetTile = game.grid[targetKey];

        if (!targetTile) {
            console.log(`Target tile (${targetKey}) not found in grid.`);
            return;
        }

        const currentTileKey = `${unit.tile.q},${unit.tile.r}`;
        const currentTile = game.grid[currentTileKey];

        // Remove unit from its current tile
        const unitIndex = currentTile.units.findIndex(u => u.unitId === unit.unitId);
        if (unitIndex !== -1) {
            currentTile.units.splice(unitIndex, 1);
        }

        // Add unit to the target tile
        targetTile.units.push(unit);
        unit.tile = targetTile;

        // Update tile ownership (optional, depending on game rules)
        // In this case, ownership can change to the last player who moved a unit onto the tile
        targetTile.owner = unit.playerId;

        console.log(`Unit ${unit.unitId} moved to tile (${targetTile.q}, ${targetTile.r})`);

        // Record the movement for visualization (e.g., trails)
        game.lastTurnMovements.push({
            unitId: unit.unitId,
            from: { q: currentTile.q, r: currentTile.r },
            to: { q: targetTile.q, r: targetTile.r },
            playerId: unit.playerId
        });
    });

    callback();
}

function processReloadActions(reloadActions, callback) {
    if (reloadActions.length === 0) {
        callback();
        return;
    }

    console.log(`Processing ${reloadActions.length} reload actions...`);

    // Loop through all reload actions and reload the power of the units
    reloadActions.forEach(action => {
        const unit = findUnitById(action.unitId);
        if (!unit) {
            console.log(`Unit ${action.unitId} not found.`);
            return;
        }

        const actionDefinition = ACTIONS[action.actionKey];
        if (!actionDefinition) {
            console.log(`Action definition for '${action.actionKey}' not found.`);
            return;
        }

        // Deduct power here
        unit.power -= actionDefinition.powerConsumption; // For reload, powerConsumption is 0, but kept for consistency

        // Instead, add power based on strengthImpact
        unit.power += actionDefinition.strengthImpact;
        unit.power = Math.min(unit.power, MAX_STRENGTH_PER_UNIT); // Ensure it doesn't exceed max
        console.log(`Unit ${unit.unitId} reloaded by ${actionDefinition.strengthImpact}. New power: ${unit.power}`);

        // Check if the unit can reload (its power should be below the maximum allowed power)
        if (unit.power < MAX_STRENGTH_PER_UNIT) {
            unit.power += 1;
            console.log(`Unit ${unit.unitId} reloaded. New power: ${unit.power}`);
        } else {
            console.log(`Unit ${unit.unitId} is already at max power (${unit.power}).`);
        }

        // Record the reload for visualization
        game.lastTurnReloads.push({
            unitId: unit.unitId,
            tile: { q: unit.tile.q, r: unit.tile.r },
            amount: actionDefinition.strengthImpact
        });
    });

    callback();
}

function processAttackActions(attackActions, callback) {
    if (attackActions.length === 0) {
        callback();
        return;
    }

    console.log(`Processing ${attackActions.length} attack actions...`);

    // To defer unit removal, we'll first process all attacks and record the outcomes
    // Then, after all attacks are processed, we'll remove units with strength <= 0

    attackActions.forEach(actionData => {
        const attacker = findUnitById(actionData.unitId);
        const targetTile = game.grid[`${actionData.targetTile.q},${actionData.targetTile.r}`];

        if (!attacker) {
            console.log(`Unit ${actionData.unitId} was not found`);
            return;
        }

        const actionDefinition = ACTIONS[actionData.actionKey];
        if (!actionDefinition) {
            console.log(`Action definition for '${actionData.actionKey}' not found.`);
            return;
        }

        // Deduct power here
        attacker.power -= actionDefinition.powerConsumption;
        console.log(`Unit ${attacker.unitId} power deducted by ${actionDefinition.powerConsumption}. New power: ${attacker.power}`);

        if (!targetTile) {
            console.log(`Target tile (${actionData.targetTile.q}, ${actionData.targetTile.r}) does not exist.`);
            game.lastTurnAttacks.push({
                attackerId: attacker.unitId,
                from: { q: attacker.tile.q, r: attacker.tile.r },
                to: { q: targetTile?.q || actionData.targetTile.q, r: targetTile?.r || actionData.targetTile.r },
                attackerPlayerId: attacker.playerId,
                outcome: 'miss'
            });
            return;
        }

        // Identify all defending units, friendly fire counts
        const defendingUnits = targetTile.units;

        if (defendingUnits.length === 0) {
            // No opponents on the target tile; attack misses
            console.log(`Unit ${attacker.unitId} attacked an empty tile (${actionData.targetTile.q}, ${actionData.targetTile.r}).`);
            game.lastTurnAttacks.push({
                attackerId: attacker.unitId,
                from: { q: attacker.tile.q, r: attacker.tile.r },
                to: { q: targetTile.q, r: targetTile.r },
                attackerPlayerId: attacker.playerId,
                outcome: 'miss'
            });
            return;
        }

        // Iterate over each defending unit and reduce their strength
        defendingUnits.forEach(defender => {
            defender.strength -= 50;
            console.log(`Unit ${attacker.unitId} attacked Unit ${defender.unitId}. Defender's strength is now ${defender.strength}.`);

            // Record each attack for visualization
            game.lastTurnAttacks.push({
                attackerId: attacker.unitId,
                from: { q: attacker.tile.q, r: attacker.tile.r },
                to: { q: targetTile.q, r: targetTile.r },
                attackerPlayerId: attacker.playerId,
                defenderId: defender.unitId, // Identify which defender was attacked
                outcome: defender.strength <= 0 ? 'defeated' : 'attacked'
            });
        });
    });

    callback();
}

// Add these functions below your existing action processing functions

function processHealAction(actionData) {
    const unit = findUnitById(actionData.unitId);
    if (!unit) {
        console.log(`Unit ${actionData.unitId} not found for healing.`);
        return;
    }

    const tile = game.grid[`${unit.tile.q},${unit.tile.r}`];
    if (!tile) {
        console.log(`Tile (${unit.tile.q}, ${unit.tile.r}) not found for healing.`);
        return;
    }
    
    const actionDefinition = ACTIONS[action.actionKey];
    if (!actionDefinition) {
        console.log(`Action definition for '${action.actionKey}' not found.`);
        return;
    }

    unit.strength = Math.min(MAX_STRENGTH_PER_UNIT, unit.strength + actionDefinition.strengthImpact);
    console.log(`Unit ${unit.unitId} healed by ${actionDefinition.strengthImpact}. New strength: ${unit.strength}`);

    // Record the heal for visualization
    game.lastTurnHeals.push({
        unitId: unit.unitId,
        tile: { q: tile.q, r: tile.r },
        amount: actionDefinition.strengthImpact
    });
}

function processSpawnAction(actionData) {
    const tile = game.grid[`${actionData.targetTile.q},${actionData.targetTile.r}`];
    if (!tile) {
        console.log(`Tile (${actionData.targetTile.q}, ${actionData.targetTile.r}) not found for spawning.`);
        return;
    }

    const actionDefinition = ACTIONS[action.actionKey];
    if (!actionDefinition) {
        console.log(`Action definition for '${action.actionKey}' not found.`);
        return;
    }

    const player = game.players.find(p => p.playerId === findUnitById(actionData.unitId).playerId);
    if (!player) {
        console.log(`Player not found for spawning.`);
        return;
    }

    if (player.units.length >= MAX_UNITS_PER_PLAYER) {
        console.log(`Player ${player.playerId} has reached the maximum number of units.`);
        player.ws.send(JSON.stringify({ type: 'error', message: `Maximum units reached. Cannot spawn more.` }));
        return;
    }

    spawnUnit(player, tile.q, tile.r);
    console.log(`Player ${player.playerId} spawned a new unit on tile (${tile.q}, ${tile.r}).`);

    // Record the spawn for visualization
    game.lastTurnSpawns.push({
        playerId: player.playerId,
        tile: { q: tile.q, r: tile.r },
        unitId: player.units[player.units.length - 1].unitId
    });
}

function removeDefeatedUnits() {
    console.log("Removing defeated units...");

    game.players.forEach(player => {
        const defeatedUnits = player.units.filter(unit => unit.strength <= 0);
        defeatedUnits.forEach(unit => {
            console.log(`Removing Unit ${unit.unitId} of Player ${unit.playerId} due to 0 strength.`);
            removeUnit(unit);
        });
    });
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
            color: player.color,
            units: player.units.map(unit => ({
                unitId: unit.unitId,
                playerId: unit.playerId,
                strength: unit.strength,
                power: unit.power,
                tile: { q: unit.tile.q, r: unit.tile.r }
            })),
            resources: player.resources
        })),
        turn: game.turn,
        playerActions: game.playerActions, 
        winConditions: game.winConditions,  // Include the selected win conditions
        trails: game.trails,
        fires: game.fires,
        attackLines: game.attackLines,
        lastTurnMovements: game.lastTurnMovements,
        lastTurnAttacks: game.lastTurnAttacks,
        lastTurnHeals: game.lastTurnHeals,    // New field for heals
        lastTurnSpawns: game.lastTurnSpawns,   // New field for spawns
        lastTurnReloads: game.lastTurnReloads,
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
            units: tile.units.map(unit => ({
                unitId: unit.unitId,
                playerId: unit.playerId,
                strength: unit.strength,
                power: unit.power,
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
    // Remove player from the game
    const playerIndex = playerId - 1;
    const player = game.players[playerIndex];
    if (player) {
        // Remove player's units from the grid
        player.units.forEach(unit => {
            const tile = unit.tile;
            if (tile) {
                const unitIndex = tile.units.findIndex(u => u.unitId === unit.unitId);
                if (unitIndex !== -1) {
                    tile.units.splice(unitIndex, 1);
                }
                // Optionally update ownership based on remaining units
                if (tile.units.length === 0) {
                    tile.owner = null;
                } else {
                    tile.owner = tile.units[0].playerId;
                }
            }
        });

        // Remove player from the players array
        game.players.splice(playerIndex, 1);
        clients.splice(playerIndex, 1);

        // Broadcast updated game state
        broadcastGameState();
    }
}

function handleRestart(playerId) {
    // Only allow restarting if initiated by all players or a specific condition
    if (game.players.length === NUM_PLAYERS) {
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
    game.playerActions = Array(NUM_PLAYERS).fill(null).map(() => []);
    game.trails = [];
    game.fires = [];
    game.attackLines = [];
    game.lastTurnMovements = [];
    game.lastTurnAttacks = [];
    game.lastTurnReloads = [];

    // Reinitialize the game grid and units
    generateInitialGameState();

    // Broadcast updated game state
    broadcastGameState();

    // Resend the ACTIONS list
    broadcast({
        type: 'actions_list',
        actions: game.actions
    });

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

function checkCustomWinConditions(player) {
    const { conditions } = game.winConditions;

    if (conditions.elimination) {
        // Check if all opponents' units are eliminated
        const opponents = game.players.filter(p => p.playerId !== player.playerId);
        const allOpponentsDefeated = opponents.every(opponent => opponent.units.length === 0);
        if (allOpponentsDefeated) {
            console.log(`Player ${player.playerId} wins by eliminating all opponents!`);
            return true;  // Win by elimination
        }
    }

    // Check resource-based win conditions
    for (let condition in conditions) {
        if (condition !== 'elimination' && player[condition] >= conditions[condition]) {
            console.log(`Player ${player.playerId} wins by satisfying the ${condition} condition!`);
            return true;  // Player meets a win condition
        }
    }

    return false;
}

function broadcast(message) {
    clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify(message));
        }
    });
}

console.log('WebSocket server is running on ws://localhost:8080');
