// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IUnit} from "./interfaces/IUnit.sol";

/**
 * @title Rig
 * @author heesho
 * @notice A mining rig contract that implements a Dutch auction mechanism for mining Unit tokens.
 *         Users compete to become the current rig owner by paying a decaying price. The previous
 *         rig owner receives minted Unit tokens proportional to their holding time, plus a share
 *         of the payment from the next miner.
 * @dev Implements a halving schedule for the emission rate (UPS - units per second).
 */
contract Rig is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*----------  CONSTANTS  --------------------------------------------*/

    uint256 public constant PREVIOUS_MINER_FEE = 8_000; // 80% to previous miner
    uint256 public constant HOPPER_FEE = 1_500; // 15% to hopper
    uint256 public constant TEAM_FEE = 250; // 2.5% to team
    uint256 public constant DEV_FEE = 250; // 2.5% to dev
    uint256 public constant DIVISOR = 10_000; // fee divisor (basis points)
    uint256 public constant PRECISION = 1e18; // precision for multiplier calcs

    // Hardcoded parameters
    uint256 public constant INITIAL_UPS = 4 ether; // starting units per second
    uint256 public constant TAIL_UPS = 0.01 ether; // minimum units per second after halvings
    uint256 public constant HALVING_PERIOD = 30 days; // time between emission halvings
    uint256 public constant EPOCH_PERIOD = 1 hours; // duration of each Dutch auction
    uint256 public constant PRICE_MULTIPLIER = 2e18; // multiplier for next epoch's starting price
    uint256 public constant MIN_INIT_PRICE = 1 ether; // minimum starting price per epoch
    uint256 public constant ABS_MAX_INIT_PRICE = type(uint192).max; // chosen so that epochInitPrice * priceMultiplier does not exceed uint256

    /*----------  IMMUTABLES  -------------------------------------------*/

    uint256 public immutable startTime; // contract deployment timestamp

    address public immutable unit; // Unit token address
    address public immutable quote; // payment token (e.g., WETH)

    /*----------  STATE  ------------------------------------------------*/

    uint256 public epochId; // current epoch id
    uint256 public epochInitPrice; // current epoch starting price
    uint256 public epochStartTime; // current epoch start timestamp
    uint256 public epochUps; // current epoch units per second

    address public epochMiner; // current epoch miner
    address public hopper; // hopper address
    address public team; // team address
    address public dev; // dev address

    string public epochUri; // current epoch miner uri
    string public uri; // rig uri

    /*----------  ERRORS  -----------------------------------------------*/

    error Rig__InvalidMiner();
    error Rig__Expired();
    error Rig__EpochIdMismatch();
    error Rig__MaxPriceExceeded();
    error Rig__InvalidUnit();
    error Rig__InvalidQuote();
    error Rig__InvalidHopper();
    error Rig__InvalidTeam();
    error Rig__InvalidDev();
    error Rig__NotDev();

    /*----------  EVENTS  -----------------------------------------------*/

    event Rig__Mined(address indexed sender, address indexed miner, uint256 price, string uri);
    event Rig__Minted(address indexed miner, uint256 amount);
    event Rig__PreviousMinerFee(address indexed miner, uint256 amount);
    event Rig__HopperFee(address indexed hopper, uint256 amount);
    event Rig__TeamFee(address indexed team, uint256 amount);
    event Rig__DevFee(address indexed dev, uint256 amount);
    event Rig__HopperSet(address indexed hopper);
    event Rig__TeamSet(address indexed team);
    event Rig__DevSet(address indexed dev);
    event Rig__UriSet(string uri);

    /*----------  CONSTRUCTOR  ------------------------------------------*/

    /**
     * @notice Deploys a new Rig contract.
     * @param _unit Unit token address (deployed separately)
     * @param _quote Payment token address (e.g., WETH)
     * @param _hopper Hopper address for fee collection
     * @param _team Team address for fee collection
     * @param _dev Dev address for fee collection
     * @param _uri Metadata URI for the rig
     */
    constructor(
        address _unit,
        address _quote,
        address _hopper,
        address _team,
        address _dev,
        string memory _uri
    ) {
        if (_unit == address(0)) revert Rig__InvalidUnit();
        if (_quote == address(0)) revert Rig__InvalidQuote();
        if (_hopper == address(0)) revert Rig__InvalidHopper();
        if (_team == address(0)) revert Rig__InvalidTeam();
        if (_dev == address(0)) revert Rig__InvalidDev();

        unit = _unit;
        quote = _quote;
        hopper = _hopper;
        team = _team;
        dev = _dev;
        uri = _uri;
        startTime = block.timestamp;

        epochInitPrice = MIN_INIT_PRICE;
        epochStartTime = block.timestamp;
        epochMiner = _team;
        epochUps = INITIAL_UPS;
    }

    /*----------  EXTERNAL FUNCTIONS  -----------------------------------*/

    /**
     * @notice Mine the rig by paying the current Dutch auction price.
     * @dev Transfers payment to fee recipients, mints Unit tokens to previous holder,
     *      and sets the caller as the new miner.
     * @param miner Address to set as new miner (receives future minted tokens)
     * @param _epochId Expected epoch ID (reverts if mismatched for frontrun protection)
     * @param deadline Transaction deadline timestamp
     * @param maxPrice Maximum price willing to pay (slippage protection)
     * @param _epochUri Metadata URI for this mining action
     * @return price Actual price paid
     */
    function mine(address miner, uint256 _epochId, uint256 deadline, uint256 maxPrice, string calldata _epochUri)
        external
        nonReentrant
        returns (uint256 price)
    {
        if (miner == address(0)) revert Rig__InvalidMiner();
        if (block.timestamp > deadline) revert Rig__Expired();
        if (_epochId != epochId) revert Rig__EpochIdMismatch();

        price = getPrice();
        if (price > maxPrice) revert Rig__MaxPriceExceeded();

        // Distribute payment to fee recipients
        if (price > 0) {
            uint256 previousMinerAmount = price * PREVIOUS_MINER_FEE / DIVISOR;
            uint256 hopperAmount = price * HOPPER_FEE / DIVISOR;
            uint256 teamAmount = price * TEAM_FEE / DIVISOR;
            uint256 devAmount = price - previousMinerAmount - hopperAmount - teamAmount;

            // Pull payment once, then distribute
            IERC20(quote).safeTransferFrom(msg.sender, address(this), price);

            IERC20(quote).safeTransfer(epochMiner, previousMinerAmount);
            emit Rig__PreviousMinerFee(epochMiner, previousMinerAmount);

            IERC20(quote).safeTransfer(hopper, hopperAmount);
            emit Rig__HopperFee(hopper, hopperAmount);

            IERC20(quote).safeTransfer(team, teamAmount);
            emit Rig__TeamFee(team, teamAmount);

            IERC20(quote).safeTransfer(dev, devAmount);
            emit Rig__DevFee(dev, devAmount);
        }

        // Calculate next epoch's starting price
        uint256 newInitPrice = price * PRICE_MULTIPLIER / PRECISION;
        if (newInitPrice > ABS_MAX_INIT_PRICE) {
            newInitPrice = ABS_MAX_INIT_PRICE;
        } else if (newInitPrice < MIN_INIT_PRICE) {
            newInitPrice = MIN_INIT_PRICE;
        }

        // Mint tokens to previous rig holder based on holding time
        uint256 mineTime = block.timestamp - epochStartTime;
        uint256 minedAmount = mineTime * epochUps;

        IUnit(unit).mint(epochMiner, minedAmount);
        emit Rig__Minted(epochMiner, minedAmount);

        // Update state for new epoch
        unchecked {
            epochId++;
        }
        epochInitPrice = newInitPrice;
        epochStartTime = block.timestamp;
        epochMiner = miner;
        epochUps = _getUpsFromTime(block.timestamp);
        epochUri = _epochUri;

        emit Rig__Mined(msg.sender, miner, price, _epochUri);

        return price;
    }

    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/

    /**
     * @notice Update the hopper address for fee collection.
     * @param _hopper New hopper address
     */
    function setHopper(address _hopper) external onlyOwner {
        if (_hopper == address(0)) revert Rig__InvalidHopper();
        hopper = _hopper;
        emit Rig__HopperSet(_hopper);
    }

    /**
     * @notice Update the team address for fee collection.
     * @param _team New team address
     */
    function setTeam(address _team) external onlyOwner {
        if (_team == address(0)) revert Rig__InvalidTeam();
        team = _team;
        emit Rig__TeamSet(_team);
    }

    /**
     * @notice Update the dev address for fee collection.
     * @dev Only callable by the current dev address.
     * @param _dev New dev address
     */
    function setDev(address _dev) external {
        if (msg.sender != dev) revert Rig__NotDev();
        if (_dev == address(0)) revert Rig__InvalidDev();
        dev = _dev;
        emit Rig__DevSet(_dev);
    }

    /**
     * @notice Update the metadata URI.
     * @dev Used to set metadata like the unit logo image.
     * @param _uri New metadata URI
     */
    function setUri(string calldata _uri) external onlyOwner {
        uri = _uri;
        emit Rig__UriSet(_uri);
    }

    /*----------  VIEW FUNCTIONS  ---------------------------------------*/

    /**
     * @notice Get the current Dutch auction price.
     * @return Current price (linearly decays from epochInitPrice to 0 over EPOCH_PERIOD)
     */
    function getPrice() public view returns (uint256) {
        uint256 timePassed = block.timestamp - epochStartTime;
        if (timePassed > EPOCH_PERIOD) return 0;
        return epochInitPrice - epochInitPrice * timePassed / EPOCH_PERIOD;
    }

    /**
     * @notice Get the current units-per-second emission rate.
     * @return Current UPS after applying halving schedule
     */
    function getUps() external view returns (uint256) {
        return _getUpsFromTime(block.timestamp);
    }

    /*----------  INTERNAL FUNCTIONS  -----------------------------------*/

    /**
     * @notice Calculate UPS at a given timestamp based on halving schedule.
     * @param time Timestamp to calculate UPS for
     * @return ups Units per second at the given time
     */
    function _getUpsFromTime(uint256 time) internal view returns (uint256 ups) {
        uint256 halvings = time <= startTime ? 0 : (time - startTime) / HALVING_PERIOD;
        ups = INITIAL_UPS >> halvings;
        if (ups < TAIL_UPS) ups = TAIL_UPS;
        return ups;
    }
}
