;; ------------------------------------------------------------
;; nontransferable-vote.clar
;; Soulbound (non-transferable) voting rights
;; ------------------------------------------------------------

(define-constant ERR-NOT-ADMIN u100)
(define-constant ERR-NOT-VOTER u101)
(define-constant ERR-ALREADY-VOTED u102)
(define-constant ERR-PROPOSAL-NOT-FOUND u103)
(define-constant ERR-VOTING-CLOSED u104)
(define-constant ERR-ALREADY-ASSIGNED u105)

;; ------------------------------------------------------------
;; DAO state
;; ------------------------------------------------------------

(define-data-var admin (optional principal) none)
(define-data-var proposal-count uint u0)

;; ------------------------------------------------------------
;; Soulbound voting rights
;; ------------------------------------------------------------

(define-map voters
  { user: principal }
  { active: bool }
)

(define-read-only (is-voter (u principal))
  (is-some (map-get? voters { user: u }))
)

;; ------------------------------------------------------------
;; Proposals
;; ------------------------------------------------------------

(define-map proposals
  { id: uint }
  {
    creator: principal,
    description: (string-ascii 200),
    start: uint,
    end: uint,
    yes: uint,
    no: uint,
    open: bool
  }
)

;; Track individual votes
(define-map votes
  { id: uint, voter: principal }
  { voted: bool }
)

;; ------------------------------------------------------------
;; Initialize
;; ------------------------------------------------------------

(define-public (initialize (dao-admin principal))
  (let ((admin-val (unwrap-panic (ok dao-admin))))
    (if (is-some (var-get admin))
        (err ERR-NOT-ADMIN)
        (begin
          (var-set admin (some admin-val))
          ;; admin is first voter
          (map-set voters { user: admin-val } { active: true })
          (ok (var-get admin))
        )
    )
  )
)

;; ------------------------------------------------------------
;; Admin: assign / revoke voting rights
;; ------------------------------------------------------------

(define-public (assign-voter (user principal))
  (if (is-none (var-get admin))
      (err ERR-NOT-ADMIN)
      (let ((a (unwrap! (var-get admin) (err ERR-NOT-ADMIN))))
        (if (not (is-eq a tx-sender))
            (err ERR-NOT-ADMIN)
            (if (is-some (map-get? voters { user: user }))
                (err ERR-ALREADY-ASSIGNED)
                (begin
                  (map-set voters { user: user } { active: true })
                  (ok true)
                )
            )
        )
      )
  )
)

(define-public (revoke-voter (user principal))
  (if (is-none (var-get admin))
      (err ERR-NOT-ADMIN)
      (let ((a (unwrap! (var-get admin) (err ERR-NOT-ADMIN))))
        (if (not (is-eq a tx-sender))
            (err ERR-NOT-ADMIN)
            (begin
              (map-delete voters { user: user })
              (ok true)
            )
        )
      )
  )
)

;; ------------------------------------------------------------
;; Create proposal (voters only)
;; ------------------------------------------------------------

(define-public (create-proposal (description (string-ascii 200)) (duration uint))
  (let ((sender tx-sender))
    (if (not (is-voter sender))
        (err ERR-NOT-VOTER)
        (let ((id (+ (var-get proposal-count) u1)))
          (begin
            (var-set proposal-count id)
            (map-set proposals
              { id: id }
              {
                creator: sender,
                description: description,
                start: u0,
                end: (+ u0 duration),
                yes: u0,
                no: u0,
                open: true
              }
            )
            (ok id)
          )
        )
    )
  )
)

;; ------------------------------------------------------------
;; Vote (1 address = 1 vote)
;; ------------------------------------------------------------

(define-public (vote (proposal-id uint) (support bool))
  (let ((sender tx-sender))
    (if (not (is-voter sender))
        (err ERR-NOT-VOTER)
        (match (map-get? proposals { id: proposal-id })
          some-p
            (if (or (not (get open some-p)) (> u0 (get end some-p)))
                (err ERR-VOTING-CLOSED)
                (if (is-some (map-get? votes { id: proposal-id, voter: sender }))
                    (err ERR-ALREADY-VOTED)
                    (begin
                      (map-set votes { id: proposal-id, voter: sender } { voted: true })
                      (if support
                          (map-set proposals { id: proposal-id }
                            {
                              creator: (get creator some-p),
                              description: (get description some-p),
                              start: (get start some-p),
                              end: (get end some-p),
                              yes: (+ (get yes some-p) u1),
                              no: (get no some-p),
                              open: (get open some-p)
                            })
                          (map-set proposals { id: proposal-id }
                            {
                              creator: (get creator some-p),
                              description: (get description some-p),
                              start: (get start some-p),
                              end: (get end some-p),
                              yes: (get yes some-p),
                              no: (+ (get no some-p) u1),
                              open: (get open some-p)
                            })
                      )
                      (ok true)
                    )
                )
            )
          (err ERR-PROPOSAL-NOT-FOUND)
        )
    )
  )
)

;; ------------------------------------------------------------
;; Finalize proposal
;; ------------------------------------------------------------

(define-public (finalize (proposal-id uint))
  (match (map-get? proposals { id: proposal-id })
    some-p
      (begin
        (if (not (get open some-p))
            (err ERR-VOTING-CLOSED)
            (begin
              (map-set proposals { id: proposal-id }
                {
                  creator: (get creator some-p),
                  description: (get description some-p),
                  start: (get start some-p),
                  end: (get end some-p),
                  yes: (get yes some-p),
                  no: (get no some-p),
                  open: false
                })
              (if (> (get yes some-p) (get no some-p))
                  (ok { result: "passed" })
                  (ok { result: "rejected" })
              )
            )
        )
      )
    (err ERR-PROPOSAL-NOT-FOUND)
  )
)

;; ------------------------------------------------------------
;; Read-only helpers
;; ------------------------------------------------------------

(define-read-only (get-proposal (id uint))
  (map-get? proposals { id: id })
)

(define-read-only (get-total-proposals)
  (ok (var-get proposal-count))
)
