// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IComplianceRegistry} from "./interfaces/IComplianceRegistry.sol";

/**
 * @title TokenizedTreasuryFund (TTF)
 * @notice ERC-20 share token for a tokenized money market fund holding short-duration
 *         U.S. Treasury bills, repos, and overnight cash. Models the BUIDL / OUSG /
 *         BENJI design pattern: an ERC-20 wrapper gated by an off-chain transfer
 *         agent and on-chain compliance whitelist.
 *
 * @dev    This is a portfolio / educational implementation. Not audited.
 *         Demonstrates the core mechanics a Tokenization Business Analyst is
 *         expected to understand and document:
 *           - Permissioned transfers (Reg D 506(c) / Reg S whitelisting)
 *           - NAV-per-share accounting with daily rebasing
 *           - Yield distribution via additional-share minting (the BUIDL model)
 *           - Subscribe / redeem flow with stablecoin settlement
 *           - Emergency pause + transfer-agent overrides
 *
 *         Roles
 *           DEFAULT_ADMIN_ROLE  - protocol governance (multisig in production)
 *           TRANSFER_AGENT_ROLE - Securitize-equivalent: KYC, cap table, force transfers
 *           ORACLE_ROLE         - NAV / yield oracle (Chainlink Proof of Reserve)
 *           PAUSER_ROLE         - emergency circuit breaker
 */
contract TokenizedTreasuryFund is ERC20, AccessControl, Pausable {
    bytes32 public constant TRANSFER_AGENT_ROLE = keccak256("TRANSFER_AGENT_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Compliance registry: who is allowed to hold the token.
    IComplianceRegistry public complianceRegistry;

    /// @notice Settlement stablecoin (e.g., USDC) used for subscribe / redeem.
    address public immutable settlementToken;

    /// @notice Net Asset Value per share, scaled by 1e8 (e.g., 1.00000000 = 1e8).
    uint256 public navPerShare;

    /// @notice Minimum subscription in settlement-token units (e.g., $100,000).
    uint256 public minSubscription;

    /// @notice Last NAV update timestamp (used to detect stale oracle data).
    uint256 public lastNavUpdate;

    /// @notice Maximum NAV staleness before subscribe / redeem auto-pause.
    uint256 public constant MAX_NAV_STALENESS = 36 hours;

    /// @notice Annualised management fee in basis points (e.g., 15 = 0.15%).
    uint16 public mgmtFeeBps;

    event NavUpdated(uint256 oldNav, uint256 newNav, uint256 timestamp);
    event Subscribed(address indexed investor, uint256 stableIn, uint256 sharesOut, uint256 nav);
    event Redeemed(address indexed investor, uint256 sharesIn, uint256 stableOut, uint256 nav);
    event YieldDistributed(uint256 sharesMinted, uint256 yieldBps, uint256 timestamp);
    event ForceTransfer(address indexed from, address indexed to, uint256 amount, string reason);
    event ComplianceRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);

    error NotWhitelisted(address account);
    error BelowMinimum(uint256 provided, uint256 required);
    error StaleNav(uint256 lastUpdate, uint256 maxAge);
    error ZeroAmount();

    constructor(
        string memory name_,
        string memory symbol_,
        address admin,
        address transferAgent,
        address oracle,
        address pauser,
        address complianceRegistry_,
        address settlementToken_,
        uint256 minSubscription_,
        uint16 mgmtFeeBps_
    ) ERC20(name_, symbol_) {
        require(admin != address(0), "TTF: admin zero");
        require(complianceRegistry_ != address(0), "TTF: registry zero");
        require(settlementToken_ != address(0), "TTF: stable zero");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(TRANSFER_AGENT_ROLE, transferAgent);
        _grantRole(ORACLE_ROLE, oracle);
        _grantRole(PAUSER_ROLE, pauser);

        complianceRegistry = IComplianceRegistry(complianceRegistry_);
        settlementToken = settlementToken_;
        minSubscription = minSubscription_;
        mgmtFeeBps = mgmtFeeBps_;
        navPerShare = 1e8; // start at 1.00 per share
        lastNavUpdate = block.timestamp;
    }

    // ---------------------------------------------------------------------
    // COMPLIANCE: every state-changing token movement goes through this hook
    // ---------------------------------------------------------------------

    /// @dev Enforces whitelist on mint / burn / transfer.
    function _update(address from, address to, uint256 value) internal virtual override whenNotPaused {
        // Allow burns (to == 0) and mints (from == 0); other paths must be whitelisted.
        if (from != address(0) && !complianceRegistry.isWhitelisted(from)) {
            revert NotWhitelisted(from);
        }
        if (to != address(0) && !complianceRegistry.isWhitelisted(to)) {
            revert NotWhitelisted(to);
        }
        super._update(from, to, value);
    }

    // ---------------------------------------------------------------------
    // ORACLE: NAV + yield distribution (the "daily dividend in new shares" pattern)
    // ---------------------------------------------------------------------

    /**
     * @notice Update NAV per share. Called daily by the oracle after T-bill mark-to-market.
     * @param newNav New NAV scaled by 1e8.
     */
    function updateNav(uint256 newNav) external onlyRole(ORACLE_ROLE) {
        require(newNav > 0, "TTF: nav zero");
        uint256 old = navPerShare;
        navPerShare = newNav;
        lastNavUpdate = block.timestamp;
        emit NavUpdated(old, newNav, block.timestamp);
    }

    /**
     * @notice Distribute yield by minting additional shares pro-rata to all holders.
     *         Mirrors the BUIDL "dividend in tokens" mechanism: instead of paying cash,
     *         each wallet's balance grows by the yield-bps amount.
     *
     * @dev    Production version would iterate a cap-table snapshot or use a rebasing model.
     *         For demo simplicity, this version mints to a distributor that pushes pro-rata.
     * @param yieldBps Yield amount in basis points (e.g., 12 = 0.12% for one day).
     * @param distributor Address that will receive the freshly minted shares and dispatch them.
     */
    function distributeYield(uint16 yieldBps, address distributor)
        external
        onlyRole(ORACLE_ROLE)
        whenNotPaused
    {
        require(yieldBps > 0 && yieldBps < 1000, "TTF: yield out of range");
        require(complianceRegistry.isWhitelisted(distributor), "TTF: distributor not whitelisted");

        uint256 supply = totalSupply();
        if (supply == 0) return;

        uint256 sharesToMint = (supply * yieldBps) / 10_000;
        _mint(distributor, sharesToMint);
        emit YieldDistributed(sharesToMint, yieldBps, block.timestamp);
    }

    // ---------------------------------------------------------------------
    // SUBSCRIBE / REDEEM
    // ---------------------------------------------------------------------

    /**
     * @notice Investor subscribes by sending stablecoin and receiving shares at current NAV.
     *         In production this is processed by the transfer agent off-chain and settled here.
     */
    function subscribe(address investor, uint256 stableAmount)
        external
        onlyRole(TRANSFER_AGENT_ROLE)
        whenNotPaused
        returns (uint256 sharesOut)
    {
        if (stableAmount == 0) revert ZeroAmount();
        if (stableAmount < minSubscription) revert BelowMinimum(stableAmount, minSubscription);
        if (block.timestamp - lastNavUpdate > MAX_NAV_STALENESS) {
            revert StaleNav(lastNavUpdate, MAX_NAV_STALENESS);
        }
        if (!complianceRegistry.isWhitelisted(investor)) revert NotWhitelisted(investor);

        // shares = stable * 1e8 / nav   (both stable + shares assumed 6-decimal here for clarity)
        sharesOut = (stableAmount * 1e8) / navPerShare;
        _mint(investor, sharesOut);
        emit Subscribed(investor, stableAmount, sharesOut, navPerShare);
    }

    /**
     * @notice Investor redeems shares back to stablecoin at current NAV.
     *         Settlement of the stablecoin transfer is handled by the transfer agent.
     */
    function redeem(address investor, uint256 shareAmount)
        external
        onlyRole(TRANSFER_AGENT_ROLE)
        whenNotPaused
        returns (uint256 stableOut)
    {
        if (shareAmount == 0) revert ZeroAmount();
        if (block.timestamp - lastNavUpdate > MAX_NAV_STALENESS) {
            revert StaleNav(lastNavUpdate, MAX_NAV_STALENESS);
        }

        stableOut = (shareAmount * navPerShare) / 1e8;
        _burn(investor, shareAmount);
        emit Redeemed(investor, shareAmount, stableOut, navPerShare);
    }

    // ---------------------------------------------------------------------
    // TRANSFER AGENT OVERRIDES (recovery, court order, lost-wallet, AML hold)
    // ---------------------------------------------------------------------

    function forceTransfer(address from, address to, uint256 amount, string calldata reason)
        external
        onlyRole(TRANSFER_AGENT_ROLE)
    {
        require(complianceRegistry.isWhitelisted(to), "TTF: target not whitelisted");
        _transfer(from, to, amount);
        emit ForceTransfer(from, to, amount, reason);
    }

    // ---------------------------------------------------------------------
    // ADMIN
    // ---------------------------------------------------------------------

    function setComplianceRegistry(address newRegistry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newRegistry != address(0), "TTF: zero");
        emit ComplianceRegistryUpdated(address(complianceRegistry), newRegistry);
        complianceRegistry = IComplianceRegistry(newRegistry);
    }

    function setMinSubscription(uint256 newMin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        minSubscription = newMin;
    }

    function setMgmtFeeBps(uint16 newFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newFee <= 500, "TTF: fee too high"); // <= 5%
        mgmtFeeBps = newFee;
    }

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }

    function decimals() public pure override returns (uint8) { return 6; }
}
