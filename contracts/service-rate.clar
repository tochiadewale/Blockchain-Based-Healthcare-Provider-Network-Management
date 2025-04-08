;; Service Rate Contract
;; Defines agreed payment terms for procedures

(define-data-var admin principal tx-sender)

;; Service code data structure
(define-map service-codes
  { code: (string-ascii 20) }
  {
    description: (string-ascii 255),
    category: (string-ascii 50)
  }
)

;; Service rates data structure (by network and provider)
(define-map service-rates
  { network-id: (string-ascii 64), provider-id: (string-ascii 64), code: (string-ascii 20) }
  {
    rate: uint,  ;; Rate in cents
    effective-date: uint,
    expiry-date: uint,
    negotiated-date: uint
  }
)

;; Default rates by network (when provider-specific rates aren't available)
(define-map default-network-rates
  { network-id: (string-ascii 64), code: (string-ascii 20) }
  {
    rate: uint,  ;; Rate in cents
    effective-date: uint,
    expiry-date: uint
  }
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-CODE-EXISTS u2)
(define-constant ERR-CODE-NOT-FOUND u3)
(define-constant ERR-RATE-EXISTS u4)
(define-constant ERR-RATE-NOT-FOUND u5)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Set a new admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (ok (var-set admin new-admin))
  )
)

;; Add a new service code
(define-public (add-service-code
    (code (string-ascii 20))
    (description (string-ascii 255))
    (category (string-ascii 50)))
  (let ((code-exists (map-get? service-codes { code: code })))
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-none code-exists) (err ERR-CODE-EXISTS))

    (ok (map-set service-codes
      { code: code }
      {
        description: description,
        category: category
      }
    ))
  )
)

;; Set default rate for a service in a network
(define-public (set-default-network-rate
    (network-id (string-ascii 64))
    (code (string-ascii 20))
    (rate uint)
    (effective-date uint)
    (expiry-date uint))
  (let ((code-exists (map-get? service-codes { code: code })))
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-some code-exists) (err ERR-CODE-NOT-FOUND))

    (ok (map-set default-network-rates
      { network-id: network-id, code: code }
      {
        rate: rate,
        effective-date: effective-date,
        expiry-date: expiry-date
      }
    ))
  )
)

;; Set provider-specific rate for a service in a network
(define-public (set-provider-rate
    (network-id (string-ascii 64))
    (provider-id (string-ascii 64))
    (code (string-ascii 20))
    (rate uint)
    (effective-date uint)
    (expiry-date uint))
  (let ((code-exists (map-get? service-codes { code: code })))
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-some code-exists) (err ERR-CODE-NOT-FOUND))

    (ok (map-set service-rates
      { network-id: network-id, provider-id: provider-id, code: code }
      {
        rate: rate,
        effective-date: effective-date,
        expiry-date: expiry-date,
        negotiated-date: block-height
      }
    ))
  )
)

;; Get service code information
(define-read-only (get-service-code (code (string-ascii 20)))
  (map-get? service-codes { code: code })
)

;; Get provider-specific rate
(define-read-only (get-provider-rate (network-id (string-ascii 64)) (provider-id (string-ascii 64)) (code (string-ascii 20)))
  (map-get? service-rates { network-id: network-id, provider-id: provider-id, code: code })
)

;; Get default network rate
(define-read-only (get-default-network-rate (network-id (string-ascii 64)) (code (string-ascii 20)))
  (map-get? default-network-rates { network-id: network-id, code: code })
)

;; Get effective rate for a provider (provider-specific or default)
(define-read-only (get-effective-rate (network-id (string-ascii 64)) (provider-id (string-ascii 64)) (code (string-ascii 20)))
  (let (
    (provider-rate (map-get? service-rates { network-id: network-id, provider-id: provider-id, code: code }))
    (network-rate (map-get? default-network-rates { network-id: network-id, code: code }))
    (current-block block-height)
  )
    (match provider-rate
      provider-rate-data (if (and
                              (>= current-block (get effective-date provider-rate-data))
                              (< current-block (get expiry-date provider-rate-data)))
                            (some (get rate provider-rate-data))
                            none)
      (match network-rate
        network-rate-data (if (and
                               (>= current-block (get effective-date network-rate-data))
                               (< current-block (get expiry-date network-rate-data)))
                             (some (get rate network-rate-data))
                             none)
        none
      )
    )
  )
)
