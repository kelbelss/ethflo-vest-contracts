// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VestMathLib} from "src/Libraries/VestMathLib.sol";
import {SafeTransferLib} from "lib/solady/src/utils/SafeTransferLib.sol";

/*
 * @title EthFlo Vest
 * @author Kelbels
 *
 * 
 *
 * @notice 
 * @notice 
 */
contract Vest {
    using SafeTransferLib for address;

    ///////////////////
    // Errors
    ///////////////////

    // addBeneficiary Errors
    error InsufficientAmount(uint256 balance, uint256 amount);
    error AmountTooLow(uint256 amount);
    error DurationTooLow(uint256 duration);

    // claimTokens Errors
    error NoVestingScheduleFound();
    error AllTokensClaimed();
    error VestingScheduleRevoked();
    error NoTokensToClaim();

    // revokeVestingSchedule Errors
    error VestingScheduleNotRevocable();

    ///////////////////
    // Types
    ///////////////////

    // Mapping - store vesting schedules: creator Address => (Beneficiary Address => VestingSchedule)
    mapping(address creator => mapping(address beneficiary => VestingSchedule)) public vestingSchedules;

    // structs

    // vesting schedule for a beneficiary.
    struct VestingSchedule {
        address token; // Address of company ERC20
        uint256 totalAmount; // Total amount of tokens to be vested
        uint256 startTime; // block.timestamp when vesting begins
        uint256 duration; // Duration of the vesting period (seconds)
        // uint256 cliffDuration; // Duration of the cliff period (seconds)
        uint256 claimedAmount; // Amount of tokens already claimed
        bool isRevocable; // Whether the vesting is revocable
        bool revoked; // Whether the vesting is revoked
        bool isDepleted; // Whether the vesting is depleted
    }

    ///////////////////
    // State Variables
    ///////////////////

    // use multisig for owner
    address public owner;
    uint256 internal s_totalEscrowedFunds;

    ///////////////////
    // Events
    ///////////////////

    // @notice Emitted when a new vesting schedule is added
    event TokensVested(
        address indexed creator,
        address indexed beneficiary,
        address indexed token,
        uint256 amount,
        uint256 startTime,
        uint256 duration
    );
    // @notice Emitted when tokens are claimed
    event TokensClaimed(address indexed creator, address indexed beneficiary, uint256 amountClaimed);

    ///////////////////
    // Functions
    ///////////////////

    constructor() {
        owner = msg.sender;
    }

    /*
     * @notice This function allows a creator to add a new beneficiary to a new vesting schedule.
     * @param _token The address of the token to be vested.
     * @param _beneficiary The address of the beneficiary.
     * @param _amount The total amount of tokens to be vested.
     * @param _startTime The block.timestamp when the vesting begins.
     * @param _duration The duration of the vesting period (seconds).
     * @param _isRevocable Whether the vesting is revocable.
     */
    function addBeneficiary(
        address _token,
        address _beneficiary,
        uint256 _amount,
        uint256 _startTime,
        uint256 _duration,
        bool _isRevocable
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
            totalAmount: _amount,
            startTime: _startTime,
            duration: _duration,
            claimedAmount: 0,
            isRevocable: _isRevocable,
            revoked: false,
            isDepleted: false
        });

        // add the new vesting schedule to the mapping
        vestingSchedules[msg.sender][_beneficiary] = newVestingSchedule;

        // update accounting
        s_totalEscrowedFunds += _amount;

        // emit event
        emit TokensVested(msg.sender, _beneficiary, _token, _amount, _startTime, _duration);
    }

    /*
     * @notice This function allows a beneficiary to claim their vested tokens.
     * @param creator The address of the creator.
     */
    function claimTokens(address creator) public {
        // get the vesting schedule - change to SLOAD operations to save gas - uint256 _duration = vestingSchedules[creator][msg.sender].duration;
        VestingSchedule memory vestingSchedule = vestingSchedules[creator][msg.sender];

        // ensure claimer is beneficiary - beneficiary is needed to find struct so probably not needed

        // ensure the beneficiary has a vesting schedule
        require(vestingSchedule.totalAmount > 0, NoVestingScheduleFound());

        // ensure the beneficiary has not claimed all tokens
        require(!vestingSchedule.isDepleted, AllTokensClaimed());

        // ensure the vesting schedule has not been revoked
        // require(!vestingSchedule.revoked, VestingScheduleRevoked());

        // calculate the amount of tokens that can be claimed
        uint256 claimableAmount = VestMathLib.calculateClaimableAmount(
            vestingSchedule.totalAmount, vestingSchedule.startTime, vestingSchedule.duration
        );

        // uint256 claimableAmount = vestingSchedule.calculateClaimableAmount();

        // ensure the beneficiary has tokens to claim
        require(claimableAmount > 0, NoTokensToClaim());

        // update the claimed amount
        vestingSchedule.claimedAmount += claimableAmount;

        // update the vesting schedule
        vestingSchedules[creator][msg.sender].claimedAmount = claimableAmount;

        // update accounting first
        s_totalEscrowedFunds -= claimableAmount;

        // if isRevoked is true, mark as depleted - this helps revokeVestingSchedule flow
        if (vestingSchedule.revoked) {
            vestingSchedule.isDepleted = true;
        }

        // solady for gas efficiency
        vestingSchedule.token.safeTransfer(msg.sender, claimableAmount);

        // emit event
        emit TokensClaimed(creator, msg.sender, claimableAmount);
    }

    /*
     * @notice This function allows a creator to revoke a beneficiary's vesting schedule.
     * @param beneficiary The address of the beneficiary.
     */
    function revokeVestingSchedule(address beneficiary) public {
        // get the vesting schedule
        VestingSchedule memory vestingSchedule = vestingSchedules[msg.sender][beneficiary];

        // ensure the beneficiary has a vesting schedule
        require(vestingSchedule.totalAmount > 0, NoVestingScheduleFound());

        // ensure the vesting schedule is revocable
        require(vestingSchedule.isRevocable, VestingScheduleNotRevocable());

        // ensure the vesting schedule has not been revoked
        require(!vestingSchedule.revoked, VestingScheduleRevoked());

        // update the vesting schedule
        vestingSchedules[msg.sender][beneficiary].revoked = true;

        // calculate the amount of tokens that can be claimed
        uint256 claimableAmount = VestMathLib.calculateClaimableAmount(
            vestingSchedule.totalAmount, vestingSchedule.startTime, vestingSchedule.duration
        );

        // check creator amount due
        uint256 creatorRefund = vestingSchedule.totalAmount - claimableAmount;

        // check bebneficiary amount due
        uint256 beneficiaryRefund = claimableAmount - vestingSchedule.claimedAmount;

        // mark as depleted if bene = 0
        if (beneficiaryRefund == 0) {
            vestingSchedule.isDepleted = true;
        }

        // refund creator
        vestingSchedule.token.safeTransfer(msg.sender, creatorRefund);

        // allow beneficiary to claim remaining tokens - leave require out of claimTokens

        // update accounting
        s_totalEscrowedFunds -= creatorRefund;
    }

    /*
     * @notice This function allows a creator to get the details of a beneficiary's vesting schedule.
     * @param creator The address of the creator.
     * @param beneficiary The address of the beneficiary.
     * @return VestingSchedule The vesting schedule.
     */
    function getVestedDetails(address creator, address beneficiary) public view returns (VestingSchedule memory) {
        return vestingSchedules[creator][beneficiary];
    }

    /*
     * @notice This function allows a creator to get the total amount of escrowed funds.
     * @return uint256 The total amount of escrowed funds.
     */
    function totalEscrowedFunds() public view returns (uint256) {
        return s_totalEscrowedFunds;
    }
}

// Notes

// 1. Add balances for each company - see how much is being held for each company and all their schedules
// 2. Audit as you go
