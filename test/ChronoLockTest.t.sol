// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {ChronoLock} from "../src/ChronoLock.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract ChronoLockTest is Test {
    ERC20Mock mockToken;
    ChronoLock chronoLock;

    address USER = vm.addr(1);
    address BENEFICIARY = vm.addr(2);

    function setUp() public {
        mockToken = new ERC20Mock();
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

        console.log("Token: expected %s, got %s", address(mockToken), token);
        console.log("Company: expected %s, got %s", USER, company);
        console.log("Beneficiary: expected %s, got %s", BENEFICIARY, beneficiary);
        console.log("Total Amount: expected %s, got %s", amount, totalAmount);
        console.log("Start Time: expected %s, got %s", currentTimestamp, startTime);
        console.log("Duration: expected %s, got %s", duration, durationFromSchedule);
        console.log("Claimed Amount: expected 0, got %s", claimedAmount);
    }
}
