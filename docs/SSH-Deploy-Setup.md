---
creation_date: 2026-11-03
status: status/active
project: "[[Homelab Migration]]"
tags:
  - hardware/synology
  - task/pending
---

# Safe SSH credentials for DataVault Restreamer deploy

**Rule:** use an SSH **public key**. Never put NAS passwords in scripts, `Makefile`, git, or chat.

> [!NOTE] NAS users (not Mac users)
> - **MediaVault** SSH user: `DocBrown` (LiveTV-Consolidator)
> - **DataVault** SSH user: `mcfly` (Restreamer)
>
> These are Synology accounts. Your Mac user stays as-is (e.g. `begun`). SSH connects *from* the Mac *to* the NAS as that NAS user.

| Piece | MediaVault (LiveTV) | DataVault (Restreamer) |
|-------|---------------------|-------------------------|
| NAS | MediaVault (`192.168.1.26`) | DataVault (`192.168.1.28`) |
| NAS SSH user | `DocBrown` | `mcfly` |
| SSH port | `2323` | Confirm in DSM (often also `2323`) |
| Mac private key | `~/.ssh/id_ed25519_mediavault` | `~/.ssh/id_ed25519_datavault` |
| Mac `~/.ssh/config` Host | `mediavault` | `datavault` |
| Deploy path | `/volume1/docker/LiveTV-Consolidator` | `/volume1/docker/restreamer-dev` |

## Status on this Mac (already done)

1. Key exists: `~/.ssh/id_ed25519_datavault` (+ `.pub`)
2. `~/.ssh/config` `Host datavault` → `192.168.1.28`, user **`mcfly`**, port `2323`, that identity file

**Still required:** install the **public** key on DataVault’s **`mcfly`** account (step 2 below). Until that is done, `ssh datavault` will say `Permission denied`.

---

## 1. Create a deploy key on your Mac (once)

Skip if the key already exists (it does on this Mac).

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_datavault -C "restreamer-deploy@$(hostname -s)"
```

Passphrase: preferred for security; macOS can store it via `ssh-add --apple-use-keychain`.

## 2. Install the public key on DataVault (you do this on the NAS)

Copy **only** the `.pub` file to the clipboard:

```bash
pbcopy < ~/.ssh/id_ed25519_datavault.pub
```

Current public key line (one line — paste exactly):

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJYgCUEgGEpCIDS0AcAZAR29rexE0Y32WyGAE41aYV/I restreamer-deploy@BegunFX-MAC-WIFI
```

### 2a. DSM checks on DataVault

1. Open DataVault DSM in a browser.
2. **Control Panel → Terminal & SNMP** — enable SSH. Note the port (MediaVault uses `2323`; use whatever DataVault shows).
3. **Control Panel → User & Group → mcfly → Edit → Advanced** — enable **Allow user to access via SSH / SFTP** if present.
4. Prefer an account that can run Docker for deploys (admin / Docker permission group).

### 2b. Add the public key to **mcfly** on DataVault

**Option A — one-time password login from your Mac** (mirrors MediaVault setup):

```bash
ssh -p 2323 mcfly@192.168.1.28
```

(Use DataVault’s real SSH port if it is not `2323`. Enter the **NAS** password for `mcfly` when prompted — this is not your Mac login.)

Then on the NAS session:

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJYgCUEgGEpCIDS0AcAZAR29rexE0Y32WyGAE41aYV/I restreamer-deploy@BegunFX-MAC-WIFI' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
exit
```

**Option B — DSM File Station**

1. Browse to `mcfly`’s home → `.ssh` (create folder if missing).
2. Edit or create `authorized_keys`.
3. Paste the public key as its own line.
4. Permissions should be: `.ssh` = `700`, `authorized_keys` = `600`.

**Option C — DSM Terminal “Import SSH public key”** (if available for user `mcfly`).

## 3. Mac SSH config (no secrets in the repo)

Already set on this Mac. Reference:

```sshconfig
Host datavault
  HostName 192.168.1.28
  User mcfly
  Port 2323
  IdentityFile ~/.ssh/id_ed25519_datavault
  IdentitiesOnly yes
  AddKeysToAgent yes
  UseKeychain yes
  LogLevel ERROR
```

If DataVault’s SSH port is not `2323`, change `Port` to match DSM.

## 4. Test (must work before deploy)

```bash
ssh datavault 'echo ok && whoami && hostname'
```

Expected:

- `ok`
- `mcfly`
- DataVault hostname
- **no password prompt**

If you still get `Permission denied (publickey,password)`:

- Public key was not appended to **mcfly**’s `authorized_keys` (wrong user home, e.g. DocBrown by mistake)
- SSH not enabled for `mcfly` on DataVault
- Wrong port in `~/.ssh/config`

## 5. Point the deploy script and deploy

```bash
cd /Users/begun/Documents/ObsidianVaults/note-vault/Restreamer
cp -n deploy.env.example deploy.env   # optional; defaults already target datavault
make deploy-datavault
```

That creates/updates **DataVault** `/volume1/docker/restreamer-dev` and container `restreamer-dev` on ports `18085` etc. Production `restreamer` on `:8085` is not touched.

## What we never do

| Bad | Why |
|-----|-----|
| Password in `deploy-datavault.sh` | Leaks via git / shell history |
| Committing private keys | Full account compromise |
| Using MediaVault’s `DocBrown` for DataVault | Wrong NAS user — DataVault is `mcfly` |
| Deploying Restreamer to MediaVault | Wrong host — Restreamer runs on DataVault |

Private key stays in `~/.ssh/` (mode `600`). Only the **public** key goes on the NAS.

## Docker permission note

`mcfly` on DataVault must be able to run `docker`. If `docker build` fails with permission denied on the socket, configure the same passwordless-sudo / Docker access pattern you used on MediaVault for LiveTV (adapted for user `mcfly`).
