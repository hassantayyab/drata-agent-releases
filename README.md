# Drata Agent Releases

This repository hosts releases of the Drata Agent for macOS.

## Installation

To install the Drata Agent, you can use our installation script:

```bash
curl -o install_drata_agent.sh https://raw.githubusercontent.com/hassantayyab/drata-agent-releases/main/install_drata_agent.sh
chmod +x install_drata_agent.sh
sudo ./install_drata_agent.sh YOUR_EMAIL YOUR_KEY
```

### Kill existing instances

```bash
killall "Drata Agent"
```

### Launch manually

```bash
open "/Applications/Drata Agent.app"
```

### Remove application

```bash
sudo rm -rf "/Applications/Drata Agent.app"
```

#### Remove registration data

```bash
sudo rm -rf "$HOME/Library/Application Support/Drata Agent"
```

## Latest Release

The latest version of Drata Agent can be downloaded from the releases section of this repository.

## Support

For support, please contact Drata support team.
