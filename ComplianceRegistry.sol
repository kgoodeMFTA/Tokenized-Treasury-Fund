// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IComplianceRegistry} from "./interfaces/IComplianceRegistry.sol";

/**
 * @title ComplianceRegistry
 * @notice On-chain whitelist managed by an off-chain KYC / transfer-agent process.
 *         Mirrors the ERC-3643 (T-REX) identity-and-eligibility pattern used by Tokeny,
 *         but kept intentionally minimal so a business analyst can read every line.
 *
 *         Each investor record captures:
 *           - jurisdiction (ISO-3166-1 alpha-2 stored as 2-byte tag)
 *           - investorType  (0 = none, 1 = retail, 2 = accredited, 3 = qualified purchaser, 4 = institutional)
 *           - kycExpiry     (unix seconds; lapsed KYC disables transfers)
 *           - sanctioned    (true blocks all activity)
 *
 *         Eligibility rule (configurable per token, demoed here):
 *           whitelisted = !sanctioned && kycExpiry > now && investorType >= requiredTier
 */
contract ComplianceRegistry is AccessControl, IComplianceRegistry {
    bytes32 public constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");

    struct InvestorRecord {
        bytes2 jurisdiction;
        uint8 investorType;
        uint64 kycExpiry;
        bool sanctioned;
        bool exists;
    }

    mapping(address => InvestorRecord) public records;

    /// @notice Minimum investor tier required to hold the fund (e.g., 3 = QP only).
    uint8 public requiredTier;

    /// @notice Blocked jurisdictions (e.g., 0x5553 = "US" if Reg S only).
    mapping(bytes2 => bool) public blockedJurisdictions;

    event InvestorRegistered(address indexed investor, bytes2 jurisdiction, uint8 investorType, uint64 kycExpiry);
    event InvestorUpdated(address indexed investor, uint8 newType, uint64 newExpiry, bool sanctioned);
    event RequiredTierChanged(uint8 oldTier, uint8 newTier);
    event JurisdictionBlocked(bytes2 jurisdiction, bool blocked);

    constructor(address admin, uint8 requiredTier_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(COMPLIANCE_OFFICER_ROLE, admin);
        requiredTier = requiredTier_;
    }

    function registerInvestor(
        address investor,
        bytes2 jurisdiction,
        uint8 investorType,
        uint64 kycExpiry
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        require(investor != address(0), "Registry: zero addr");
        require(kycExpiry > block.timestamp, "Registry: expiry in past");
        records[investor] = InvestorRecord({
            jurisdiction: jurisdiction,
            investorType: investorType,
            kycExpiry: kycExpiry,
            sanctioned: false,
            exists: true
        });
        emit InvestorRegistered(investor, jurisdiction, investorType, kycExpiry);
    }

    function updateInvestor(
        address investor,
        uint8 newType,
        uint64 newExpiry,
        bool sanctioned
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        InvestorRecord storage r = records[investor];
        require(r.exists, "Registry: unknown investor");
        r.investorType = newType;
        r.kycExpiry = newExpiry;
        r.sanctioned = sanctioned;
        emit InvestorUpdated(investor, newType, newExpiry, sanctioned);
    }

    function setRequiredTier(uint8 newTier) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit RequiredTierChanged(requiredTier, newTier);
        requiredTier = newTier;
    }

    function setBlockedJurisdiction(bytes2 jurisdiction, bool blocked)
        external
        onlyRole(COMPLIANCE_OFFICER_ROLE)
    {
        blockedJurisdictions[jurisdiction] = blocked;
        emit JurisdictionBlocked(jurisdiction, blocked);
    }

    function isWhitelisted(address account) external view override returns (bool) {
        InvestorRecord memory r = records[account];
        if (!r.exists) return false;
        if (r.sanctioned) return false;
        if (r.kycExpiry <= block.timestamp) return false;
        if (blockedJurisdictions[r.jurisdiction]) return false;
        if (r.investorType < requiredTier) return false;
        return true;
    }
}
