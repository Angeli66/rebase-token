# Rebase Token Contract

An elastic supply token contract that adjusts total supply through
proportional balance updates across all token holders.

## Key Functions
- `rebase` — Adjust total token supply based on rebase factor
- `transfer` — Move tokens between accounts
- `mint` — Create new tokens (authorized only)
- `burn` — Destroy tokens (authorized only)
- `get-total-supply` — Retrieve current supply after rebase
- `get-balance` — View holder balance

Designed for algorithmic supply models, synthetic assets,
and protocol-controlled monetary experiments.
