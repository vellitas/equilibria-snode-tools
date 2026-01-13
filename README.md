# Equilibria Service Node Utilities

Community-maintained utilities for managing **Equilibria (XEQ) service nodes**.

This repository targets operators running **multiple service nodes** who need
safe lifecycle tooling, especially **clean removal** of unused or unstaked nodes.

Designed to work with service nodes installed using:
https://github.com/misterr-labs/eqsnode-installer-script

---

## Repository Layout

```
equilibria-snode-tools/
├── README.md
└── scripts/
    └── remove_snodes_range.sh
```

---

## remove_snodes_range.sh

Safely removes a numeric range of Equilibria service nodes.

### Key Characteristics

- DRY RUN by default (no changes)
- Explicit APPLY=1 required to delete anything
- Targets only snode<N> (numeric)
- Never touches plain `snode`

### What Gets Removed

- systemd service units
- systemd drop-ins
- sudoers fragments
- Linux users
- home directories
- orphaned processes

---

## Quick Start

```bash
sudo install -m 750 scripts/remove_snodes_range.sh /usr/local/sbin/
sudo START=82 END=90 /usr/local/sbin/remove_snodes_range.sh
sudo APPLY=1 START=82 END=90 /usr/local/sbin/remove_snodes_range.sh
```

---

## Verification

```bash
systemctl list-unit-files 'eqnode_snode*.service'
getent passwd snode82 snode83
ls -ld /home/snode8*
```

---

## Disclaimer

This is community tooling.
Always dry-run first.
