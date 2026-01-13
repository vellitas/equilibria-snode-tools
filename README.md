# Equilibria Snode Tools

Utilities for managing **Equilibria service nodes (snodes)** at scale.

This repository is designed for **community operators** running Equilibria service nodes installed via  
**Mister R Labs' installer**:  
https://github.com/misterr-labs/eqsnode-installer-script

The tools here focus on **safe, repeatable system administration tasks** that are painful to do by hand
when operating dozens of service nodes on a single host.

---

## Included Tools

### `remove_snodes_range.sh`
Safely removes a **range of Equilibria service nodes** by:
- Disabling and removing systemd service units
- Removing Linux users (`snode<N>`)
- Deleting associated home directories and data
- Cleaning up sudoers snippets
- Resetting systemd state

⚠️ **Default mode is DRY-RUN** — nothing is deleted unless explicitly enabled.

---

## Recommended Installation (Clone + Install)

```bash
git clone git clone https://github.com/vellitas/equilibria-snode-tools.git
cd equilibria-snode-tools

sudo install -m 0755 -o root -g root sbin/remove_snodes_range.sh /usr/local/sbin/remove_snodes_range.sh
```

---

## Usage

```bash
sudo remove_snodes_range.sh
sudo START=82 END=90 remove_snodes_range.sh
sudo APPLY=1 START=82 END=90 remove_snodes_range.sh
```

---

## License

MIT License
