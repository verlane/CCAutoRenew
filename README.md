# CC AutoRenew 🚀

> Never miss a Claude Code renewal window again! Automatically maintains your 5-hour usage blocks.

## 🎯 Problem

Claude Code operates on a 5-hour subscription model that renews from your first message. If you:
- Start coding at 5pm (block runs 5pm-10pm)
- Don't use Claude again until 11:01pm
- Your next block runs 11pm-4am (missing an hour!)

This tool ensures you automatically start a new session right when your block expires, maximizing your available Claude time.

## ✨ Features

- 🔄 **Automatic Renewal** - Starts Claude sessions exactly when needed
- 📊 **Smart Monitoring** - Integrates with [ccusage](https://github.com/ryoppippi/ccusage) for accurate timing
- 🎯 **Intelligent Scheduling** - Checks more frequently as renewal approaches
- 📝 **Detailed Logging** - Track all renewal activities
- 🛡️ **Failsafe Design** - Multiple fallback mechanisms
- 🖥️ **Cross-platform** - Works on macOS and Linux

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/aniketkarne/CCAutoRenew.git
cd CCAutoRenew

# Make scripts executable
chmod +x *.sh

# Interactive setup (recommended)
./setup-claude-cron.sh

# OR manual daemon start
./claude-daemon-manager.sh start
./claude-daemon-manager.sh start --at "09:00"  # with start time
```

That's it! The daemon will now run in the background and automatically renew your Claude sessions.

## 📋 Prerequisites

- [Claude CLI](https://www.anthropic.com/claude-code) installed and authenticated
- Bash 4.0+ (pre-installed on macOS/Linux)
- (Optional) [ccusage](https://github.com/ryoppippi/ccusage) for precise timing

## 🔧 Installation

### 1. Install Claude CLI

First, ensure you have Claude Code installed:
```bash
# Follow the official installation guide
# https://claude.ai/claude-code
```

### 2. Install ccusage (Optional but Recommended)

For accurate renewal timing:
```bash
# Option 1: Global install
npm install -g ccusage

# Option 2: Use without installing
npx ccusage@latest
bunx ccusage
```

### 3. Setup CC AutoRenew

```bash
# Clone this repository
git clone https://github.com/aniketkarne/CCAutoRenew.git
cd cc-autorenew

# Make all scripts executable
chmod +x *.sh

# Test your setup
./test-claude-renewal.sh
```

## 📖 Usage

### Managing the Daemon

```bash
# Start the auto-renewal daemon
./claude-daemon-manager.sh start

# Start with scheduled activation time
./claude-daemon-manager.sh start --at "09:00"
./claude-daemon-manager.sh start --at "2025-01-28 14:30"

# Check daemon status
./claude-daemon-manager.sh status

# View logs
./claude-daemon-manager.sh logs

# Follow logs in real-time
./claude-daemon-manager.sh logs -f

# Stop the daemon
./claude-daemon-manager.sh stop

# Restart the daemon (with same start time if previously set)
./claude-daemon-manager.sh restart
./claude-daemon-manager.sh restart --at "10:00"  # new start time
```

### How It Works

1. **Monitors** your Claude usage using ccusage (or time-based fallback)
2. **Detects** when your 5-hour block is about to expire
3. **Waits** until just after expiration
4. **Starts** a minimal Claude session ("hi" command)
5. **Logs** all activities for transparency

### Monitoring Schedule

The daemon adjusts its checking frequency based on time remaining:
- **Normal**: Every 10 minutes
- **< 30 minutes**: Every 2 minutes  
- **< 5 minutes**: Every 30 seconds
- **After renewal**: 5-minute cooldown

## 🧪 Testing

Run the test suite to verify everything is working:

```bash
# Quick test (< 1 minute)
./test-quick.sh

# Comprehensive test suite (includes start-time feature)
./test-start-time-feature.sh

# Legacy comprehensive test
./test-claude-renewal.sh
```

The new comprehensive test includes:
- ✅ Start-time functionality validation
- ✅ Daemon status with scheduling
- ✅ File management and cleanup
- ✅ Integration tests with real timing
- ✅ All existing functionality tests

## 📁 Project Structure

```
cc-autorenew/
├── claude-daemon-manager.sh      # Main control script
├── claude-auto-renew-daemon.sh   # Core daemon process
├── claude-auto-renew-advanced.sh # Standalone renewal script
├── claude-auto-renew.sh          # Basic renewal script
├── setup-claude-cron.sh          # Interactive setup (daemon/cron)
├── test-start-time-feature.sh    # New comprehensive test suite
├── reddit.md                     # Reddit post about the project
└── README.md                     # This file
```

## 🔍 Logs and Debugging

Logs are stored in your home directory:
- `~/.claude-auto-renew-daemon.log` - Main daemon activity
- `~/.claude-last-activity` - Timestamp of last renewal

View recent activity:
```bash
# Last 50 log entries
tail -50 ~/.claude-auto-renew-daemon.log

# Follow logs in real-time
tail -f ~/.claude-auto-renew-daemon.log
```

## ⚙️ Configuration

The daemon uses smart defaults, but you can modify behavior by editing `claude-auto-renew-daemon.sh`:

```bash
# Adjust check intervals (in seconds)
- Normal: 600 (10 minutes)
- Approaching: 120 (2 minutes)  
- Imminent: 30 (30 seconds)
```

## 🐛 Troubleshooting

### Daemon won't start
```bash
# Check if already running
./claude-daemon-manager.sh status

# Check logs for errors
tail -20 ~/.claude-auto-renew-daemon.log
```

### ccusage not working
```bash
# Test ccusage directly
ccusage blocks

# The daemon will fall back to time-based checking automatically
```

### Claude command fails
```bash
# Verify Claude CLI is installed
which claude

# Test Claude directly
echo "hi" | claude
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [ccusage](https://github.com/ryoppippi/ccusage) by @ryoppippi for accurate usage tracking
- Claude Code team for the amazing coding assistant
- Community feedback and contributions

## 💡 Tips

- Run `claude-daemon-manager.sh status` regularly to ensure the daemon is active
- Check logs after updates to verify renewals are working
- The daemon is lightweight - uses minimal resources while running
- Can be added to system startup for automatic launch

---

Made with ❤️ for the Claude Code community