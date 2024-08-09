// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/GamblePool.sol";

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

    function getYield() external override view returns (uint256) {
        return yieldAmount;
    }
}

contract GamblePoolTest is Test {
    GamblePool public pool;
    MockYieldStrategy public strategy;
    ERC20Mock public token;
    address public user1;
    address public user2;

    function setUp() public {
        token = new ERC20Mock();
        strategy = new MockYieldStrategy(token);
        pool = new GamblePool(token, strategy, 1 days, 7 days);

        user1 = address(0x1);
        user2 = address(0x2);

        // Mint tokens to users for testing
        token.mint(user1, 1000 ether);
        token.mint(user2, 1000 ether);

        // Approve the pool contract to spend tokens on behalf of users
        vm.prank(user1);
        token.approve(address(pool), 1000 ether);

        vm.prank(user2);
        token.approve(address(pool), 1000 ether);
    }

    function testEnterPool() public {
        vm.warp(block.timestamp + 1 hours); // move time forward

        vm.prank(user1);
        pool.enterPool(100 ether);

        assertEq(token.balanceOf(address(pool)), 100 ether);
        assertEq(pool.balances(user1), 100 ether);
    }

    function testCannotEnterPoolAfterEntryPeriod() public {
        vm.warp(block.timestamp + 2 days); // move time forward beyond entry period

        vm.prank(user1);
        vm.expectRevert("Pool is not in entry period");
        pool.enterPool(100 ether);
    }

    function testLockPool() public {
        vm.prank(user1);
        pool.enterPool(100 ether);

        vm.warp(block.timestamp + 2 days); // move time forward to lock period

        pool.lockPool();

        assertEq(strategy.totalDeposited(), 100 ether);
    }

    function testDistributeYield() public {
        vm.prank(user1);
        pool.enterPool(1000 ether);

        vm.warp(block.timestamp + 2 days); // move time forward to lock period
        pool.lockPool();

        uint256 yeildAmount = 10 ether;
        token.mint(address(strategy), yeildAmount);
        strategy.setYieldAmount(yeildAmount); // Set the mock yield

        vm.warp(block.timestamp + 8 days); // move time forward to complete period
        pool.withdrawFromYieldStrategy();

        pool.distributeYield();

        // Check that the yield was transferred to one of the entrants
        assertEq(token.balanceOf(user1), yeildAmount);
    }

    function testWithdrawPrincipal() public {
        vm.prank(user1);
        pool.enterPool(100 ether);

        vm.warp(block.timestamp + 2 days); // move time forward to lock period
        pool.lockPool();

        vm.warp(block.timestamp + 8 days); // move time forward to complete period
        pool.withdrawFromYieldStrategy();

        vm.prank(user1);
        pool.withdrawPrincipal();

        assertEq(token.balanceOf(user1), 1000 ether); // user1 got their principal back
    }
}
