# User Stories & Acceptance Criteria

Format: **As a** \<role\>, **I want** \<capability\>, **so that** \<outcome\>. Acceptance criteria use Given/When/Then.

---

## Epic 1 — Investor onboarding

### US-1.1 Whitelist a qualified purchaser
**As a** Compliance Officer, **I want** to register a verified QP investor's wallet, **so that** they can subscribe to the fund.

**Acceptance**
- Given a verified QP investor with valid KYC,
- When I call `registerInvestor(wallet, "US", 3, expiryTs)`,
- Then `isWhitelisted(wallet)` returns `true`
- And an `InvestorRegistered` event is emitted with all four fields.

### US-1.2 Reject a non-QP investor for a QP-only fund
**As a** Compliance Officer, **I want** retail investors blocked from a QP-only fund.

**Acceptance**
- Given the fund's `requiredTier = 3`,
- When I register an investor with `investorType = 1` (retail),
- Then `isWhitelisted(wallet)` returns `false`
- And a subscription attempt reverts with `NotWhitelisted`.

### US-1.3 Block sanctioned jurisdiction
**As a** Compliance Officer, **I want** investors from blocked jurisdictions rejected even if otherwise eligible.

**Acceptance**
- Given `blockedJurisdictions["KP"] = true`,
- When an investor with jurisdiction `KP` is registered as institutional,
- Then `isWhitelisted` returns `false`.

---

## Epic 2 — Subscribe / Redeem

### US-2.1 Subscribe at current NAV
**As a** QP Investor, **I want** to subscribe to the fund and receive shares at the current NAV.

**Acceptance**
- Given NAV = 1.00 and min subscription = $100K,
- When the Transfer Agent calls `subscribe(investor, $500,000)`,
- Then the investor's balance increases by 500,000 TTF
- And a `Subscribed` event is emitted with the NAV used.

### US-2.2 Reject sub-minimum subscription
**Acceptance**
- Given min subscription = $100K,
- When TA calls `subscribe(investor, $50,000)`,
- Then the call reverts with `BelowMinimum(50000e6, 100000e6)`.

### US-2.3 Reject when NAV is stale
**Acceptance**
- Given the last NAV update was > 36 hours ago,
- When TA calls `subscribe(...)` or `redeem(...)`,
- Then the call reverts with `StaleNav`.

### US-2.4 Redeem at NAV
**As a** QP Investor, **I want** to redeem shares for stablecoin at current NAV.

**Acceptance**
- Given NAV = 1.01 and investor holds 100,000 TTF,
- When TA calls `redeem(investor, 100_000e6)`,
- Then 101,000 USDC equivalent is owed off-chain
- And the investor's TTF balance decreases by 100,000.

---

## Epic 3 — NAV & Yield

### US-3.1 Daily NAV update
**As a** Fund Administrator, **I want** the oracle to publish a fresh NAV daily.

**Acceptance**
- Given the oracle holds `ORACLE_ROLE`,
- When it calls `updateNav(newNav)`,
- Then `navPerShare` is updated and `NavUpdated` is emitted with old and new values.

### US-3.2 Yield distributed as new shares
**As a** Holder, **I want** my yield credited as additional shares rather than cash.

**Acceptance**
- Given total supply = 1,000,000 TTF and yield = 12 bps,
- When oracle calls `distributeYield(12, distributor)`,
- Then 1,200 new TTF are minted to the distributor
- And `YieldDistributed(1200, 12, ts)` is emitted.

---

## Epic 4 — Operational controls

### US-4.1 Force transfer for lost wallet
**As a** Transfer Agent, **I want** to move shares from a lost wallet to a new wallet on receipt of a notarised affidavit.

**Acceptance**
- Given both addresses are whitelisted,
- When TA calls `forceTransfer(lost, new, balance, "Affidavit #1042")`,
- Then balance moves and a `ForceTransfer` event is logged with the reason string.

### US-4.2 Emergency pause
**As a** Pauser, **I want** to halt all transfers during an incident.

**Acceptance**
- Given `PAUSER_ROLE`,
- When `pause()` is called,
- Then any subscribe / redeem / transfer reverts with `EnforcedPause`
- And `unpause()` restores normal operation.

### US-4.3 Sanctions in-flight block
**As a** Compliance Officer, **I want** an existing investor to be frozen the moment they are SDN-listed.

**Acceptance**
- Given investor A is whitelisted and holds 100,000 TTF,
- When `updateInvestor(A, _, _, sanctioned=true)` is called,
- Then any outgoing transfer from A reverts with `NotWhitelisted`.

---

## Traceability matrix

| Story | FR | Test |
|---|---|---|
| US-1.1 | FR-1, FR-2 | `Compliance gating → blocks subscription for non-whitelisted` |
| US-1.2 | FR-12 | `Compliance gating → blocks subscription for non-whitelisted` |
| US-1.3 | FR-9 | `Jurisdiction blocking → blocks investors from a sanctioned jurisdiction` |
| US-2.1 | FR-4, FR-5 | `Subscribe/Redeem flow → mints shares at NAV` |
| US-2.2 | FR-4 | `Compliance gating → blocks subscription below minimum` |
| US-2.3 | FR-5 | `Subscribe/Redeem flow → reverts when NAV is stale` |
| US-2.4 | FR-5 | `Subscribe/Redeem flow → redeems shares for stable amount at NAV` |
| US-3.1 | FR-5 | `Subscribe/Redeem flow (NAV update)` |
| US-3.2 | FR-6 | `Yield distribution → mints new shares proportional to supply` |
| US-4.1 | FR-7 | `Transfer agent overrides → force-transfers` |
| US-4.2 | FR-8 | `Pause → blocks subscribe when paused` |
| US-4.3 | FR-9 | `Compliance gating → blocks sanctioned investor` |
