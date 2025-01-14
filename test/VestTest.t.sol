// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Vest} from "../src/Vest.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {VestMathLib} from "src/Libraries/VestMathLib.sol";

contract VestTest is Test {
    Vest public vest;
    ERC20Mock public mockToken;

    address USER = vm.addr(1);
    address BENEFICIARY = vm.addr(2);

    uint256 amount = 100 ether;
    uint256 currentTimestamp = block.timestamp;
    uint256 duration = 365 days;

    function setUp() public {
        mockToken = new ERC20Mock();
        vest = new Vest();

        mockToken.mint(USER, 1000 ether);
    }

    function addBeneficiary() public {
        vm.startPrank(USER);
        mockToken.approve(address(vest), amount);
        vest.addBeneficiary(address(mockToken), BENEFICIARY, amount, currentTimestamp, duration);
        vm.stopPrank();
    }

    function test_addBeneficiary_success() public {
        vm.startPrank(USER);
        mockToken.approve(address(vest), amount);
        vest.addBeneficiary(address(mockToken), BENEFICIARY, amount, currentTimestamp, duration);

        // decompose tuple manually
        (address token, uint256 totalAmount, uint256 startTime, uint256 durationSet, uint256 claimedAmount) =
            vest.vestingSchedules(USER, BENEFICIARY);

        // Validate vesting schedule
        assertEq(token, address(mockToken));
        assertEq(totalAmount, amount);
        assertEq(startTime, currentTimestamp);
        assertEq(durationSet, duration);
        assertEq(claimedAmount, 0);

        console.log("Token: expected", address(mockToken), "got", token);
        console.log("Total Amount: expected", amount, "got", totalAmount);
        console.log("Start Time: expected", currentTimestamp, "got", startTime);
        console.log("Duration: expected", duration, "got", durationSet);
        console.log("Claimed Amount: expected", 0, "got", claimedAmount);
    }

    // function test_addBeneficiary_fail_AmountTooLow() public {}
    // function test_addBeneficiary_fail_DurationTooLow() public {}
    // function test_addBeneficiary_fail_InsufficientAmount() public {}
    // function test_addBeneficiary_event_TokensVested() public {}

    function test_claimTokens_success() public {
        addBeneficiary();

        vm.warp(currentTimestamp + duration / 2); // warp to halfway

        // get vesting schedule to pass to the library
        (, uint256 totalAmount, uint256 startTime, uint256 durationSet,) = vest.vestingSchedules(USER, BENEFICIARY);

        // calculate the expected claimable amount using the library
        uint256 expectedClaimableAmount = VestMathLib.calculateClaimableAmount(totalAmount, startTime, durationSet);

        // call claimTokens
        vm.startPrank(BENEFICIARY);
        vest.claimTokens(USER);
        vm.stopPrank();

        // get updated vesting schedule

        address token;
        uint256 claimedAmount;

        (token, totalAmount, startTime, durationSet, claimedAmount) = vest.vestingSchedules(USER, BENEFICIARY);

        // check the results
        assertEq(token, address(mockToken), "Token address mismatch");
        assertEq(totalAmount, amount, "Total amount mismatch");
        assertEq(startTime, currentTimestamp, "Start time mismatch");
        assertEq(durationSet, duration, "Duration mismatch");
        assertEq(claimedAmount, expectedClaimableAmount, "Claimed amount incorrect");

        console.log("After Claim - Token:", token);
        console.log("After Claim - Total Amount:", totalAmount);
        console.log("After Claim - Start Time:", startTime);
        console.log("After Claim - Duration:", durationSet);
        console.log("After Claim - Claimed Amount:", claimedAmount);

        // check the bene's token balance
        console.log("After Claim - Beneficiary Token Balance:", mockToken.balanceOf(BENEFICIARY));
        assertEq(mockToken.balanceOf(BENEFICIARY), expectedClaimableAmount, "Beneficiary balance incorrect");
    }
}
