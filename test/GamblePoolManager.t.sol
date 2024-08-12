// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/GamblePool.sol";
import "../src/GamblePoolManager.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor() ERC20("Mock Token", "MKT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

contract MockYieldStrategy is IYieldStrategy {
    uint256 public totalDeposited;
    uint256 public yieldAmount;
    ERC20 public token;

    constructor(ERC20 _token) {
        token = _token;
    }

    function setYieldAmount(uint256 _yieldAmount) external {
        yieldAmount = _yieldAmount;
    }

    function deposit(uint256 amount) external override {
        totalDeposited += amount;
        token.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw() external override {
        totalDeposited = 0;
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function getYield() external view override returns (uint256) {
        return yieldAmount;
    }
}

contract GamblePoolManagerTest is Test {
    GamblePoolManager public poolManager;
    MockYieldStrategy public strategy;
    ERC20Mock public token;
    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    function setUp() public {
        token = new ERC20Mock();
        strategy = new MockYieldStrategy(token);

        vm.prank(owner);
        poolManager = new GamblePoolManager();
    }

    function testCreatePool() public {
        vm.prank(owner);
        poolManager.createPool(token, strategy, 1 days, 7 days);
    }

    function testLockPool() public {}

    function testWithdrawFromYieldStrategy() public {}
}
