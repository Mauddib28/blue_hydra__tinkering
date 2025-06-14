# Blue Hydra Docker Container with Ruby 3.x
# Purpose: Run Blue Hydra with modern Ruby on any host OS
FROM ruby:3.2-slim-bullseye

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    pkg-config \
    # SQLite
    libsqlite3-dev \
    sqlite3 \
    # Bluetooth - ensure we get bluetoothd
    bluez \
    bluez-tools \
    bluez-hcidump \
    libbluetooth-dev \
    # D-Bus and system integration
    libdbus-1-dev \
    libdbus-glib-1-dev \
    dbus \
    dbus-x11 \
    # Python (for fallback discovery if needed)
    python3 \
    python3-bluez \
    python3-dbus \
    python3-gi \
    python3-gi-cairo \
    gir1.2-glib-2.0 \
    # Utilities
    git \
    sudo \
    procps \
    usbutils \
    net-tools \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for running Blue Hydra
RUN useradd -m -s /bin/bash hydra && \
    usermod -aG sudo hydra && \
    echo 'hydra ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Set working directory
WORKDIR /opt/blue_hydra

# Copy project files
COPY --chown=hydra:hydra . .

# Install Ruby dependencies
RUN gem install bundler && \
    bundle install

# Create necessary directories
RUN mkdir -p logs && \
    chown -R hydra:hydra /opt/blue_hydra

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Expose BlueHydra API port
EXPOSE 1124

# Set volume for database persistence
VOLUME ["/opt/blue_hydra"]

# Run entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"] 