/**
 * gameConfig.js
 *
 * This file contains the definitions for actions, unit types, tile types,
 * as well as all game configuration attributes.
 */

// -------------------------
// Actions Definitions
// -------------------------
const ACTIONS = {
    fast_move: {
      key: 'fast_move',
      type: 'fast move',
      name: 'Fast Move',
      minRange: 1,
      maxRange: 1,
      powerConsumption: 0,
      strengthImpact: 0,
      applyTo: 'none',
      self: false
    },
    move_short: {
      key: 'move_short',
      type: 'move',
      name: 'Move',
      minRange: 1,
      maxRange: 1,
      powerConsumption: 0,
      strengthImpact: 0,
      applyTo: 'none',
      self: false
    },
    slow_move: {
      key: 'slow_move',
      type: 'slow move',
      name: 'Slow Move',
      minRange: 1,
      maxRange: 1,
      powerConsumption: 0,
      strengthImpact: 0,
      applyTo: 'none',
      self: false
    },
    dash: {
      key: 'dash',
      type: 'fast move',
      name: 'Dash',
      minRange: 2,
      maxRange: 2,
      powerConsumption: 4,
      strengthImpact: 0,
      applyTo: 'none',
      self: false
    },
    attack_short: {
      key: 'attack_short',
      type: 'attack',
      name: 'Attack',
      minRange: 1,
      maxRange: 1,
      powerConsumption: 2,
      strengthImpact: -35,
      applyTo: 'enemies',
      self: false,
      areaOfEffect: {
        directions: [2],
        distance: 1,
        impact: -35
      }
    },
    fast_attack: {
      key: 'fast_attack',
      type: 'fast attack',
      name: 'Fast Attack',
      minRange: 1,
      maxRange: 2,
      powerConsumption: 2,
      strengthImpact: -30,
      applyTo: 'enemies',
      self: false
    },
    spit: {
      key: 'spit',
      type: 'fast attack',
      name: 'Spit',
      minRange: 1,
      maxRange: 2,
      powerConsumption: 1,
      strengthImpact: -35,
      applyTo: 'enemies',
      self: false
    },
    attack_passive: {
      key: 'attack_passive',
      type: 'slow attack',
      name: 'Passive Attack',
      minRange: 0,
      maxRange: 0,
      powerConsumption: 0,
      strengthImpact: -35,
      applyTo: 'enemies',
      self: false
    },
    attack_long: {
      key: 'attack_long',
      type: 'attack',
      name: 'Long Attack',
      minRange: 2,
      maxRange: 2,
      powerConsumption: 2,
      strengthImpact: -35,
      duration: 1,
      applyTo: 'enemies',
      self: false
    },
    reload: {
      key: 'reload',
      type: 'reload',
      name: 'Rest',
      minRange: 0,
      maxRange: 0,
      powerConsumption: -1,
      strengthImpact: 0,
      applyTo: 'none',
      self: false
    },
    regenerate: {
      key: 'regenerate',
      type: 'slow attack',
      name: 'Regenerate',
      minRange: 0,
      maxRange: 0,
      powerConsumption: 0,
      strengthImpact: 5,
      applyTo: 'none',
      self: true
    },
    heal: {
      key: 'heal',
      type: 'attack',
      name: 'Heal',
      minRange: 1,
      maxRange: 1,
      powerConsumption: 2,
      strengthImpact: 20,
      applyTo: 'friendly',
      self: true
    },
    selfHeal: {
      key: 'selfHeal',
      type: 'attack',
      name: 'Self Heal',
      minRange: 0,
      maxRange: 0,
      powerConsumption: 2,
      strengthImpact: 20,
      applyTo: 'friendly',
      self: true
    },
    spawn_zergling: {
      key: 'spawn_zergling',
      type: 'spawn',
      name: 'Spawn Zergling',
      minRange: 0,
      maxRange: 0,
      powerConsumption: 3,
      strengthImpact: 0,
      applyTo: 'none',
      self: false,
      unitType: 'zergling'
    },
    spawn_baneling: {
      key: 'spawn_baneling',
      type: 'spawn',
      name: 'Spawn Baneling',
      minRange: 0,
      maxRange: 0,
      powerConsumption: 2,
      strengthImpact: 0,
      applyTo: 'none',
      self: false,
      unitType: 'baneling'
    },
    spawn_ravager: {
      key: 'spawn_ravager',
      type: 'spawn',
      name: 'Spawn Ravager',
      minRange: 0,
      maxRange: 0,
      powerConsumption: 4,
      strengthImpact: 0,
      applyTo: 'none',
      self: false,
      unitType: 'ravager'
    },
    attack_ray: {
      key: 'attack_ray',
      type: 'slow attack',
      name: 'Attack Ray',
      minRange: 1,
      maxRange: 1,
      powerConsumption: 2,
      strengthImpact: -45,
      applyTo: 'enemies',
      self: false,
      areaOfEffect: {
        directions: [4, 2],
        distance: 1,
        impact: -45
      }
    },
    attack_mortar: {
      key: 'attack_mortar',
      type: 'attack',
      name: 'Mortar Attack',
      minRange: 2,
      maxRange: 2,
      powerConsumption: 2,
      strengthImpact: -35,
      applyTo: 'all',
      self: false,
      delay: 1,
      areaOfEffect: {
        directions: [3],
        distance: 1,
        impact: -35
      }
    },
    stun: {
      key: 'stun',
      type: 'stun',
      name: 'Stun',
      minRange: 0,
      maxRange: 0,
      powerConsumption: 0,
      strengthImpact: 0,
      applyTo: 'enemies',
      self: false,
      disableActions: ['move', 'attack']
    },
    explode: {
      key: 'explode',
      type: 'slow attack',
      name: 'Explode',
      minRange: 1,
      maxRange: 1,
      powerConsumption: 0,
      strengthImpact: -50,
      applyTo: 'all',
      self: true,
      areaOfEffect: {
        directions: [3],
        distance: 1,
        impact: -50
      }
    },
    deconstruct: {
      key: 'deconstruct',
      type: 'slow attack',
      name: 'deconstruct',
      minRange: 0,
      maxRange: 0,
      powerConsumption: 0,
      strengthImpact: -100,
      applyTo: 'none',
      self: true
    },
    extract_resource: {
      key: 'extract_resource',
      type: 'extract',
      name: 'Extract Resource',
      minRange: 0,
      maxRange: 0,
      powerConsumption: 1,
      strengthImpact: 0,
      applyTo: 'none',
      self: false
    },
    baneling_evolve: {
      key: 'baneling_evolve',
      name: 'Baneling Evolution',
      type: 'evolve',
      powerConsumption: 3,
      maxRange: 0,
      transformUnitType: 'baneling'
    },
    build_pylon: {
      key: 'build_pylon',
      name: 'Build Pylon',
      type: 'spawn',
      powerConsumption: 3,
      minRange: 0,
      maxRange: 1,
      unitType: 'pylon',
      resourceCost: { gold: 2 }
    },
    warp_zealot: {
      key: 'warp_zealot',
      name: 'Warp Zealot',
      type: 'spawn',
      powerConsumption: 2,
      minRange: 0,
      maxRange: 0,
      unitType: 'zealot'
    },
    warp_stalker: {
      key: 'warp_stalker',
      name: 'Warp Stalker',
      type: 'spawn',
      powerConsumption: 2,
      minRange: 0,
      maxRange: 0,
      unitType: 'stalker'
    },
    warp_colossus: {
      key: 'warp_colossus',
      name: 'Warp Colossus',
      type: 'spawn',
      powerConsumption: 3,
      minRange: 0,
      maxRange: 0,
      unitType: 'colossus'
    },
    warp_probe: {
      key: 'warp_probe',
      name: 'Warp Probe',
      type: 'spawn',
      powerConsumption: 2,
      minRange: 0,
      maxRange: 0,
      unitType: 'probe'
    },
    build_factory: {
      key: 'build_factory',
      name: 'Build Factory',
      type: 'spawn',
      powerConsumption: 2,
      minRange: 0,
      maxRange: 1,
      unitType: 'factory',
      resourceCost: { gold: 3 }
    },
    build_tank: {
      key: 'build_tank',
      name: 'Build Tank',
      type: 'spawn',
      powerConsumption: 4,
      minRange: 0,
      maxRange: 0,
      unitType: 'tank'
    },
    build_ifv: {
      key: 'build_ifv',
      name: 'Build IFV',
      type: 'spawn',
      powerConsumption: 3,
      minRange: 0,
      maxRange: 0,
      unitType: 'ifv'
    },
    build_scv: {
      key: 'build_scv',
      name: 'Build SCV',
      type: 'spawn',
      powerConsumption: 2,
      minRange: 0,
      maxRange: 0,
      unitType: 'scv'
    },
    move_with_resources: {
      key: 'move_with_resources',
      type: 'move',
      name: 'Move with Resources',
      minRange: 1,
      maxRange: 1,
      powerConsumption: 1,
      strengthImpact: 0,
      applyTo: 'none',
      self: false,
      movesResources: true
    }
};
  
  // -------------------------
  // Unit Types Definitions
  // -------------------------
  const UNIT_TYPES = {
    ifv: {
      name: 'IFV',
      strength: 75,
      actions: ['move_short', 'attack_short', 'reload'],
      passiveActions: ['attack_passive', 'reload'],
      color: '#00FF00'
    },
    tank: {
      name: 'Tank',
      strength: 100,
      actions: ['move_short', 'attack_long', 'reload'],
      passiveActions: ['reload'],
      color: '#FFAA00'
    },
    scv: {
      name: 'SCV',
      strength: 100,
      actions: ['fast_move', 'move_with_resources', 'build_factory', 'heal', 'selfHeal', 'reload', 'extract_resource'],
      passiveActions: ['reload'],
      color: '#FFAA00'
    },
    factory: {
      name: 'Factory',
      strength: 75,
      actions: ['build_scv', 'build_tank', 'build_ifv', 'reload'],
      passiveActions: [],
      color: '#FFAA00',
      isStructure: true
    },
    zergling: {
      name: 'Zergling',
      strength: 70,
      actions: ['fast_move', 'move_with_resources', 'reload', 'extract_resource'],
      passiveActions: ['stun', 'attack_passive'],
      color: '#0000FF'
    },
    ravager: {
      name: 'Ravager',
      strength: 100,
      actions: ['move_short', 'attack_mortar', 'reload'],
      passiveActions: ['reload'],
      color: '#9C27B0'
    },
    baneling: {
      name: 'Baneling',
      strength: 50,
      actions: ['move_short', 'explode', 'reload'],
      passiveActions: [],
      color: '#FFD700'
    },
    queen: {
      name: 'Queen',
      strength: 110,
      actions: ['move_short', 'spit', 'reload', 'spawn_zergling', 'spawn_baneling', 'spawn_ravager'],
      passiveActions: ['attack_passive', 'regenerate'],
      color: '#FFD700'
    },
    zealot: {
      name: 'Zealot',
      strength: 75,
      actions: ['move_short', 'dash', 'reload'],
      passiveActions: ['stun', 'reload', 'attack_passive', 'regenerate'],
      color: '#FFD700'
    },
    stalker: {
      name: 'Stalker',
      strength: 70,
      actions: ['move_short', 'fast_attack', 'reload'],
      passiveActions: ['reload', 'regenerate'],
      color: '#FFD700'
    },
    colossus: {
      name: 'Colossus',
      strength: 110,
      actions: ['slow_move', 'attack_ray', 'reload'],
      passiveActions: ['reload', 'regenerate'],
      color: '#FFD700'
    },
    pylon: {
      name: 'Pylon',
      strength: 100,
      startingPower: 5,
      actions: ['warp_zealot', 'warp_stalker', 'warp_colossus', 'warp_probe', 'deconstruct'],
      passiveActions: [],
      color: '#FFD700'
    },
    probe: {
      name: 'Probe',
      strength: 50,
      actions: ['move_short', 'move_with_resources', 'reload', 'extract_resource', 'build_pylon'],
      passiveActions: ['reload', 'regenerate'],
      color: '#FFD700'
    }
  };
  
  // -------------------------
  // Tile Types Definitions
  // -------------------------
  const TileTypes = {
    wood: {
      color: '#8B4513', // Brown color for wood tile
      resources: ['wood']
    },
    gold: {
      color: '#ffd700', // Gold color for gold tile
      resources: ['gold'],
      growthFrequency: 5,
      maxResource: 20
    },
    healing: {
      color: '#ff6347', // Red color for healing tile
      actions: [{ type: 'heal', healAmount: 15 }]
    },
    default: {
      color: '#e0e0e0', // Default gray tile
      resources: [],
      actions: []
    },
    water: {
      color: '#00BFFF', // Light blue color for water tile
      actions: [{ type: 'heal', healAmount: 5 }]
    },
    forest: {
      color: '#228B22',  // Forest green color
      resources: ['wood'],
      actions: [{ type: 'heal', healAmount: 10 }]
    }
  };
  
  // -------------------------
  // Game Configuration Attributes
  // -------------------------
  const NUM_PLAYERS = 2;
  const MAX_PLAYERS = 6;
  const MAX_POWER_PER_UNIT = 5;
  const GRID_SIZE = 4;
  
  const actionOrder = [
    { type: 'fast move',  color: '#0055FF' },  // Blue
    { type: 'fast attack', color: '#FF5500' },  // Red
    { type: 'stun',        color: '#07dfe3' },  // Turquoise
    { type: 'move',        color: '#0000FF' },  // Blue
    { type: 'attack',      color: '#FF0000' },  // Red
    { type: 'slow move',   color: '#5500FF' },  // Blue
    { type: 'slow attack', color: '#FF0055' },  // Red
    { type: 'spawn',       color: '#2ab82a' },  // Green
    { type: 'evolve',      color: '#2ab82a' },  // Green
    { type: 'reload',      color: '#ad00a8' },  // Purple
    { type: 'extract',     color: '#FFD700' }   // Gold
  ];
  
  const hexDirections = [
    { dq: 1, dr: 0 },    // Direction 0
    { dq: 1, dr: -1 },   // Direction 1
    { dq: 0, dr: -1 },   // Direction 2
    { dq: -1, dr: 0 },   // Direction 3
    { dq: -1, dr: 1 },   // Direction 4
    { dq: 0, dr: 1 }     // Direction 5
  ];
  
  const cubeDirections = [
    { x: 1, y: -1, z: 0 }, // Direction 0
    { x: 1, y: 0, z: -1 }, // Direction 1
    { x: 0, y: 1, z: -1 }, // Direction 2
    { x: -1, y: 1, z: 0 }, // Direction 3
    { x: -1, y: 0, z: 1 }, // Direction 4
    { x: 0, y: -1, z: 1 }  // Direction 5
  ];

  // -------------------------
// Faction Definitions
// -------------------------
const FACTIONS = {
    Zerg: {
        description: "The Zerg focus on protecting the Queen and large numbers to overwheling their opponents. Individuals may be sacrificed for the greater good.",
        color: "#FF0000",
        unitTypes: ["zergling", "baneling", "ravager", "queen"],
        initialUnits: ['zergling', 'zergling', 'queen']
        //initialUnits = ['queen'];
    },
    Protos: {
        description: "The Protos warp in units and have a diverse a technical army",
        color: "#800080",
        unitTypes: ["probe", "zealot", "stalker", "colossus", "pylon"],
        initialUnits: ['probe', 'zealot', 'zealot']
        //initialUnits = ['probe'];
    },
    Terran: {
        description: "Terran are a simpler and balanced faction",
        color: "#0000FF",
        unitTypes: ["scv", "ifv", "tank", "factory"],
        initialUnits: ['scv', 'ifv', 'ifv']
        //initialUnits = ['scv']
    },
    green: {
        description: "The balanced Green faction focuses on resource management and support units.",
        color: "#4CAF50",
        unitTypes: ["scv", "ifv", "tank", "factory"],
        initialUnits: ['scv', 'ifv', 'ifv']
        //initialUnits = ['scv']
    },
};
  
  // -------------------------
  // Exports
  // -------------------------
  module.exports = {
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
  };