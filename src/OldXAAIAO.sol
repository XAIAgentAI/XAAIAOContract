// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title XAAIAO
 * @dev This contract allows users to deposit the  TokenIn  during  deposit period.
 * After the distribution period begins, users can claim their proportional ERC20 rewards based on the amount of TokenIn they deposited.
 */
/// @custom:oz-upgrades-from OldXAAIAO
contract OldXAAIAO is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    // Address of the  ERC20 token contract
    IERC20 public tokenIn;
    IERC20 public rewardToken;

    // Total rewards to be distributed: 20 billion (in wei)
    uint256  public totalReward;

    // Deposit period:
    uint256 public depositPeriod;

    // Start and end timestamps for the deposit period
    uint256 public startTime;
    uint256 public endTime;

    // Total amount of tokenIn deposited in the contract
    uint256 public totalDepositedTokenIn;

    // Mapping to store the amount of DBC deposited by each user
    mapping(address => uint256) public userDeposits;

    // Mapping to track whether a user has claimed their  rewards
    mapping(address => bool) public hasClaimed;

    // Events
    event Deposit(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event DepositedTokenClaimed(uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // Disable initializers to prevent unauthorized initialization of the implementation contract
        _disableInitializers();
    }

    function initialize(address owner, address _tokenIn, address _rewardToken, uint256 _startTime, uint256 depositPeriodDays, uint256 _totalReward) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(owner);

        tokenIn = IERC20(_tokenIn);
        rewardToken = IERC20(_rewardToken);
        startTime = _startTime;
        depositPeriod = depositPeriodDays * 1 days;
        endTime = _startTime + depositPeriod;
        totalReward = _totalReward;
    }

    /**
     * @dev Modifier to ensure the function is only called during the deposit period.
     */
    modifier onlyDuringDepositPeriod() {
        require(isStarted(), "Distribution not started");
        require(
            block.timestamp >= startTime && block.timestamp <= endTime,
            "Deposit period over"
        );
        _;
    }

    /**
     * @dev Modifier to ensure the function is only called after the distribution period begins.
     */
    modifier onlyAfterDistribution() {
        require(isStarted(), "Distribution not started");
        require(block.timestamp > endTime, "Distribution not end");
        _;
    }

    function start() external onlyOwner {
        require(isStarted() == false, "Distribution already started");
        startTime = block.timestamp;
        endTime = block.timestamp + depositPeriod;
    }

    function setRewardToken(address _rewardToken) external onlyOwner {
        rewardToken = IERC20(_rewardToken);
    }

    /**
     * @dev Allows users to claim their rewards after the distribution period begins.
     * The amount of rewards is proportional to the amount of DBC they deposited.
     * Emits a `RewardsClaimed` event.
     */
    function claimRewards() external onlyAfterDistribution {
        require(!hasClaimed[msg.sender], "Rewards already claimed");
        require(userDeposits[msg.sender] > 0, "No deposit found");

        uint256 userReward = (userDeposits[msg.sender] * totalReward) /
                    totalDepositedTokenIn;

        // Mark rewards as claimed
        hasClaimed[msg.sender] = true;

        // Transfer rewards to the user
        require(
            rewardToken.transfer(msg.sender, userReward),
            "rewards transfer failed"
        );

        emit RewardsClaimed(msg.sender, userReward);
    }

    /**
     * @dev Returns the remaining time in the deposit period.
     * @return Remaining time in seconds, or 0 if the deposit period has ended.
     */
    function getRemainingTime() external view returns (uint256) {
        if (isStarted() == false) {
            return 0;
        }
        if (block.timestamp > endTime) {
            return 0;
        }
        return endTime - block.timestamp;
    }

    /**
       * @dev Allows the owner (admin) to claim any remaining TokenIn from the contract.
     * This function can only be called after the deposit period ends.
     */
    function claimDepositedToken() external onlyAfterDistribution onlyOwner {
        uint256 dbcBalance = address(this).balance;
        require(dbcBalance > 0, "No DBC to claim");

        // Transfer all remaining DBC to the owner
        (bool success, ) = msg.sender.call{value: dbcBalance}("");
        require(success, "DBC transfer failed");
        emit DepositedTokenClaimed(dbcBalance);
    }

    /**
     * @dev Ensures that only the contract owner can authorize upgrades to the implementation contract.
     * @param newImplementation Address of the new implementation contract.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}


    function isStarted() public view returns(bool)  {
        return block.timestamp >= startTime;
    }

    function getReward() external view returns(uint256) {
        uint256 userReward = (userDeposits[msg.sender] * totalReward) /
                    totalDepositedTokenIn;
        return userReward;
    }
}
