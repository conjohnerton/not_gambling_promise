// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./GamblePool.sol";


contract GamblePoolManager is Ownable {
    event PoolCreated(address newPool, address yieldStrategy);
    event PoolsClosed(uint256 timestamp);
    event PoolLocked(address pool);
    event BalanceWithdrawnFromYieldStrategy(address pool);

    constructor() Ownable(msg.sender) {}

    function createPool(
        IERC20 _token,
        IYieldStrategy _yieldStrategy,
        uint256 _entryPeriodLength,
        uint256 _lockPeriodLength
    ) external onlyOwner returns (address pool) {
        GamblePool newPool = new GamblePool(
            _token,
            _yieldStrategy,
            _entryPeriodLength,
            _lockPeriodLength
        );

        emit PoolCreated(address(newPool), address(_yieldStrategy));
    }

    function lockPool(GamblePool pool) external onlyOwner {
        pool.lockPool();
        emit PoolLocked(address(pool));
    }

    function withdrawFromYieldStrategy(GamblePool pool) external onlyOwner {
        pool.withdrawFromYieldStrategy();
        emit BalanceWithdrawnFromYieldStrategy(address(pool));
    }
}
