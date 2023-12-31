// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.19;

interface IFactoryProvider {
    function factory() external view returns (address);
}
