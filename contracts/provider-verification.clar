;; Provider Verification Contract
;; Validates credentials of medical professionals

(define-data-var admin principal tx-sender)

;; Provider data structure
(define-map providers
  { provider-id: (string-ascii 64) }
  {
    principal: principal,
    name: (string-ascii 100),
    specialty: (string-ascii 100),
    license-number: (string-ascii 50),
    license-expiry: uint,
    is-verified: bool
  }
)

;; Credentials data structure
(define-map credentials
  { provider-id: (string-ascii 64), credential-id: (string-ascii 64) }
  {
    credential-type: (string-ascii 100),
    issuer: (string-ascii 100),
    issue-date: uint,
    expiry-date: uint,
    hash: (buff 32)  ;; Hash of the credential document
  }
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-PROVIDER-EXISTS u2)
(define-constant ERR-PROVIDER-NOT-FOUND u3)
(define-constant ERR-CREDENTIAL-EXISTS u4)
(define-constant ERR-CREDENTIAL-NOT-FOUND u5)

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

;; Register a new provider
(define-public (register-provider
    (provider-id (string-ascii 64))
    (name (string-ascii 100))
    (specialty (string-ascii 100))
    (license-number (string-ascii 50))
    (license-expiry uint))
  (let ((provider-exists (map-get? providers { provider-id: provider-id })))
    (asserts! (or (is-admin) (is-eq tx-sender (get principal (default-to { principal: tx-sender } provider-exists)))) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-none provider-exists) (err ERR-PROVIDER-EXISTS))

    (ok (map-set providers
      { provider-id: provider-id }
      {
        principal: tx-sender,
        name: name,
        specialty: specialty,
        license-number: license-number,
        license-expiry: license-expiry,
        is-verified: false
      }
    ))
  )
)

;; Verify a provider
(define-public (verify-provider (provider-id (string-ascii 64)))
  (let ((provider-data (map-get? providers { provider-id: provider-id })))
    (asserts! (is-admin) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-some provider-data) (err ERR-PROVIDER-NOT-FOUND))

    (ok (map-set providers
      { provider-id: provider-id }
      (merge (unwrap-panic provider-data) { is-verified: true })
    ))
  )
)

;; Add a credential to a provider
(define-public (add-credential
    (provider-id (string-ascii 64))
    (credential-id (string-ascii 64))
    (credential-type (string-ascii 100))
    (issuer (string-ascii 100))
    (issue-date uint)
    (expiry-date uint)
    (document-hash (buff 32)))
  (let (
    (provider-data (map-get? providers { provider-id: provider-id }))
    (credential-exists (map-get? credentials { provider-id: provider-id, credential-id: credential-id }))
  )
    (asserts! (is-some provider-data) (err ERR-PROVIDER-NOT-FOUND))
    (asserts! (or (is-admin) (is-eq tx-sender (get principal (unwrap-panic provider-data)))) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-none credential-exists) (err ERR-CREDENTIAL-EXISTS))

    (ok (map-set credentials
      { provider-id: provider-id, credential-id: credential-id }
      {
        credential-type: credential-type,
        issuer: issuer,
        issue-date: issue-date,
        expiry-date: expiry-date,
        hash: document-hash
      }
    ))
  )
)

;; Get provider information
(define-read-only (get-provider (provider-id (string-ascii 64)))
  (map-get? providers { provider-id: provider-id })
)

;; Get credential information
(define-read-only (get-credential (provider-id (string-ascii 64)) (credential-id (string-ascii 64)))
  (map-get? credentials { provider-id: provider-id, credential-id: credential-id })
)

;; Check if provider is verified
(define-read-only (is-provider-verified (provider-id (string-ascii 64)))
  (match (map-get? providers { provider-id: provider-id })
    provider-data (get is-verified provider-data)
    false
  )
)
