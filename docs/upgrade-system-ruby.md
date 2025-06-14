# Upgrading System Ruby (Advanced Users Only)

⚠️ **WARNING**: Upgrading system Ruby on Ubuntu 20.04 can break system packages. Docker is the recommended approach.

## Option 1: Using Brightbox PPA (Ruby 3.1)

```bash
# Add Brightbox PPA
sudo apt-add-repository ppa:brightbox/ruby-ng
sudo apt-get update

# Install Ruby 3.1
sudo apt-get install ruby3.1 ruby3.1-dev

# Update alternatives to use Ruby 3.1 as default
sudo update-alternatives --install /usr/bin/ruby ruby /usr/bin/ruby3.1 100
sudo update-alternatives --install /usr/bin/gem gem /usr/bin/gem3.1 100

# Verify
ruby --version  # Should show 3.1.x
```

## Option 2: Compile from Source (Ruby 3.2)

```bash
# Install dependencies
sudo apt-get update
sudo apt-get install -y build-essential libssl-dev libreadline-dev \
  zlib1g-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev \
  libxslt1-dev libcurl4-openssl-dev libffi-dev

# Download Ruby 3.2.0
cd /tmp
wget https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.gz
tar -xzf ruby-3.2.0.tar.gz
cd ruby-3.2.0

# Configure and compile
./configure --prefix=/usr/local
make -j$(nproc)
sudo make install

# Update PATH
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify
ruby --version  # Should show 3.2.0
```

## After Upgrading System Ruby

1. Install Blue Hydra dependencies:
```bash
cd /path/to/blue_hydra
sudo apt-get install -y libdbus-1-dev libdbus-glib-1-dev
sudo gem install bundler
sudo bundle install
```

2. Run Blue Hydra:
```bash
sudo ./bin/blue_hydra
```

## Risks of System Ruby Upgrade

- May break system Ruby scripts
- Package manager issues
- Potential conflicts with system packages
- Difficult to revert

## Recommended: Use Docker Instead

See the main README for Docker instructions, which provide isolation and don't affect system packages. 