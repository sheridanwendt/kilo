# Ventoy bootable USB image (usb-offline profile)

Target: one Ventoy USB drive carrying a persistent Ubuntu image with Ollama +
a preloaded local model + Hermes Agent already configured for the
`usb-offline` profile, so it boots to a working offline agent on any machine.

This is Project Plan steps 16-17. Build process (to be scripted in this
directory as `build-image.sh` once validated manually once):

1. Install [Ventoy](https://www.ventoy.net/) on the target USB drive.
2. Download an Ubuntu Server (or Desktop, if you want a GUI) ISO and copy it
   onto the Ventoy partition as usual — Ventoy boots ISOs directly, no
   re-spinning required for the base OS.
3. Boot the ISO once, with **persistence enabled** (Ventoy supports a
   persistence data file per ISO — create one sized comfortably above your
   model's disk footprint, e.g. 40GB+ for a 14B model plus Hermes + logs).
4. From that persistent session, run the normal install flow:
   ```bash
   git clone https://github.com/<you>/hermes-personal-assistant.git
   cd hermes-personal-assistant
   ./install.sh --profile usb-offline
   ```
5. Confirm `systemctl status ollama hermes-gateway` are both enabled and
   running, then reboot from the USB on a *different* physical machine to
   confirm true device-agnostic behavior (Project Plan step 17) before
   calling the image final.
6. From then on, that persistence file *is* the image — back it up
   (`ventoy/*persistence*` file on the drive) so you can restore it or copy
   it onto a second Ventoy USB without repeating steps 1-4.

## Notes / open items

- First boot needs internet once, to run `install.sh` itself (cloning the
  repo, downloading Ollama, pulling the model). After that, the drive is
  self-contained and boots fully offline.
- Model choice matters a lot here — pick something that runs acceptably on
  the weakest machine you expect to plug this into. Override via
  `HPA_LOCAL_MODEL=<model> ./install.sh --profile usb-offline`.
- If Ventoy's persistence proves too fragile across very different host
  hardware (driver/firmware differences), the fallback is a plain
  dd-flashed persistent Ubuntu image per drive — see the architecture doc's
  "USB approach" decision for why Ventoy was chosen first.
