// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.19;

bytes32 constant BURNER_ROLE = bytes32(keccak256("BURNER"));
bytes32 constant MINTER_ROLE = bytes32(keccak256("MINTER"));
bytes32 constant FACTORY_ROLE = bytes32(keccak256("FACTORY"));
bytes32 constant MARKETPLACE_ROLE = bytes32(keccak256("FACTORY"));
bytes32 constant TRACKER_ROLE = bytes32(keccak256("TRACKER"));
bytes32 constant ROUTER_POLICY_ROLE = bytes32(keccak256("ROUTER_POLICY"));
//for revenue share
bytes32 constant CLAIMER_ROLE = keccak256("CLAIMER");
bytes32 constant DEPOSITOR_ROLE = keccak256("DEPOSITOR");
bytes32 constant SHARE_MANAGER_ROLE = keccak256("SHARE_MANAGER");
