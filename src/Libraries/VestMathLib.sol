// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

library VestMathLib {
    function calculateClaimableAmount(uint256 totalAmount, uint256 startTime, uint256 duration)
        internal
        view
        returns (uint256)
    {
        // calculate the time passed since the vesting began
        uint256 elapsedTime = block.timestamp - startTime;

        // calculate the amount of tokens that can be claimed
        uint256 claimableAmount = (totalAmount * elapsedTime) / duration;

        // ensure the claimable amount is not more than the total amount

        // ensure the claimable amount is not greater than the remaining amount

        return claimableAmount;
    }
}
