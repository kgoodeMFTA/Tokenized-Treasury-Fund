# Data Model — Tokenized Treasury Fund

## Conceptual model

```
┌─────────────────┐ owns ┌─────────────────┐ holds ┌─────────────────┐
│    Investor     │──────────►│   TTF Share     │◄──────────│      Fund       │
│  (wallet + KYC) │           │   (ERC-20)      │           │ (on-chain SPV)  │
└────────┬────────┘           └────────┬────────┘           └────────┬────────┘
         │                             │                             │
         │ verified by                 │ governed by                 │ invests in
         ▼                             ▼                             ▼
┌─────────────────┐           ┌─────────────────┐           ┌─────────────────┐
│ Transfer Agent  │           │ Compliance      │           │ U.S. Treasuries │
│ (Securitize-eq) │           │ Registry        │           │ + Repos + Cash  │
└─────────────────┘           └─────────────────┘           └─────────────────┘
                                       ▲
                                       │ updates daily
                                       │
                              ┌─────────────────┐
                              │     Oracle      │
                              │ (Chainlink PoR) │
                              └─────────────────┘
```

## Logical entities

### Investor

| Field | Type | Source | Notes |
|---|---|---|---|
| `walletAddress` | address | On-chain | Unique key |
| `legalName` | string | KYC packet | Off-chain only |
| `jurisdiction` | bytes2 (ISO-3166) | On-chain | e.g., `0x5553` = US |
| `investorType` | uint8 enum | On-chain | 1 retail / 2 accredited / 3 QP / 4 institutional |
| `kycExpiry` | uint64 | On-chain | Unix seconds |
| `sanctioned` | bool | On-chain | Set by OFAC delta job |
| `accreditationDocId` | string | Off-chain DMS | Form ID / CPA letter reference |
| `taxFormType` | enum | Off-chain | W-9, W-8BEN, W-8BEN-E |

### Share

| Field | Type | Source | Notes |
|---|---|---|---|
| `tokenId` | address | On-chain | Contract address (TTF) |
| `decimals` | uint8 | On-chain | 6, matches USDC |
| `totalSupply` | uint256 | On-chain | Derived |
| `navPerShare` | uint256 (1e8) | Oracle | Posted daily |
| `mgmtFeeBps` | uint16 | Admin | ≤ 500 (5%) |
| `minSubscription` | uint256 | Admin | Default 100,000e6 ($100K) |

### Fund

| Field | Type | Source | Notes |
|---|---|---|---|
| `fundId` | string | Off-chain | CIK / LEI |
| `domicile` | string | Off-chain | Delaware / BVI / Cayman / Luxembourg |
| `custodian` | string | Off-chain | BNY Mellon / State Street |
| `transferAgent` | address | On-chain | Has `TRANSFER_AGENT_ROLE` |
| `inceptionDate` | date | Off-chain | |
| `aumUsd` | numeric | Derived | `totalSupply * navPerShare` |

### Settlement leg (off-chain ↔ on-chain)

| Field | Type | Notes |
|---|---|---|
| `subscriptionId` | uuid | Created in TA system |
| `investorWallet` | address | |
| `stablecoinIn` | uint256 (USDC) | Posted by investor |
| `sharesOut` | uint256 | Minted by contract |
| `navStrike` | uint256 (1e8) | NAV at strike |
| `strikeBlock` | uint64 | On-chain confirmation block |
| `taApprovalId` | uuid | TA system reference |

## Key events (the auditor's view)

| Event | Emitted by | Fields | Purpose |
|---|---|---|---|
| `InvestorRegistered` | ComplianceRegistry | investor, jurisdiction, investorType, kycExpiry | Onboarding evidence |
| `InvestorUpdated` | ComplianceRegistry | investor, newType, newExpiry, sanctioned | KYC refresh / sanctions |
| `JurisdictionBlocked` | ComplianceRegistry | jurisdiction, blocked | Reg S enforcement |
| `Subscribed` | TTF | investor, stableIn, sharesOut, nav | Cap-table reconciliation |
| `Redeemed` | TTF | investor, sharesIn, stableOut, nav | Cap-table reconciliation |
| `NavUpdated` | TTF | oldNav, newNav, timestamp | NAV audit trail |
| `YieldDistributed` | TTF | sharesMinted, yieldBps, timestamp | Yield audit trail |
| `ForceTransfer` | TTF | from, to, amount, reason | Court order / recovery log |
| `Paused` / `Unpaused` | TTF (OZ Pausable) | account | Incident response |

## Cap-table reconciliation query

The recon job runs nightly: sum of on-chain `balanceOf` per whitelisted address must equal the transfer agent's system of record.

```
SELECT
  investor_wallet,
  on_chain_balance,
  ta_book_balance,
  (on_chain_balance - ta_book_balance) AS variance
FROM v_captable_recon
WHERE variance <> 0;
-- Expected: 0 rows. Any row pages oncall and freezes net new subscriptions.
```
