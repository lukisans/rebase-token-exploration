// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IRebaseToken {
    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external;
    function burn(address _from, uint256 _amount) external;
    function getInterestRate() external view returns (uint256);
    function balanceOf(address _account) external view returns (uint256);
}
