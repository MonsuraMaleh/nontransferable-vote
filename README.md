# Nontransferable Vote Contract

A governance voting module where voting power is bound to an address and
cannot be transferred, sold, or delegated.

## Key Functions
- `assign-vote-power` — Grant voting power to an address
- `revoke-vote-power` — Remove voting rights from an address
- `cast-vote` — Submit a vote tied permanently to the voter
- `get-vote-power` — Check assigned voting weight
- `has-voted` — Prevent duplicate voting per proposal

Designed for identity-based governance, councils, and reputation systems.
