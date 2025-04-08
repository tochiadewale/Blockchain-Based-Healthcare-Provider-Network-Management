;; Network Participation Contract
;; Manages inclusion in insurance networks

(define-data-var admin principal tx-sender)

;; Insurance network data structure
(define-map networks
  { network-id: (string-ascii 64) }
  {
    name: (string-ascii 100),
    description: (string-ascii 255),
    active: bool
  }
)

;; Network participation data structure
(define-map network-providers
  { network-id: (string-ascii 64), provider-id: (string-ascii 64) }
  {
    join-date: uint,
    status: (string-ascii 20),  ;; "active", "suspended", "terminated"
    tier: (string-ascii 20)     ;; "preferred", "standard", etc.
  }
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-NETWORK-EXISTS u2)
(define-constant ERR-NETWORK-NOT-FOUND u3)
(define-constant ERR-PROVIDER-EXISTS u4)
(define-constant ERR-PROVIDER-NOT-FOUND u5)

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

;; Create a new insurance network
(define-public (create-network
    (network-id (string-ascii 64))
    (name (string-ascii 100))
    (description (string-ascii 255)))
  (let ((network-exists (map-get? networks { network-id: network-id })))
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-none network-exists) (err ERR-NETWORK-EXISTS))

    (ok (map-set networks
      { network-id: network-id }
      {
        name: name,
        description: description,
        active: true
      }
    ))
  )
)

;; Add a provider to a network
(define-public (add-provider-to-network
    (network-id (string-ascii 64))
    (provider-id (string-ascii 64))
    (tier (string-ascii 20)))
  (let (
    (network-exists (map-get? networks { network-id: network-id }))
    (provider-exists (map-get? network-providers { network-id: network-id, provider-id: provider-id }))
  )
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-some network-exists) (err ERR-NETWORK-NOT-FOUND))
    (asserts! (is-none provider-exists) (err ERR-PROVIDER-EXISTS))

    (ok (map-set network-providers
      { network-id: network-id, provider-id: provider-id }
      {
        join-date: block-height,
        status: "active",
        tier: tier
      }
    ))
  )
)

;; Update provider status in a network
(define-public (update-provider-status
    (network-id (string-ascii 64))
    (provider-id (string-ascii 64))
    (status (string-ascii 20)))
  (let ((provider-data (map-get? network-providers { network-id: network-id, provider-id: provider-id })))
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-some provider-data) (err ERR-PROVIDER-NOT-FOUND))

    (ok (map-set network-providers
      { network-id: network-id, provider-id: provider-id }
      (merge (unwrap-panic provider-data) { status: status })
    ))
  )
)

;; Update provider tier in a network
(define-public (update-provider-tier
    (network-id (string-ascii 64))
    (provider-id (string-ascii 64))
    (tier (string-ascii 20)))
  (let ((provider-data (map-get? network-providers { network-id: network-id, provider-id: provider-id })))
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-some provider-data) (err ERR-PROVIDER-NOT-FOUND))

    (ok (map-set network-providers
      { network-id: network-id, provider-id: provider-id }
      (merge (unwrap-panic provider-data) { tier: tier })
    ))
  )
)

;; Get network information
(define-read-only (get-network (network-id (string-ascii 64)))
  (map-get? networks { network-id: network-id })
)

;; Get provider's network participation information
(define-read-only (get-provider-network-status (network-id (string-ascii 64)) (provider-id (string-ascii 64)))
  (map-get? network-providers { network-id: network-id, provider-id: provider-id })
)

;; Check if provider is active in a network
(define-read-only (is-provider-active-in-network (network-id (string-ascii 64)) (provider-id (string-ascii 64)))
  (match (map-get? network-providers { network-id: network-id, provider-id: provider-id })
    provider-data (is-eq (get status provider-data) "active")
    false
  )
)
