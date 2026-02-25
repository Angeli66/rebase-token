;; rebase-token.clar
;; ------------------------------------------------------------
;; Elastic Supply (Rebase) Token for Stacks (STX)
;; SIP-010 Compatible Structure
;;
;; - Uses internal "base units"
;; - Visible balances scale via global multiplier
;; - Admin can increase or decrease supply via rebase()
;; ------------------------------------------------------------

(define-constant ERR_NOT_ADMIN (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_INVALID_PRINCIPAL (err u103))

;; -------------------------
;; Token Metadata
;; -------------------------
(define-constant TOKEN_NAME "Rebase Token")
(define-constant TOKEN_SYMBOL "RBT")
(define-constant TOKEN_DECIMALS u6)

;; -------------------------
;; Admin
;; -------------------------
(define-constant admin tx-sender)

;; -------------------------
;; Supply Accounting
;; -------------------------

;; Total base supply (internal accounting)
(define-data-var total-base-supply uint u0)

;; Global multiplier (scaled by 1e6 for precision)
(define-data-var multiplier uint u1000000)

;; Base balances (not scaled)
(define-map base-balances
  { account: principal }
  { amount: uint })

;; -------------------------
;; Events
;; -------------------------

(define-private (ev-transfer (from principal) (to principal) (amount uint))
  (print { event: "transfer", from: from, to: to, amount: amount }))

(define-private (ev-rebase (new-multiplier uint))
  (print { event: "rebase", new_multiplier: new-multiplier }))

;; -------------------------
;; Internal Helpers
;; -------------------------

(define-private (to-visible (base uint))
  ;; base * multiplier / 1e6
  (/ (* base (var-get multiplier)) u1000000))

(define-private (to-base (visible uint))
  ;; visible * 1e6 / multiplier
  (/ (* visible u1000000) (var-get multiplier)))

;; -------------------------
;; Public Functions
;; -------------------------

;; Mint (admin only)
(define-public (mint (to principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender admin) ERR_NOT_ADMIN)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (not (is-eq to (as-contract tx-sender))) ERR_INVALID_PRINCIPAL)

    (let (
          (base-amt (to-base amount))
          (current (default-to u0 (get amount (map-get? base-balances { account: to }))))
         )
      (map-set base-balances { account: to } { amount: (+ current base-amt) })
      (var-set total-base-supply (+ (var-get total-base-supply) base-amt))
      (ok true)
    )
  )
)

;; Transfer
(define-public (transfer (to principal) (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (not (is-eq to (as-contract tx-sender))) ERR_INVALID_PRINCIPAL)

    (let (
          (base-amt (to-base amount))
          (sender-bal (default-to u0 (get amount (map-get? base-balances { account: tx-sender }))))
         )

      (asserts! (>= sender-bal base-amt) ERR_INSUFFICIENT_BALANCE)

      ;; subtract sender
      (map-set base-balances
        { account: tx-sender }
        { amount: (- sender-bal base-amt) })

      ;; add receiver
      (let ((recv-bal (default-to u0 (get amount (map-get? base-balances { account: to }))))
           )
        (map-set base-balances
          { account: to }
          { amount: (+ recv-bal base-amt) }))

      (ok (ev-transfer tx-sender to amount))
    )
  )
)

;; Rebase (adjust supply by basis points)
;; Example:
;; +500 = +5%
;; -300 = -3%
(define-public (rebase (basis-points int))
  (begin
    (asserts! (is-eq tx-sender admin) ERR_NOT_ADMIN)

    ;; multiplier = multiplier * (10000 + bp) / 10000
    (let (
          (current (var-get multiplier))
          (new-mult
            (if (>= basis-points 0)
                (/ (* current (+ u10000 (to-uint basis-points))) u10000)
                (/ (* current (- u10000 (to-uint (- 0 basis-points)))) u10000)
            )
          )
         )
      (var-set multiplier new-mult)
      (ev-rebase new-mult)
      (ok new-mult)
    )
  )
)

;; -------------------------
;; Read-Only Functions
;; -------------------------

(define-read-only (get-name) (ok TOKEN_NAME))
(define-read-only (get-symbol) (ok TOKEN_SYMBOL))
(define-read-only (get-decimals) (ok TOKEN_DECIMALS))

(define-read-only (get-total-supply)
  (ok (to-visible (var-get total-base-supply))))

(define-read-only (get-balance (who principal))
  (let ((base (default-to u0 (get amount (map-get? base-balances { account: who })))))
    (ok (to-visible base))
  )
)

(define-read-only (get-multiplier)
  (ok (var-get multiplier)))

(define-read-only (get-admin)
  (ok admin))