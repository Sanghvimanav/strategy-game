extends Node

signal show_move_acs(acs)
signal show_attack_acs(acs, from_cell)
signal show_move_path(ac, from_cell)
signal show_selected_unit_cell(cell)
signal planning_started
signal planning_complete
signal execute_turn_requested
signal replay_turn_requested
signal unit_selected_for_planning(unit)
signal unit_pick_requested(unit)
signal show_units_panel(units: Array)
signal show_replay_summary(lines: Array)
signal action_key_selected(action_key)
signal turn_changed(turn_number)
signal replay_available_changed(available: bool)
signal replay_finished