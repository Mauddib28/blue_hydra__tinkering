# Blue Hydra Ruby Version Issue

## The Problem

- **Ubuntu 20.04 ships with Ruby 2.7.0**
- **Blue Hydra requires Ruby 3.x** (modernized version)
- **System Ruby 2.7 is missing required gems** (ruby-dbus)

## Why You Can't Run `sudo ./bin/blue_hydra` Directly

When you run `sudo ./bin/blue_hydra`, it uses system Ruby (/usr/bin/ruby) which is version 2.7.0. This version:
1. Is incompatible with the modernized Blue Hydra code
2. Doesn't have the `ruby-dbus` gem installed
3. Can't install the gem properly due to version conflicts

## The Solution: Docker

Since you don't want Ruby version managers (rbenv, rvm, etc.), Docker is the ONLY way to run Blue Hydra without upgrading your entire system Ruby (which could break system packages).

## How to Run Blue Hydra

```bash
# Simple command (always uses Docker with Ruby 3.2)
sudo ./blue-hydra

# Or use docker-compose directly
sudo docker-compose up

# Run in background
sudo docker-compose up -d

# View logs
sudo docker-compose logs -f

# Stop
sudo docker-compose down
```

## What the Docker Container Provides

- Ruby 3.2 (latest stable)
- All required gems (ruby-dbus, sequel, etc.)
- Bluetooth hardware access
- Isolated environment that doesn't affect your system

## Alternative: Upgrade System Ruby

If you absolutely must run Blue Hydra directly on the host:
1. See `docs/upgrade-system-ruby.md` for instructions
2. WARNING: This can break Ubuntu system packages
3. Docker is the safer, recommended approach 