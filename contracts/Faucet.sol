// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// imports
import { LasmOwnable } from "./imports/LasmOwnable.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Address } from "./libs/Address.sol";
import { IVestingClaimingContract } from "./interfaces/IVestingClaimingContract.sol";

/**
 * @title LasmFaucet
 * @dev A faucet contract that manages token distribution with cooldown periods to prevent abuse.
 * The contract allows users to claim tokens after a specified cooldown period. It includes functionalities
 * for updating payout amounts, cooldown periods, and supporting vesting and claiming mechanisms. The contract
 * also ensures that only certain chain IDs are allowed and handles vesting token claims.
 */

contract LasmFaucet is LasmOwnable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;

    // State variables
    IERC20 private _baseAsset;
    IVestingClaimingContract private _vestingClaimImplementation;

    uint256 public constant ZERO = 0;
    uint256 public constant MINUTE = 60;
    uint256 private immutable _MAX_CLAIM_THRESHOLD = 10000 ether;
    uint256 private immutable _MIN_COOLD_DOWN_THRESHOLD = MINUTE;
    uint256 private _payoutAmount = 200 ether;
    uint256 private _coolDownPeriod = MINUTE * MINUTE; 

    uint256 private _chainAllowed;
    uint256 private _totalDistributedTokens;
    mapping(address => uint256) private _lastClaimTime;

    // Events
    event TokensClaimed(address indexed _wallet, uint256 indexed _paymentAmount);
    event CoolDownPeriodUpdated(uint256 indexed _oldPeriod, uint256 indexed _newPeriod);
    event PayoutAmountUpdated(uint256 indexed _oldAmount, uint256 indexed _newAmount);    
    event VestingTokensClaimed(
        uint256 indexed _oldBalance, 
        uint256 indexed _currentBalance
    );
    event VestingClaimContractUpdated(
        address indexed oldVestingClaimImplementation, 
        address indexed _newVestingClaimImplementation
    );
    event ChainIdUpdated(uint256 indexed _oldChain, uint256 indexed _newChainId);
    event Withdrawal(address indexed _owner, address indexed _destination, uint256 indexed _amount);

    // Errors
    error CooldownNotPassed();
    error InvalidCooldownPeriod(uint256 _newCooldownPeriod);
    error AddressInteractionInvalid();
    error InvalidContractInteraction();
    error ChainInteractionInvalid();
    error VestingClaimImplementationInvalid();
    error NoVestingTokensClaimed();
    error DoesNotAcceptingEthers();
    error TokenAmountIsZero();
    error OutOfCapacity();
    error ChainIdUnchanged(uint256 _chainAllowed);
    error PayoutAmountUnchanged(uint256 _amount);
    error CoolDownPeriodUnchanged(uint256 _coolDownPeriod);
    error MainnetIDsAreNotAllowed(uint256 _newChainId);
    error FailedToSend();
    error NotPermitted();

    // Modifiers
    modifier validContract(address _address) {
        if(!_address.isContract()) {
            revert InvalidContractInteraction();
        }
        _;
    }

    modifier validAddress(address _address){
        if(_address == address(0)){
            revert AddressInteractionInvalid();
        }
        _;
    }

    /**
     * @dev Constructor sets the token address.
     * @param _token The address of the token contract.
     */
    constructor(address _token) {
        if (!_token.isContract()) revert InvalidContractInteraction();
        _baseAsset = IERC20(_token);
    }

    receive() external payable {
        revert DoesNotAcceptingEthers();
    }

    fallback() external payable {
        revert NotPermitted();
    } 

    /**
     * @dev Claims tokens for the sender if cooldown period has passed.
     */
    function claimTokens() external 
    nonReentrant() 
    whenNotPaused()
    {
        if (block.timestamp - _lastClaimTime[_msgSender()] < _coolDownPeriod) revert CooldownNotPassed();
        if (_baseAsset.balanceOf(address(this)) < _payoutAmount) revert OutOfCapacity();
        _claimTokens(_msgSender());
    }

    /**
     * @dev Updates the payout amount.
     * @param _newPayoutAmount The new payout amount.
     */
    function updatePayoutAmount(uint256 _newPayoutAmount) external onlyOwner() {
        if(_newPayoutAmount > _MAX_CLAIM_THRESHOLD) revert OutOfCapacity();
        if(_payoutAmount == _newPayoutAmount) revert PayoutAmountUnchanged(_payoutAmount);
        emit PayoutAmountUpdated(_payoutAmount, _newPayoutAmount);
        _payoutAmount = _newPayoutAmount;
    }

    /**
     * @dev Updates the cooldown period.
     * @param _newCoolDownPeriod The new cooldown period in seconds.
     */
    function updateCooldownPeriod(uint256 _newCoolDownPeriod) external onlyOwner() {
        if(_coolDownPeriod == _newCoolDownPeriod) revert CoolDownPeriodUnchanged(_coolDownPeriod);
        if(_newCoolDownPeriod < _MIN_COOLD_DOWN_THRESHOLD) revert OutOfCapacity();
        if(_newCoolDownPeriod < MINUTE) revert InvalidCooldownPeriod(_newCoolDownPeriod);
        emit CoolDownPeriodUpdated(_coolDownPeriod, _newCoolDownPeriod);
        _coolDownPeriod = _newCoolDownPeriod;
    }

    /**
     * @dev Returns the base asset address.
     */
    function getBaseAsset() external view returns(address){
        return address(_baseAsset);
    }

    /**
     * @dev Returns the vesting claim contract address.
     */
    function getVestingClaimContract() external view returns(address){
        return address(_vestingClaimImplementation);
    }

    /**
     * @dev Checks if the current chain ID is allowed.
     */
    function isChainAllowed() external view returns(bool) {
        if(_chainAllowed != _chainID() || _chainAllowed == ZERO) return false;

        return true;
    }

    /**
     * @dev Returns the total distributed tokens.
     */
    function getTotalDistributedTokens() external view returns (uint256) {
        return _totalDistributedTokens;
    }

    /**
     * @dev Returns the cooldown period.
     */
    function getCoolDownPeriod() external view returns (uint256) {
        return _coolDownPeriod;
    }

    /**
     * @dev Returns the payout amount.
     */
    function getPayoutAmount() external view returns (uint256) {
        return _payoutAmount;
    }

    /**
     * @dev Returns the current chain ID.
     */
    function getChainId() external view returns (uint256) {
        return _chainID();
    }

    /**
     * @dev Internal function to get the current chain ID.
     */
    function _chainID() private view returns (uint256) {
        uint256 chainID;
        assembly {
            chainID := chainid()
        }
        return chainID;
    }

    /**
     * @dev Internal function to claim tokens for a wallet.
     * @param _wallet The wallet address to claim tokens for.
     */
    function _claimTokens(address _wallet) internal {
        if(_chainAllowed != _chainID()) revert ChainInteractionInvalid();
        if(address(_vestingClaimImplementation) == address(0)) revert VestingClaimImplementationInvalid();
        _baseAsset.safeTransfer(_wallet, _payoutAmount);

        _totalDistributedTokens += _payoutAmount;
        _lastClaimTime[_wallet] = block.timestamp;

        emit TokensClaimed(_wallet, _payoutAmount);
    }

    /**
     * @dev Updates the vesting claim contract.
     * @param _newVestingClaimImplementation The new vesting claim contract address.
     */
    function updateVestingClaimContract(address _newVestingClaimImplementation) 
    external 
    validContract(_newVestingClaimImplementation)
    onlyOwner() 
    whenNotPaused()
    {
        address oldVestingClaimImplementation = address(_vestingClaimImplementation);
        _vestingClaimImplementation = IVestingClaimingContract(_newVestingClaimImplementation);
        emit VestingClaimContractUpdated(oldVestingClaimImplementation, _newVestingClaimImplementation);
    }

    /**
     * @dev Updates the allowed chain ID.
     * @param _newChainId The new chain ID.
     */
    function updateChainID(uint256 _newChainId) external onlyOwner(){
        if (_newChainId == _chainAllowed) revert ChainIdUnchanged(_chainAllowed);
        if ( 
            _newChainId == ZERO || // Zero Id not allowed
            _newChainId == 1 || // Ethereum Mainnet
            _newChainId == 56 || // Binance Smart Chain (BSC) Mainnet
            _newChainId == 137 || // Polygon (MATIC) Mainnet
            _newChainId == 43114 || // Avalanche C-Chain Mainnet
            _newChainId == 250 || // Fantom Opera Mainnet
            _newChainId == 42161 || // Arbitrum One Mainnet
            _newChainId == 10 || // Optimism Mainnet
            _newChainId == 25 || // Cronos Mainnet
            _newChainId == 128 || // Heco (Huobi ECO Chain) Mainnet
            _newChainId == 1284 || // Moonbeam (Polkadot on Ethereum) Mainnet
            _newChainId == 8217 || // Klaytn Mainnet
            _newChainId == 1666600000 || // Harmony Mainnet
            _newChainId == 42220) { // Celo Mainnet
            revert MainnetIDsAreNotAllowed(_newChainId);
        }
        emit ChainIdUpdated(_chainAllowed, _newChainId);
        _chainAllowed = _newChainId;
    }

    /**
     * @dev Claims vested tokens for a template.
     * @param templateName The name of the template.
     */
    function claimVestedTokens(string calldata templateName) 
    external 
    nonReentrant() 
    onlyOwner() 
    whenNotPaused()
    {
        if(address(_vestingClaimImplementation)==address(0)) revert AddressInteractionInvalid();
        uint256 oldBalance = IERC20(_baseAsset).balanceOf(address(this));
        _vestingClaimImplementation.claimTokensForBeneficiary(templateName);
        uint256 currentBalance = IERC20(_baseAsset).balanceOf(address(this));

        if(oldBalance == currentBalance) revert NoVestingTokensClaimed();

        emit VestingTokensClaimed(oldBalance, currentBalance);
    }

    /**
     * @dev Rescues tokens from the contract.
     * @param _tokenAddress The address of the token contract.
     * @param _to The address to send the tokens to.
     * @param _amount The amount of tokens to rescue.
     */
    function rescueTokens(address _tokenAddress, address _to, uint256 _amount) 
    external 
    validContract(_tokenAddress)
    validAddress(_to) 
    onlyOwner() 
    {
        if(_amount == 0) revert TokenAmountIsZero();
        SafeERC20.safeTransfer(IERC20(_tokenAddress), _to, _amount);
        emit Withdrawal(_tokenAddress, _to, _amount);
    }

    /**
     * @dev Pauses the contract.
     */
    function pause() external onlyOwner() {
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     */
    function unpause() external onlyOwner(){
        _unpause();
    }
}
