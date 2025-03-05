// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract TokenVesting is  Initializable, UUPSUpgradeable, OwnableUpgradeable{
    /// @notice Initialize the contract, only callable once

    address public canUpgradeAddress;
    struct LockInfo {
        address beneficiary;
        uint256 amount;
        uint256 lockStartTime;
        uint256 lockEndTime;
        uint256 withdrawnAmount;
    }

    // token => beneficiary => lockInfo[]
    mapping(address => mapping(address => LockInfo[])) public beneficiary2LockInfos;

    event LockedForBeneficiary(address indexed token, address indexed beneficiary, uint256 amount, uint256 lockStartTime, uint256 lockEndTime);
    event Withdrawn(address indexed token, address indexed beneficiary, uint256 amount);

    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();

        canUpgradeAddress = msg.sender;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    function setCanUpgradeAddress(address _canUpgradeAddress) external onlyOwner {
        canUpgradeAddress = _canUpgradeAddress;
    }

    function _authorizeUpgrade(address newImplementation) internal view override  {
        require(newImplementation!= address(0), "Invalid address");
        require(msg.sender == canUpgradeAddress, "Only authorized address can upgrade");
    }

    function getAvailableWithdrawalAmount(address _token,address _beneficiary) external view returns(uint256) {
        LockInfo[] storage lockInfos = beneficiary2LockInfos[_token][_beneficiary];
        uint256 availableAmount = 0;
        for (uint256 i = 0; i < lockInfos.length; i++){
            availableAmount += _getAvailableWithdrawalAmount(lockInfos[i]);
        }
        return availableAmount;
    }

    function _getAvailableWithdrawalAmount(LockInfo storage lockInfo) internal view returns(uint256) {
        if (lockInfo.lockStartTime > block.timestamp){
            return 0;
        }
        if (lockInfo.amount <= lockInfo.withdrawnAmount) {
            return 0;
        }

        if (lockInfo.lockEndTime < block.timestamp){
            return lockInfo.amount - lockInfo.withdrawnAmount;
        }

        uint256 availableAmount = lockInfo.amount * (block.timestamp - lockInfo.lockStartTime) / (lockInfo.lockEndTime - lockInfo.lockStartTime) - lockInfo.withdrawnAmount;
        return availableAmount;
    }

    function withdraw(address _token) external {
        LockInfo[] storage lockInfos = beneficiary2LockInfos[_token][msg.sender];
        uint256 availableAmount = 0;
        for (uint256 i = 0; i < lockInfos.length; i++){
            LockInfo storage lockInfo = lockInfos[i];
            uint256 amount = _getAvailableWithdrawalAmount(lockInfo);
            if (amount > 0){
                lockInfo.withdrawnAmount += amount;
                availableAmount += amount;
            }
        }
        if (availableAmount > 0){
            SafeERC20.safeTransfer(IERC20(_token), msg.sender, availableAmount);
        }

        emit Withdrawn(_token, msg.sender, availableAmount);
    }

    function lockForBeneficiary(address _token, address _beneficiary, uint256 _amount, uint256 _lockStartTime, uint256 _lockEndTime) external {
        require(_lockStartTime < _lockEndTime, "Invalid lock time");
        require(_lockEndTime > block.timestamp, "Lock time has passed");
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_token != address(0), "Invalid token");
        require(_amount > 0, "Invalid amount");
        require(IERC20(_token).balanceOf(msg.sender) >= _amount, "Insufficient balance");
        require(IERC20(_token).allowance(msg.sender, address(this)) >= _amount, "Insufficient allowance");

        SafeERC20.safeTransferFrom(IERC20(_token), msg.sender, address(this), _amount);

        beneficiary2LockInfos[_token][_beneficiary].push(LockInfo({
            beneficiary: _beneficiary,
            amount: _amount,
            lockStartTime: _lockStartTime,
            lockEndTime: _lockEndTime,
            withdrawnAmount: 0
        }));

        emit LockedForBeneficiary(_token, _beneficiary, _amount, _lockStartTime, _lockEndTime);
    }
}