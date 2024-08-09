// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IYieldStrategy {
    function deposit(uint256 amount) external;
    function withdraw() external;
    function getYield() external returns (uint256);
}

contract GamblePool is Ownable {
    IERC20 public token;
    IYieldStrategy public yieldStrategy;
    uint256 public beginCompletePeriod;
    uint256 public beginLockPeriod;
    bool public canWithdrawYield;
    address[] public entrants;
    mapping(address => uint256) public balances;

    event EnteredPool(address indexed user, uint256 amount);
    event PoolLocked(uint256 timestamp);
    event YieldDistributed(address indexed winner, uint256 yield);

    constructor(
        IERC20 _token,
        IYieldStrategy _yieldStrategy,
        uint256 _entryPeriodLength,
        uint256 _lockPeriodLength
    ) Ownable(msg.sender) {
        token = _token;
        yieldStrategy = _yieldStrategy;
        beginLockPeriod = block.timestamp + _entryPeriodLength;
        beginCompletePeriod = beginLockPeriod + _lockPeriodLength;
        canWithdrawYield = false;
    }

    modifier onlyInEntryPeriod() {
        require(
            block.timestamp < beginLockPeriod,
            "Pool is not in entry period"
        );
        _;
    }

    modifier onlyInLockPeriod() {
        require(
            beginLockPeriod <= block.timestamp &&
                block.timestamp <= beginCompletePeriod,
            "Pool is not in lock period"
        );
        _;
    }

    modifier onlyInCompletePeriod() {
        require(
            beginCompletePeriod < block.timestamp,
            "Pool is not in completed period"
        );
        _;
    }

    function enterPool(uint256 amount) external onlyInEntryPeriod {
        require(amount > 0, "Amount must be greater than 0");
        balances[msg.sender] += amount;
        entrants.push(msg.sender);
        token.transferFrom(msg.sender, address(this), amount);

        emit EnteredPool(msg.sender, amount);
    }

    function lockPool() external onlyInLockPeriod {
        require(entrants.length > 0, "No entrants in the pool");

        uint256 totalAmount = token.balanceOf(address(this));
        token.approve(address(yieldStrategy), totalAmount);
        yieldStrategy.deposit(totalAmount);

        emit PoolLocked(block.timestamp);
    }

    function withdrawFromYieldStrategy() external onlyInCompletePeriod {
        require(!canWithdrawYield, "Yield has already been unlocked");
        canWithdrawYield = true;
        yieldStrategy.withdraw();
    }

    function distributeYield() external onlyInCompletePeriod {
        require(canWithdrawYield, "Yield has not been unlocked");
        uint256 yieldAmount = yieldStrategy.getYield();
        address winner = entrants[random() % entrants.length];
        token.transfer(winner, yieldAmount);

        emit YieldDistributed(winner, yieldAmount);

        // Reset the pool
        delete entrants;
    }

    function withdrawPrincipal() external onlyInCompletePeriod {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance to withdraw");

        balances[msg.sender] = 0;
        token.transfer(msg.sender, amount);
    }

    // LOL use a real random function
    function random() private view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.prevrandao,
                        entrants
                    )
                )
            );
    }
}
