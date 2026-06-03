# Process Flows — Tokenized Treasury Fund

Diagrams use [Mermaid](https://mermaid.js.org/) so GitHub renders them inline.

## 1. Investor onboarding (cap-table entry)

```mermaid
sequenceDiagram
    participant I as Investor
    participant TA as Transfer Agent (Securitize-eq.)
    participant KYT as Chainalysis KYT
    participant CO as Compliance Officer
    participant CR as ComplianceRegistry (on-chain)

    I->>TA: Submit subscription packet + accreditation
    TA->>KYT: Wallet risk screen
    KYT-->>TA: Risk score
    TA->>CO: Review accreditation + sanctions
    CO->>CR: registerInvestor(wallet, jurisdiction, tier, kycExpiry)
    CR-->>CO: InvestorRegistered event
    CO-->>I: Welcome email + wallet whitelisted
```

## 2. Subscribe (mint)

```mermaid
sequenceDiagram
    participant I as Investor
    participant TA as Transfer Agent
    participant USDC as USDC Contract
    participant TTF as TTF Contract
    participant CUS as Custodian (BNY)

    I->>TA: Submit subscription order ($X)
    I->>USDC: Approve TA wallet for $X
    TA->>USDC: TransferFrom(I, custodian, $X)
    TA->>CUS: Off-chain settlement to T-bill purchase
    TA->>TTF: subscribe(I, $X)
    TTF->>TTF: Check whitelist, min sub, NAV freshness
    TTF->>I: Mint shares at NAV
    TTF-->>TA: Subscribed event
```

## 3. Daily NAV + yield distribution

```mermaid
sequenceDiagram
    participant FA as Fund Administrator
    participant ORC as Oracle (Chainlink PoR)
    participant TTF as TTF Contract
    participant DST as Distributor Wallet
    participant HLD as Investors

    FA->>FA: Mark-to-market T-bill portfolio (4pm ET strike)
    FA->>ORC: Sign NAV attestation + reserve report
    ORC->>TTF: updateNav(newNav)
    TTF-->>ORC: NavUpdated event
    ORC->>TTF: distributeYield(bps, distributorWallet)
    TTF->>DST: Mint pro-rata shares
    TTF-->>ORC: YieldDistributed event
    DST->>HLD: Push pro-rata new shares (off-chain orchestrated)
```

## 4. Redemption (burn)

```mermaid
sequenceDiagram
    participant I as Investor
    participant TA as Transfer Agent
    participant TTF as TTF Contract
    participant CUS as Custodian
    participant USDC as USDC Contract

    I->>TA: Submit redemption order (Y shares)
    TA->>TTF: redeem(I, Y)
    TTF->>TTF: Check NAV freshness, supply
    TTF->>TTF: Burn Y shares, compute USDC out at NAV
    TTF-->>TA: Redeemed event
    TA->>CUS: Sell T-bills (if needed)
    CUS->>USDC: Wire / mint USDC to TA
    TA->>USDC: Transfer USDC to investor
```

## 5. Incident response (pause)

```mermaid
sequenceDiagram
    participant ALERT as Monitoring
    participant ONCALL as Oncall Engineer
    participant RISK as Risk Committee
    participant TTF as TTF Contract

    ALERT->>ONCALL: NAV stale > 1h OR anomaly detected
    ONCALL->>RISK: Page risk committee
    RISK->>TTF: pause()
    TTF-->>RISK: Paused event
    Note over RISK,TTF: Subscriptions / redemptions / transfers blocked
    RISK->>RISK: Investigate, remediate, notify regulators if needed
    RISK->>TTF: unpause()
    TTF-->>RISK: Unpaused event
```

## 6. Sanctions hit (in-flight investor)

```mermaid
sequenceDiagram
    participant OFAC as OFAC SDN feed
    participant JOB as Daily delta job
    participant CO as Compliance Officer
    participant CR as ComplianceRegistry
    participant TA as Transfer Agent

    OFAC->>JOB: SDN delta (new sanctioned wallet)
    JOB->>CO: Auto-flag matched investors
    CO->>CR: updateInvestor(wallet, _, _, sanctioned=true)
    CR-->>CO: InvestorUpdated event
    Note over CR: All future transfers / subscriptions revert
    CO->>TA: File SAR if applicable
```
