// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

// SushiBar is the coolest bar in town. You come in with some Sushi, and leave with more! The longer you stay, the more Sushi you get.
//
// This contract handles swapping to and from xSushi, SushiSwap's staking token.
contract SushiBar is ERC20("SushiBar", "xSUSHI") {
    using SafeMath for uint256;
    IERC20 public sushi;

    mapping(address => uint256) public _lastTime;
    address public rewardPoolAddress;

    // Define the Sushi token contract
    constructor(IERC20 _sushi, address _rewardPool) public {
        sushi = _sushi;
        rewardPoolAddress = _rewardPool;
    }

    // Enter the bar. Pay some SUSHIs. Earn some shares.
    // Locks Sushi and mints xSushi
    function enter(uint256 _amount) public {
        // Gets the amount of Sushi locked in the contract
        uint256 totalSushi = sushi.balanceOf(address(this));
        // Gets the amount of xSushi in existence
        uint256 totalShares = totalSupply();
        // If no xSushi exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalSushi == 0) {
            _mint(msg.sender, _amount);
        }
        // Calculate and mint the amount of xSushi the Sushi is worth. The ratio will change overtime, as xSushi is burned/minted and Sushi deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalSushi);
            _mint(msg.sender, what);
        }
        // Lock the Sushi in the contract
        _lastTime[msg.sender] = block.timestamp;
        sushi.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the bar. Claim back your SUSHIs.
    // Unlocks the staked + gained Sushi and burns xSushi
    function leave(uint256 _share) public {
        // Gets the amount of xSushi in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of Sushi the xSushi is worth

        uint256 timeDiff = block.timestamp - _lastTime[msg.sender];
        uint256 what = _share.mul(sushi.balanceOf(address(this))).div(
            totalShares
        );
        uint256 tax = 0;

        if (timeDiff < 2 days) {
            require(false, "You can't unstake now. your sushi is still locked. please try again later after two days");
        } else if (timeDiff < 4 days) {
            tax = (what * 75) / 100;
            what -= tax;
        } else if (timeDiff < 6 days) {
            tax = (what * 50) / 100;
            what -= tax;
        } else if (timeDiff < 8 days) {
            tax = (what * 25) / 100;
            what -= tax;
        } else {
            tax = 0;
            what -= tax;
        }

        _burn(msg.sender, _share);
        sushi.transfer(msg.sender, what);

        // sendTokenToRewardPool
        if (tax > 0) {
            sushi.transfer(rewardPoolAddress, tax);
        }
    }
}
