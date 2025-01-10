// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ChronoLock {
    // state variables

    // use multisig for owner
    address public owner;

    // Mapping - store vesting schedules: Company Address => (Beneficiary Address => VestingSchedule)
    mapping(address company => mapping(address beneficiary => VestingSchedule)) public vestingSchedules;

    // structs

    // vesting schedule for a beneficiary.
    struct VestingSchedule {
        address token; // Address of company ERC20
        address company; // Address of the company creating the schedule
        address beneficiary; // Address of beneficiary
        uint256 totalAmount; // Total amount of tokens to be vested
        uint256 startTime; // block.timestamp when vesting begins
        uint256 duration; // Duration of the vesting period (seconds)
        // uint256 cliffDuration; // Duration of the cliff period (seconds)
        uint256 claimedAmount; // Amount of tokens already claimed
    }

    // events

    // @notice Emitted when a new vesting schedule is added
    event TokensVested(
        address indexed company,
        address indexed beneficiary,
        address indexed token,
        uint256 amount,
        uint256 startTime,
        uint256 duration
    );

    // errors

    // addBeneficiary Errors
    error InsufficientAllowance(uint256 balance, uint256 amount_required);
    error AmountTooLow(uint256 amount);
    error DurationTooLow(uint256 duration);

    constructor() {
        owner = msg.sender;
    }

    // functions

    function addBeneficiary(
        address _token,
        address _beneficiary,
        uint256 _amount,
        uint256 _startTime,
        uint256 _duration
    ) public {
        // ensure amount is above 0
        require(_amount > 0, AmountTooLow(_amount));

        // ensure duration is above 0
        require(_duration > 0, DurationTooLow(_duration));

        // allowance - Returns the remaining number of tokens that `spender` will be allowed to spend on behalf of `owner` through {transferFrom}.
        // ensure company calling function has approved this contract to spend the amount of tokens
        require(
            IERC20(_token).allowance(msg.sender, address(this)) >= _amount,
            InsufficientAllowance(IERC20(_token).allowance(msg.sender, address(this)), _amount)
        );

        // check if bene already has one?
        // calculate start time and end time?

        // create a new vesting schedule
        VestingSchedule memory newVestingSchedule = VestingSchedule({
            token: _token,
            company: msg.sender,
            beneficiary: _beneficiary,
            totalAmount: _amount,
            startTime: _startTime,
            duration: _duration,
            claimedAmount: 0
        });

        // add the new vesting schedule to the mapping
        vestingSchedules[msg.sender][_beneficiary] = newVestingSchedule;

        // emit event
        emit TokensVested(msg.sender, _beneficiary, _token, _amount, _startTime, _duration);
    }
}
