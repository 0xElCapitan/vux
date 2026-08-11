// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IUnit {
    function mint(address account, uint256 amount) external;
    function burn(uint256 amount) external;
    function setRig(address _rig) external;
    function rig() external view returns (address);
}
