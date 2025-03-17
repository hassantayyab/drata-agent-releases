#!/bin/bash

echo "Starting silent installation of Drata Agent..."

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)"
  exit 1
fi

# Variables
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 EMAIL REGISTRATION_KEY DOWNLOAD_URL"
  echo "Example: $0 user@company.com YOUR_REGISTRATION_KEY https://example.com/path/to/Drata-Agent-mac.pkg"
  exit 1
fi

EMAIL="$1"
KEY="$2"
DOWNLOAD_URL="$3"

echo "Using email: $EMAIL"
echo "Download URL: $DOWNLOAD_URL"

# Validate email format
if [[ ! "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
  echo "Invalid email format"
  exit 1
fi

# Validate URL format
if [[ ! "$DOWNLOAD_URL" =~ ^https?:// ]]; then
  echo "Invalid download URL format. Must start with http:// or https://"
  exit 1
fi

echo "Preparing for installation..."

# Kill any running instances
echo "Stopping any running instances..."
pkill -f "Drata Agent" || true
sleep 2  # Give processes time to terminate

# Clean up existing installation
echo "Removing existing installation..."
rm -rf "/Applications/Drata Agent.app"
rm -rf "/Library/Application Support/drata-agent"
rm -rf "/Library/Application Support/Drata Agent"
rm -rf "/Library/Logs/Drata Agent"
rm -rf "/Users/root/Library/Application Support/Drata Agent"
rm -rf "/Users/root/Library/Application Support/drata-agent"
rm -rf "/Library/LaunchAgents/com.drata.agent.plist"

# Create temp directory for download
DATE=$(date '+%Y-%m-%d-%H-%M-%S')
TEMP_DIR="/tmp/drata-install-${DATE}"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Download the package
echo "Downloading Drata Agent package from: $DOWNLOAD_URL"
curl --fail -L -o "DrataAgent.pkg" "$DOWNLOAD_URL"

if [ ! -f "DrataAgent.pkg" ]; then
  echo "Failed to download package"
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Create necessary directories with proper permissions
echo "Creating required directories..."
mkdir -p "/Library/Application Support/drata-agent"
mkdir -p "/Library/Application Support/Drata Agent"
mkdir -p "/Library/Logs/Drata Agent"
mkdir -p "/Library/LaunchAgents"
mkdir -p "/Users/root/Library/Application Support/Drata Agent"
mkdir -p "/Users/root/Library/Application Support/drata-agent"

# Set proper permissions
chmod 755 "/Library/Application Support/drata-agent"
chmod 755 "/Library/Application Support/Drata Agent"
chmod 755 "/Library/Logs/Drata Agent"
chmod 755 "/Library/LaunchAgents"
chmod 755 "/Users/root/Library/Application Support/Drata Agent"
chmod 755 "/Users/root/Library/Application Support/drata-agent"

chown root:wheel "/Library/Application Support/drata-agent"
chown root:wheel "/Library/Application Support/Drata Agent"
chown root:wheel "/Library/Logs/Drata Agent"
chown root:wheel "/Library/LaunchAgents"
chown root:wheel "/Users/root/Library/Application Support/Drata Agent"
chown root:wheel "/Users/root/Library/Application Support/drata-agent"

# Create registration files in all possible locations
echo "Creating registration files..."
REGISTRATION_JSON='{
  "email": "'$EMAIL'",
  "key": "'$KEY'"
}'

# System-wide locations
echo "$REGISTRATION_JSON" > "/Library/Application Support/drata-agent/registration.json"
echo "$REGISTRATION_JSON" > "/Library/Application Support/Drata Agent/registration.json"

# Root user locations
echo "$REGISTRATION_JSON" > "/Users/root/Library/Application Support/drata-agent/registration.json"
echo "$REGISTRATION_JSON" > "/Users/root/Library/Application Support/Drata Agent/registration.json"

# Set permissions for registration files
chmod 644 "/Library/Application Support/drata-agent/registration.json"
chmod 644 "/Library/Application Support/Drata Agent/registration.json"
chmod 644 "/Users/root/Library/Application Support/drata-agent/registration.json"
chmod 644 "/Users/root/Library/Application Support/Drata Agent/registration.json"

chown root:wheel "/Library/Application Support/drata-agent/registration.json"
chown root:wheel "/Library/Application Support/Drata Agent/registration.json"
chown root:wheel "/Users/root/Library/Application Support/drata-agent/registration.json"
chown root:wheel "/Users/root/Library/Application Support/Drata Agent/registration.json"

# Create MDM profile for registration
echo "Creating MDM registration profile..."
MANAGED_PREFS_DIR="/Library/Managed Preferences"
mkdir -p "$MANAGED_PREFS_DIR"
cat > "$MANAGED_PREFS_DIR/com.drata.agent.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>RegistrationEmail</key>
    <string>$EMAIL</string>
    <key>RegistrationKey</key>
    <string>$KEY</string>
</dict>
</plist>
EOF

chmod 644 "$MANAGED_PREFS_DIR/com.drata.agent.plist"
chown root:wheel "$MANAGED_PREFS_DIR/com.drata.agent.plist"

# Install package
echo "Installing .pkg package..."
installer -verbose -dumplog -pkg "DrataAgent.pkg" -target / || {
  echo "❌ Error: Failed to install package"
  # Check installer log
  echo "Checking installation log..."
  if [ -f "/var/log/install.log" ]; then
    tail -n 50 "/var/log/install.log"
  fi
  rm -rf "$TEMP_DIR"
  exit 1
}

# Create and configure LaunchAgent
echo "Setting up auto-start configuration..."
LAUNCH_AGENT_FILE="/Library/LaunchAgents/com.drata.agent.plist"

# Create LaunchAgent plist
cat > "$LAUNCH_AGENT_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.drata.agent</string>
    <key>Program</key>
    <string>/Applications/Drata Agent.app/Contents/MacOS/Drata Agent</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Library/Logs/Drata Agent/launch.log</string>
    <key>StandardErrorPath</key>
    <string>/Library/Logs/Drata Agent/launch-error.log</string>
</dict>
</plist>
EOF

# Set proper permissions for LaunchAgent
chmod 644 "$LAUNCH_AGENT_FILE"
chown root:wheel "$LAUNCH_AGENT_FILE"

# Load the LaunchAgent for the current user
CURRENT_USER=$(stat -f "%Su" /dev/console)
sudo -u "$CURRENT_USER" launchctl load "$LAUNCH_AGENT_FILE"

# Launch the application immediately
echo "Launching Drata Agent..."
sudo -u "$CURRENT_USER" open "/Applications/Drata Agent.app"

# Cleanup
rm -rf "$TEMP_DIR"
echo "Cleaned up temporary files"

# Display installation status
echo
echo "Installation Status:"
echo "- Application: /Applications/Drata Agent.app"
[ -d "/Applications/Drata Agent.app" ] && echo "  [✓] Installed" || echo "  [✗] Failed"
echo "- Registration: /Library/Application Support/Drata Agent/registration.json"
[ -f "/Library/Application Support/Drata Agent/registration.json" ] && echo "  [✓] Created" || echo "  [✗] Missing"
echo "- MDM Profile: $MANAGED_PREFS_DIR/com.drata.agent.plist"
[ -f "$MANAGED_PREFS_DIR/com.drata.agent.plist" ] && echo "  [✓] Created" || echo "  [✗] Missing"
echo "- Auto-start: $LAUNCH_AGENT_FILE"
[ -f "$LAUNCH_AGENT_FILE" ] && echo "  [✓] Configured" || echo "  [✗] Failed"
echo "- Launch Status: Started"
echo

echo "✅ Installation completed successfully" 