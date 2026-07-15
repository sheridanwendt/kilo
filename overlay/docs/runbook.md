# Reinstall / recovery runbook

## Cloud VM or on-prem Ubuntu box (bare metal)

1. Fresh Ubuntu install (22.04+ recommended).
2. `git clone https://github.com/<you>/hermes-personal-assistant.git && cd hermes-personal-assistant`
3. `./install.sh --profile cloud-server` (or `on-prem`)
4. Verify: `systemctl status ollama hermes-gateway`, then `hermes` to chat.
5. If restoring from a backup, see "Memory restore" below before step 4.

## Docker (cloud or on-prem)

1. `docker compose -f docker-compose.yml -f overlay/docker/docker-compose.override.yml up -d`
2. Verify: `docker compose logs -f hermes-agent`

## USB (usb-offline)

See `overlay/iso-usb/README.md`. Recovery here means re-flashing/copying the
persistence file to a new drive, not re-running the install from scratch.

## Memory backup / restore

Hermes's entire state (skill memory, conversation memory, user model,
`config.yaml`) lives in `~/.hermes/`. To back it up:

```bash
tar czf hermes-backup-$(date +%Y%m%d).tar.gz -C "$HOME" .hermes
```

To restore onto a freshly-installed instance (after running `install.sh`
once so Hermes and its systemd services exist, but before you've had a real
conversation on the new box):

```bash
sudo systemctl stop hermes-gateway
tar xzf hermes-backup-YYYYMMDD.tar.gz -C "$HOME"
sudo systemctl start hermes-gateway
```

Keep backups off the machine itself (encrypted, on separate storage) —
`~/.hermes` may contain OAuth refresh tokens for any cloud providers you've
configured.

## Known gaps to account for during recovery

- Native Windows install is experimental upstream; always recover via WSL2.
- The purchase-making skill is deferred/not present — don't expect it after
  a restore, it was never built into any backed-up instance.
