// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {ChronoLock} from "../src/ChronoLock.sol";
import {MockERC20} from "./MockERC20.sol";

contract ChronoLockTest is Test {
    MockERC20 mockToken;
    ChronoLock chronoLock;

    address USER = vm.addr(1);
    address BENEFICIARY = vm.addr(2);

    function setUp() public {
        mockToken = new MockERC20("Mock Token", "MTK", 18);
        chronoLock = new ChronoLock();

        mockToken.mint(USER, 1000 ether);
    }

    function test_addBeneficiary_success() public {
        uint256 amount = 20 ether;
        uint256 currentTimestamp = block.timestamp;
        uint256 duration = 1000;

        vm.startPrank(USER);
        mockToken.approve(address(chronoLock), amount);
        chronoLock.addBeneficiary(address(mockToken), BENEFICIARY, amount, currentTimestamp, duration);

        // decompose tuple manually
        (
            address token,
            address company,
            address beneficiary,
            uint256 totalAmount,
            uint256 startTime,
            uint256 durationFromSchedule,
            uint256 claimedAmount
        ) = chronoLock.vestingSchedules(USER, BENEFICIARY);

        // Validate vesting schedule
        assertEq(token, address(mockToken));
        assertEq(company, USER);
        assertEq(beneficiary, BENEFICIARY);
        assertEq(totalAmount, amount);
        assertEq(startTime, currentTimestamp);
        assertEq(durationFromSchedule, duration);
        assertEq(claimedAmount, 0);
    }
}
