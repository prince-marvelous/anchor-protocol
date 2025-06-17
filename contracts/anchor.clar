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