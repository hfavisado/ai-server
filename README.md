# Docker Compose stack with Ollama (ROCm) and Open WebUI

## Host prep (once)
1. BIOS: Set the iGPU memory (UMA frame buffer) to 16 GB. With 32 GB total, that leaves 16 GB for the OS. Ollama's ROCm path mostly uses dedicated VRAM, so this setting matters more than kernel tuning.
2. Kernel: Use 6.8 or newer. Debian 12 needs backports for this.
3. Install Docker Engine and the Compose plugin using [Docker's Debian installation instructions](https://docs.docker.com/engine/install/debian/), then verify `docker compose version`. To run Docker without `sudo`, follow the [Linux post-installation instructions](https://docs.docker.com/engine/install/linux-postinstall/); membership in the `docker` group grants root-level privileges.
4. Ensure the host has a compatible AMD GPU kernel driver and exposes `/dev/kfd` and `/dev/dri`. The ROCm image supplies user-space libraries but does not replace the host driver. See [Ollama's GPU documentation](https://docs.ollama.com/gpu) for driver requirements. The 780M is not on its supported AMD GPU list; the configured `HSA_OVERRIDE_GFX_VERSION` is an experimental workaround and does not guarantee GPU support.
5. Check devices: `ls /dev/kfd /dev/dri` should list both.

## Setup, start and test

From the repository root, create `.env` using the host's render group GID:

```sh
./setup.sh
```

The script refuses to overwrite an existing `.env`. Alternatively, create it manually:

```sh
cp .env.example .env
getent group render | cut -d: -f3
```

Edit `.env` and replace the example `RENDER_GID=105` with the number printed by the command. Compose stores persistent data under `data/` relative to the repository root.

If upgrading an existing deployment, stop its stack first, then move its Ollama and Open WebUI data into `data/ollama` and `data/open-webui` respectively before starting the new stack. Preserve file ownership and permissions.

Start and test the stack from the repository root:

```sh
docker compose up -d
docker exec -it ollama ollama pull qwen3:8b
docker exec -it ollama ollama run qwen3:8b "hello"
docker exec -it ollama ollama ps     # should show 100% GPU
docker logs ollama | grep -i -E "rocm|gfx|vram"
```

Open WebUI is at `http://<host>:3000`. The first account you create becomes admin.

## Backups

Back up `data/` regularly; it contains the Ollama models and Open WebUI's database and other persistent data. From the repository root, stop the stack before archiving to avoid an inconsistent database:

```sh
docker compose stop
sudo tar -czf "../ai-server-data-$(date +%Y%m%d-%H%M%S).tar.gz" data/
```

Verify the archive was created successfully, store it securely outside the host, then restart the stack with `docker compose up -d`. The backup may contain private conversations and credentials. To restore, stop the stack, extract the archive into the repository root with `sudo tar -xzf /path/to/backup.tar.gz` after moving any existing `data/` aside, and start the stack again.

## Optional systemd unit
The `restart: unless-stopped` policy already brings the stack up after a reboot, as long as Docker is enabled with `systemctl enable docker`. A separate unit is only needed if you want ordering, for example starting after a NAS mount.

## If the GPU isn't used
- If the logs show CPU fallback, try the Vulkan backend. Use the standard `ollama/ollama` image, set `OLLAMA_VULKAN=1`, and pass through `/dev/dri` only. Vulkan on the 780M is often more stable than ROCm, but this depends on your Ollama version.
- If that also fails, use llama.cpp's Vulkan build instead.

## Model picks for 16 GB of VRAM and 32 GB of RAM
- `qwen3:8b` for general use.
- `qwen3:14b` at Q4 fits and runs at a few tokens per second.
- `qwen3:30b-a3b` is the best fit for this hardware. It's about 17–19 GB, so it would partly spill into RAM, but only 3B parameters are active per token.