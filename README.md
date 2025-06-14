# BlueHydra

BlueHydra is a Bluetooth device discovery service built on top of the `bluez` 
library. BlueHydra makes use of ubertooth where available and attempts to track
both classic and low energy (LE) bluetooth devices over time. 

## Quick Start with Docker (Recommended)

The easiest way to run Blue Hydra is using Docker, which provides Ruby 3.x without affecting your system:

```bash
# Build and run with Docker
sudo ./run-blue-hydra.sh

# Or manually with Docker Compose
sudo docker-compose up

# Run in background
sudo docker-compose up -d

# View logs
sudo docker-compose logs -f

# Stop
sudo docker-compose down
```

The Docker container includes Ruby 3.2, all dependencies, and proper Bluetooth support.

## Installation (System Ruby)

⚠️ **Note**: Blue Hydra requires Ruby 3.x. Ubuntu 20.04 ships with Ruby 2.7 which is incompatible. Use Docker (above) or see [upgrade instructions](docs/upgrade-system-ruby.md).

Ensure that the following packages are installed: 

```
bluez
bluez-test-scripts
python3-bluez
python3-dbus
ubertooth # where applicable
sqlite3
libsqlite3-dev
libdbus-1-dev
libdbus-glib-1-dev
```

If your chosen distro is still on bluez 4 please choose a more up to date distro.  Bluez 5 was released in 2012 and is required.

On Debian-based systems, these packages can be installed with the following command line:

```sudo apt-get install bluez bluez-test-scripts python3-bluez python3-dbus libsqlite3-dev libdbus-1-dev libdbus-glib-1-dev ubertooth```

To install the needed gems:

```
# Install Ruby gems (requires Ruby 3.x)
sudo gem install bundler
bundle install
```

Once all dependencies are met simply run `sudo ./bin/blue_hydra` to start discovery.

There are a few flags that can be passed to this script: 

* `-d` or `--daemonize`: suppress CLI output and run in background
* `-z` or `--demo`: run with CLI output but mask displayed macs for demo purposes
* `-p` or `--pulse`: attempt to send data to Pwn Pulse


## Recommended Hardware
BlueHydra should function with most internal bluetooth cards but we recommend 
using the Sena UD100 adapter.

Additionally you can make use of Ubertooth One hardware to detect active devices
not in discoverable mode.

**Note:** using an Ubertooth One is _not_ a replacement for a conventional
bluetooth dongle. 

## Configuring Options

The config file `blue_hydra.yml` is located in the install directory, unless /etc/blue_hydra exists,
then it is in /etc/blue_hydra. The config file is located in `/opt/pwnix/data/blue_hydra/blue_hydra.yml` on
Pwnie devices.

The following options can be set:

* `log_level`: defaults to info level, can be set to debug for much more verbosity. If set to `false` no log or rssi log will be created.
* `bt_device`: specify device to use as main bluetooth interface, defaults to `hci0`
* `info_scan_rate`: rate at which to run info scan in seconds, defaults to 240.  Values too small will be set to 45.  Value of 0 disables info scanning.
* `status_sync_rate`: rate at which to sync device status to Pulse in seconds
* `btmon_log`: `true|false`, if set to true will log filtered btmon output
* `btmon_rawlog`: `true|false`, if set to true will log unfiltered btmon output
* `file`: if set to a filepath that file will be read in rather than doing live device interactions
* `rssi_log`: `true|false`, if set will log serialized RSSI values
* `aggressive_rssi`: `true|false`, if set will agressively send RSSIs to Pulse
* `ui_inc_filter_mode`: `:disabled|:hilight|:exclusive`, set ui filtering to this mode by default
* `ui_inc_filter_mac`: `- FF:FF:00:00:59:25`, set inclusive filter on this mac, each goes on a newline proceeded by hiphon and space
* `ui_inc_filter_prox`: `- 669a0c20-0008-9191-e411-1b11d05d7707-9001-3364`, set inclusive filter on this proximity_uuid-major_number-minor_number, each goes on a newline proceeded by hiphon and space
* `ui_exc_filter_mac`: same syntax as ui_inc_filter_mac, but exclude instead
* `ui_exc_filter_prox`: same syntax as ui_inc_filter_prox, but exclude instead
* `ignore_mac`: same syntax as ui_inc_filter mac, but entirely ignore device, both db and ui

## Usage

It may also be useful to check blue_hydra --help for additional command line options.  At this time it looks like this:

```
Usage: blue_hydra [options]
    -d, --daemonize                  Suppress output and run in daemon mode
    -z, --demo                       Hide mac addresses in CLI UI
    -p, --pulse                      Send results to hermes
        --pulse-debug                Store results in a file for review
        --no-db                      Keep db in ram only
        --rssi-api                   Open 127.0.0.1:1124 to allow other processes to poll for seen devices and rssi
        --no-info                    For the purposes for fox hunting, don't info scan.  Some info may be missing, but there will be less gaps during tracking

    -h, --help                       Show this message
```

## Logging

All data is logged to an sqlite database (unless --no-db) is passed at the command line.  The database `blue_hydra.db` is located in the blue_hydra
directory, unless /etc/blue_hydra exists, and then it is placed in /etc/blue_hydra. On Pwnie Express sensors, it will be in /opt/pwnix/data.

The database will automatically be cleaned of older devices to ensure performance.  If you want to keep information about devices which haven't been seen in more than a week it is your responsibility to offload data using one of the available options (`--pulse`, `--pulse-debug`) or manually back up the database once a week.

An example for a script wrapping blue_hydra and creating a csv output after run is available here:
https://github.com/pwnieexpress/pwn_pad_sources/blob/develop/scripts/blue_hydra.sh
This script will simply take a timestamp before blue_hydra starts, and then again after it exits, then grab a few interesting values from the db and output in csv format.

## Helping with Development

PR's should be targeted against the "develop" branch.
Develop branch gets merged to master branch and tagged during the release process.

## Troubleshooting

### `Parser thread "\xC3" on US-ASCII` 

If you encounter an error like `Parser Thread "\xC3" on US-ASCII` it may be due
to an encoding misconfiguration on your system. 

On Debian like systems, this can be resolved by setting locale encodings as follows:

```
sudo locale-gen en_US.UTF-8 
sudo locale-gen en en_US en_US.UTF-8
sudo dpkg-reconfigure locales
export LC_ALL="en_US.UTF-8"
```

This issue and solution brought up by [llazzaro](https://github.com/llazzaro)
[here](https://github.com/pwnieexpress/blue_hydra/issues/65).

## Additional Edits and Work

Leveraging Cursor to Help Address Underlying Ruby Limitations via Docker Container

## Ruby 3.x and Sequel ORM Migration

This codebase has been modernized to use:
- **Ruby 3.2+** for better performance and security
- **Sequel ORM** replacing the deprecated DataMapper
- **Native Ruby D-Bus** integration for improved Bluetooth discovery

### Docker Environment (Recommended)

For production use, the containerized environment handles all dependencies correctly. Running Blue Hydra in the provided Docker container avoids host OS Ruby compatibility issues entirely.

```bash
# Run with automatic Ruby detection
sudo ./run-blue-hydra.sh

# Or use Docker directly
sudo docker-compose up
```

### Ruby D-Bus Integration

Blue Hydra now supports native Ruby D-Bus integration for improved performance. The `ruby-dbus` gem is automatically used when available. To force the use of Python scripts, set `use_python_discovery: true` in `blue_hydra.yml`.

## OSX
# ... existing code ...
