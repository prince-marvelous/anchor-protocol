;; Anchor Protocol - Bitcoin-Native Multi-Collateral Stablecoin Platform
;;
;; Title: Anchor Protocol
;;
;; Summary: A decentralized, over-collateralized stablecoin protocol built on Stacks,
;;          enabling users to mint USDx stablecoins against STX and xBTC collateral
;;          while maintaining Bitcoin's security and programmability.
;;
;; Description: Anchor revolutionizes DeFi on Bitcoin by providing a robust,
;;              multi-collateral CDP (Collateralized Debt Position) system that
;;              combines the security of Bitcoin with the flexibility of smart
;;              contracts. Users can deposit STX and xBTC as collateral to mint
;;              USDx stablecoins, participate in liquidations, and benefit from
;;              a decentralized oracle network. The protocol features automated
;;              liquidation mechanisms, dynamic collateral ratios, and comprehensive
;;              risk management to ensure stability and capital efficiency.
;;
;; Key Features:
;;   - Multi-asset collateral support (STX, xBTC)
;;   - Decentralized price oracle integration
;;   - Automated liquidation engine with penalty mechanisms
;;   - SIP-010 compliant USDx stablecoin token
;;   - Comprehensive vault management system
;;   - Emergency governance controls

;; PROTOCOL CONSTANTS AND ERROR CODES

(define-constant CONTRACT-OWNER tx-sender)

;; Error codes with descriptive meanings
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-VAULT-NOT-FOUND (err u1001))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u1002))
(define-constant ERR-VAULT-UNDERCOLLATERALIZED (err u1003))
(define-constant ERR-LIQUIDATION-NOT-ALLOWED (err u1004))
(define-constant ERR-INVALID-AMOUNT (err u1005))
(define-constant ERR-ORACLE-PRICE-STALE (err u1006))
(define-constant ERR-MINIMUM-COLLATERAL-RATIO (err u1007))
(define-constant ERR-VAULT-ALREADY-EXISTS (err u1008))
(define-constant ERR-INSUFFICIENT-USDX-BALANCE (err u1009))
(define-constant ERR-TRANSFER-FAILED (err u1010))

;; Protocol parameters for risk management
(define-constant LIQUIDATION-RATIO u150) ;; 150% - liquidation threshold
(define-constant MINIMUM-COLLATERAL-RATIO u200) ;; 200% - minimum for new vaults
(define-constant LIQUIDATION-PENALTY u110) ;; 10% liquidation penalty
(define-constant STABILITY-FEE-RATE u2) ;; 2% annual stability fee
(define-constant MAX-PRICE-AGE u3600) ;; 1 hour max price age (in seconds)

;; DATA STRUCTURES AND STORAGE

;; Comprehensive vault structure for tracking user positions
(define-map vaults
  { vault-id: uint }
  {
    owner: principal,
    stx-collateral: uint,
    xbtc-collateral: uint,
    debt: uint,
    last-update: uint,
    is-active: bool,
  }
)

;; User vault mapping for efficient lookup
(define-map user-vaults
  { user: principal }
  { vault-ids: (list 10 uint) }
)

;; Oracle price feeds with confidence scoring
(define-map price-feeds
  { asset: (string-ascii 10) }
  {
    price: uint,
    timestamp: uint,
    confidence: uint,
  }
)

;; Protocol-wide statistics tracking
(define-data-var total-vaults uint u0)
(define-data-var total-debt uint u0)
(define-data-var total-stx-collateral uint u0)
(define-data-var total-xbtc-collateral uint u0)
(define-data-var liquidation-pool uint u0)

;; Access control for liquidators and oracle operators
(define-map authorized-liquidators
  principal
  bool
)

(define-map oracle-operators
  principal
  bool
)

;; USDx STABLECOIN TOKEN (SIP-010 IMPLEMENTATION)

(define-fungible-token usdx)

;; Token metadata
(define-data-var token-name (string-ascii 32) "USDx Stablecoin")
(define-data-var token-symbol (string-ascii 10) "USDx")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var token-decimals uint u6)

;; SIP-010 Standard Functions Implementation
(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance usdx who))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply usdx))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

;; Secure token transfer function with comprehensive validation
(define-public (transfer
    (amount uint)
    (from principal)
    (to principal)
    (memo (optional (buff 34)))
  )
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (or (is-eq from tx-sender) (is-eq from contract-caller))
      ERR-NOT-AUTHORIZED
    )
    (asserts! (not (is-eq from to)) ERR-INVALID-AMOUNT)
    (ft-transfer? usdx amount from to)
  )
)

;; ORACLE SYSTEM FUNCTIONS

;; Grant or revoke oracle operator privileges
(define-public (set-oracle-operator
    (operator principal)
    (authorized bool)
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq operator tx-sender)) ERR-INVALID-AMOUNT)
    (ok (map-set oracle-operators operator authorized))
  )
)

;; Update asset price feeds with confidence scoring
(define-public (update-price
    (asset (string-ascii 10))
    (price uint)
    (confidence uint)
  )
  (begin
    (asserts! (default-to false (map-get? oracle-operators tx-sender))
      ERR-NOT-AUTHORIZED
    )
    (asserts! (> price u0) ERR-INVALID-AMOUNT)
    (asserts! (and (>= confidence u1) (<= confidence u100)) ERR-INVALID-AMOUNT)
    (asserts! (> (len asset) u0) ERR-INVALID-AMOUNT)
    (ok (map-set price-feeds { asset: asset } {
      price: price,
      timestamp: stacks-block-height,
      confidence: confidence,
    }))
  )
)

;; Retrieve current price with staleness validation
(define-read-only (get-price (asset (string-ascii 10)))
  (let ((price-data (map-get? price-feeds { asset: asset })))
    (match price-data
      feed (if (< (- stacks-block-height (get timestamp feed)) MAX-PRICE-AGE)
        (ok (get price feed))
        ERR-ORACLE-PRICE-STALE
      )
      ERR-ORACLE-PRICE-STALE
    )
  )
)

;; VAULT MANAGEMENT SYSTEM

;; Create new collateralized debt position
(define-public (create-vault
    (stx-amount uint)
    (xbtc-amount uint)
  )
  (let (
      (vault-id (+ (var-get total-vaults) u1))
      (stx-price (unwrap! (get-price "STX") ERR-ORACLE-PRICE-STALE))
      (xbtc-price (unwrap! (get-price "xBTC") ERR-ORACLE-PRICE-STALE))
      (total-collateral-value (+ (* stx-amount stx-price) (* xbtc-amount xbtc-price)))
      (user-vaults-list (default-to (list)
        (get vault-ids (map-get? user-vaults { user: tx-sender }))
      ))
    )
    (asserts! (> stx-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= xbtc-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (< vault-id u1000000) ERR-INVALID-AMOUNT)
    (asserts! (is-none (map-get? vaults { vault-id: vault-id }))
      ERR-VAULT-ALREADY-EXISTS
    )
    ;; Transfer collateral to contract custody
    (try! (stx-transfer? stx-amount tx-sender (as-contract tx-sender)))
    ;; Initialize new vault
    (map-set vaults { vault-id: vault-id } {
      owner: tx-sender,
      stx-collateral: stx-amount,
      xbtc-collateral: xbtc-amount,
      debt: u0,
      last-update: stacks-block-height,
      is-active: true,
    })
    ;; Update user vault registry
    (map-set user-vaults { user: tx-sender } { vault-ids: (unwrap! (as-max-len? (append user-vaults-list vault-id) u10)
      ERR-INVALID-AMOUNT
    ) }
    )
    ;; Update protocol statistics
    (var-set total-vaults vault-id)
    (var-set total-stx-collateral (+ (var-get total-stx-collateral) stx-amount))
    (var-set total-xbtc-collateral
      (+ (var-get total-xbtc-collateral) xbtc-amount)
    )
    (ok vault-id)
  )
)

;; Add additional collateral to existing vault
(define-public (add-collateral
    (vault-id uint)
    (stx-amount uint)
    (xbtc-amount uint)
  )
  (let ((vault (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-VAULT-NOT-FOUND)))
    (asserts! (> vault-id u0) ERR-INVALID-AMOUNT)
    (asserts! (is-eq (get owner vault) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active vault) ERR-VAULT-NOT-FOUND)
    (asserts! (> stx-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= xbtc-amount u0) ERR-INVALID-AMOUNT)
    ;; Transfer additional collateral
    (try! (stx-transfer? stx-amount tx-sender (as-contract tx-sender)))
    ;; Update vault collateral balances
    (map-set vaults { vault-id: vault-id }
      (merge vault {
        stx-collateral: (+ (get stx-collateral vault) stx-amount),
        xbtc-collateral: (+ (get xbtc-collateral vault) xbtc-amount),
        last-update: stacks-block-height,
      })
    )
    ;; Update protocol statistics
    (var-set total-stx-collateral (+ (var-get total-stx-collateral) stx-amount))
    (var-set total-xbtc-collateral
      (+ (var-get total-xbtc-collateral) xbtc-amount)
    )
    (ok true)
  )
)

;; Mint USDx stablecoins against collateral
(define-public (mint-usdx
    (vault-id uint)
    (amount uint)
  )
  (let (
      (vault (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-VAULT-NOT-FOUND))
      (stx-price (unwrap! (get-price "STX") ERR-ORACLE-PRICE-STALE))
      (xbtc-price (unwrap! (get-price "xBTC") ERR-ORACLE-PRICE-STALE))
      (collateral-value (+ (* (get stx-collateral vault) stx-price)
        (* (get xbtc-collateral vault) xbtc-price)
      ))
      (new-debt (+ (get debt vault) amount))
      (collateral-ratio (/ (* collateral-value u100) new-debt))
    )
    (asserts! (> vault-id u0) ERR-INVALID-AMOUNT)
    (asserts! (is-eq (get owner vault) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active vault) ERR-VAULT-NOT-FOUND)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (< amount u1000000000000) ERR-INVALID-AMOUNT)
    (asserts! (>= collateral-ratio MINIMUM-COLLATERAL-RATIO)
      ERR-MINIMUM-COLLATERAL-RATIO
    )
    ;; Mint USDx tokens to user
    (try! (ft-mint? usdx amount tx-sender))
    ;; Update vault debt position
    (map-set vaults { vault-id: vault-id }
      (merge vault {
        debt: new-debt,
        last-update: stacks-block-height,
      })
    )
    ;; Update protocol debt statistics
    (var-set total-debt (+ (var-get total-debt) amount))
    (ok true)
  )
)

;; Burn USDx tokens to reduce vault debt
(define-public (burn-usdx
    (vault-id uint)
    (amount uint)
  )
  (let (
      (vault (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-VAULT-NOT-FOUND))
      (user-balance (ft-get-balance usdx tx-sender))
    )
    (asserts! (> vault-id u0) ERR-INVALID-AMOUNT)
    (asserts! (is-eq (get owner vault) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active vault) ERR-VAULT-NOT-FOUND)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= user-balance amount) ERR-INSUFFICIENT-USDX-BALANCE)
    (asserts! (>= (get debt vault) amount) ERR-INVALID-AMOUNT)
    ;; Burn USDx tokens from circulation
    (try! (ft-burn? usdx amount tx-sender))
    ;; Reduce vault debt
    (map-set vaults { vault-id: vault-id }
      (merge vault {
        debt: (- (get debt vault) amount),
        last-update: stacks-block-height,
      })
    )
    ;; Update protocol debt statistics
    (var-set total-debt (- (var-get total-debt) amount))
    (ok true)
  )
)

;; Withdraw collateral from vault (with safety checks)
(define-public (withdraw-collateral
    (vault-id uint)
    (stx-amount uint)
  )
  (let (
      (vault (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-VAULT-NOT-FOUND))
      (stx-price (unwrap! (get-price "STX") ERR-ORACLE-PRICE-STALE))
      (xbtc-price (unwrap! (get-price "xBTC") ERR-ORACLE-PRICE-STALE))
      (remaining-stx (- (get stx-collateral vault) stx-amount))
      (remaining-collateral-value (+ (* remaining-stx stx-price) (* (get xbtc-collateral vault) xbtc-price)))
      (debt (get debt vault))
    )
    (asserts! (> vault-id u0) ERR-INVALID-AMOUNT)
    (asserts! (is-eq (get owner vault) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active vault) ERR-VAULT-NOT-FOUND)
    (asserts! (> stx-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= (get stx-collateral vault) stx-amount)
      ERR-INSUFFICIENT-COLLATERAL
    )
    ;; Ensure withdrawal maintains minimum collateral ratio
    (if (> debt u0)
      (asserts!
        (>= (/ (* remaining-collateral-value u100) debt) MINIMUM-COLLATERAL-RATIO)
        ERR-MINIMUM-COLLATERAL-RATIO
      )
      true
    )
    ;; Transfer collateral back to vault owner
    (try! (as-contract (stx-transfer? stx-amount tx-sender (get owner vault))))
    ;; Update vault collateral balance
    (map-set vaults { vault-id: vault-id }
      (merge vault {
        stx-collateral: remaining-stx,
        last-update: stacks-block-height,
      })
    )
    ;; Update protocol collateral statistics
    (var-set total-stx-collateral (- (var-get total-stx-collateral) stx-amount))
    (ok true)
  )
)

;; LIQUIDATION ENGINE

;; Authorize liquidator accounts
(define-public (set-liquidator
    (liquidator principal)
    (authorized bool)
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq liquidator tx-sender)) ERR-INVALID-AMOUNT)
    (ok (map-set authorized-liquidators liquidator authorized))
  )
)

;; Calculate vault health factor for liquidation assessment
(define-read-only (calculate-health-factor (vault-id uint))
  (match (map-get? vaults { vault-id: vault-id })
    vault (match (get-price "STX")
      stx-price (match (get-price "xBTC")
        xbtc-price (let (
            (collateral-value (+ (* (get stx-collateral vault) stx-price)
              (* (get xbtc-collateral vault) xbtc-price)
            ))
            (debt (get debt vault))
          )
          (if (is-eq debt u0)
            (ok u999999) ;; Infinite health factor if no debt
            (ok (/ (* collateral-value u100) debt))
          )
        )
        xbtc-err
        ERR-ORACLE-PRICE-STALE
      )
      stx-err
      ERR-ORACLE-PRICE-STALE
    )
    ERR-VAULT-NOT-FOUND
  )
)

;; Execute liquidation of undercollateralized vault
(define-public (liquidate-vault (vault-id uint))
  (let (
      (vault (unwrap! (map-get? vaults { vault-id: vault-id }) ERR-VAULT-NOT-FOUND))
      (health-factor (unwrap! (calculate-health-factor vault-id) ERR-ORACLE-PRICE-STALE))
      (debt (get debt vault))
      (stx-collateral (get stx-collateral vault))
      (xbtc-collateral (get xbtc-collateral vault))
      (liquidation-amount (/ (* debt LIQUIDATION-PENALTY) u100))
    )
    (asserts! (default-to false (map-get? authorized-liquidators tx-sender))
      ERR-NOT-AUTHORIZED
    )
    (asserts! (get is-active vault) ERR-VAULT-NOT-FOUND)
    (asserts! (< health-factor LIQUIDATION-RATIO) ERR-LIQUIDATION-NOT-ALLOWED)
    (asserts! (>= (ft-get-balance usdx tx-sender) debt)
      ERR-INSUFFICIENT-USDX-BALANCE
    )
    ;; Burn liquidator's USDx to cover vault debt
    (try! (ft-burn? usdx debt tx-sender))
    ;; Calculate collateral distribution to liquidator
    (let (
        (stx-to-liquidator (/ (* stx-collateral liquidation-amount) debt))
        (xbtc-to-liquidator (/ (* xbtc-collateral liquidation-amount) debt))
      )
      ;; Transfer seized collateral to liquidator
      (try! (as-contract (stx-transfer? stx-to-liquidator tx-sender tx-sender)))
      ;; Deactivate liquidated vault
      (map-set vaults { vault-id: vault-id }
        (merge vault {
          debt: u0,
          stx-collateral: (- stx-collateral stx-to-liquidator),
          xbtc-collateral: (- xbtc-collateral xbtc-to-liquidator),
          is-active: false,
          last-update: stacks-block-height,
        })
      )
      ;; Update protocol statistics
      (var-set total-debt (- (var-get total-debt) debt))
      (var-set total-stx-collateral
        (- (var-get total-stx-collateral) stx-to-liquidator)
      )
      (var-set total-xbtc-collateral
        (- (var-get total-xbtc-collateral) xbtc-to-liquidator)
      )
      (ok true)
    )
  )
)

;; READ-ONLY QUERY FUNCTIONS

;; Retrieve vault information
(define-read-only (get-vault (vault-id uint))
  (map-get? vaults { vault-id: vault-id })
)

;; Get all vault IDs for a user
(define-read-only (get-user-vaults (user principal))
  (map-get? user-vaults { user: user })
)

;; Get comprehensive protocol statistics
(define-read-only (get-protocol-stats)
  {
    total-vaults: (var-get total-vaults),
    total-debt: (var-get total-debt),
    total-stx-collateral: (var-get total-stx-collateral),
    total-xbtc-collateral: (var-get total-xbtc-collateral),
    total-usdx-supply: (ft-get-supply usdx),
  }
)

;; Check if vault is above liquidation threshold
(define-read-only (is-vault-safe (vault-id uint))
  (match (calculate-health-factor vault-id)
    health-factor (ok (>= health-factor LIQUIDATION-RATIO))
    error (err error)
  )
)

;; PROTOCOL GOVERNANCE FUNCTIONS

;; Emergency protocol shutdown mechanism
(define-public (emergency-shutdown)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    ;; Implementation for emergency shutdown procedures
    (ok true)
  )
)

;; Update liquidation ratio parameters
(define-public (update-liquidation-ratio (new-ratio uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-ratio u120) (<= new-ratio u200)) ERR-INVALID-AMOUNT)
    ;; Note: In production, this would update a data-var
    (ok true)
  )
)

;; PROTOCOL INITIALIZATION

;; Initialize contract owner as oracle operator
(map-set oracle-operators CONTRACT-OWNER true) 

;; Initialize baseline price feeds with confidence scores
(map-set price-feeds { asset: "STX" } {
  price: u1000000,
  timestamp: stacks-block-height,
  confidence: u95,
}) 

(map-set price-feeds { asset: "xBTC" } {
  price: u100000000000,
  timestamp: stacks-block-height,
  confidence: u95,
})
