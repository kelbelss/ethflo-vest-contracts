// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeTransferLib} from "lib/solady/src/utils/SafeTransferLib.sol";

contract ChronoLock {
    using SafeTransferLib for address;

    // state variables

    // use multisig for owner
    address public owner;
    uint256 internal s_totalEscrowedFunds;

    // Mapping - store vesting schedules: Company Address => (Beneficiary Address => VestingSchedule)
    mapping(address company => mapping(address beneficiary => VestingSchedule)) public vestingSchedules;

    // structs

    // vesting schedule for a beneficiary.
    struct VestingSchedule {
        address token; // Address of company ERC20
        // address company; // Address of the company creating the schedule
        // address beneficiary; // Address of beneficiary
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
    // @notice Emitted when tokens are claimed
    // event TokensClaimed();

    // errors

    // addBeneficiary Errors
    error InsufficientAmount(uint256 balance, uint256 amount);
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

        // transfer the tokens from the company to this contract
        // bool success = IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        // require(success, InsufficientAmount(IERC20(_token).allowance(msg.sender, address(this)), _amount));

        // solady for gas efficiency
        _token.safeTransferFrom(msg.sender, address(this), _amount);

        // create a new vesting schedule
        VestingSchedule memory newVestingSchedule = VestingSchedule({
            token: _token,
            // company: msg.sender,
            // beneficiary: _beneficiary,
            totalAmount: _amount,
            startTime: _startTime,
            duration: _duration,
            claimedAmount: 0
        });

        // add the new vesting schedule to the mapping
        vestingSchedules[msg.sender][_beneficiary] = newVestingSchedule;

        // update accounting
        s_totalEscrowedFunds += _amount;

        // emit event
        emit TokensVested(msg.sender, _beneficiary, _token, _amount, _startTime, _duration);
    }

    function claimTokens(address company) public {
        // get the vesting schedule
        VestingSchedule storage vestingSchedule = vestingSchedules[company][msg.sender];

        // ensure claimer is beneficiary

        // ensure the beneficiary has a vesting schedule
        require(vestingSchedule.totalAmount > 0, "No vesting schedule found"); // NoVestingScheduleFound

        // ensure the beneficiary has not claimed all tokens
        require(vestingSchedule.claimedAmount < vestingSchedule.totalAmount, "All tokens claimed"); // AllTokensClaimed

        // calculate the amount of tokens that can be claimed
        uint256 claimableAmount = _calculateClaimableAmount(vestingSchedule);

        // ensure the beneficiary has tokens to claim
        require(claimableAmount > 0, "No tokens to claim"); // NoTokensToClaim

        // update the claimed amount
        vestingSchedule.claimedAmount += claimableAmount;

        // update accounting first
        s_totalEscrowedFunds -= claimableAmount;

        // solady for gas efficiency
        vestingSchedule.token.safeTransfer(msg.sender, claimableAmount);

        // emit event
        // emit TokensClaimed();
    }

    function _calculateClaimableAmount(VestingSchedule memory _vestingSchedule) internal view returns (uint256) {
        // calculate the time passed since the vesting began
        uint256 elapsedTime = block.timestamp - _vestingSchedule.startTime;

        // calculate the amount of tokens that can be claimed
        uint256 claimableAmount = (_vestingSchedule.totalAmount * elapsedTime) / _vestingSchedule.duration;

        // ensure the claimable amount is not more than the total amount

        // ensure the claimable amount is not greater than the remaining amount

        return claimableAmount;
    }
}
