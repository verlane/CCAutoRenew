# CC AutoRenew 🚀

> Never miss a Claude Code renewal window again! Automatically maintains your 5-hour usage blocks with smart daily scheduling and blackout periods.

## 🔄 Key Difference from Original

**Original Code**: "언제부터 시작" (When to start monitoring)
- `--at "09:00"` means start monitoring at 9am, then renew every 5 hours continuously
- Example: 09:00 → 14:00 → 19:00 → 00:00 → 05:00 → 10:00...

**Enhanced Version**: "매일 정해진 시간에 갱신" (Daily fixed-time renewals)
- `--at "09:00"` means renew at 9am daily, with 4 scheduled times per day
- Example: 09:00 → 14:00 → 19:00 → 00:00 → [blackout 04:00-08:59] → 09:00 next day
- Prevents session burning by avoiding renewals 5 hours before your target time

## 🎯 Problem

Claude Code operates on a 5-hour subscription model that renews from your first message. If you:
- Start coding at 5pm (block runs 5pm-10pm)
- Don't use Claude again until 11:01pm
- Your next block runs 11pm-4am (missing an hour!)

**Session Burning Problem:** Starting the daemon at random times can waste precious hours of your block. If you want to code from 9am-2pm but start the daemon at 6am, you've burned 3 hours!

**Solution:** CC AutoRenew prevents both gaps AND session burning:
- 🚫 **Prevents Gaps** - Automatically starts new sessions when blocks expire
- ⏰ **Prevents Session Burning** - Schedule when monitoring begins (`--at "09:00"`) 
- 🎯 **Perfect Timing** - Start your 5-hour block exactly when you need it

## ✨ Features

- 🔄 **Automatic Renewal** - Starts Claude sessions exactly when needed
- ⏰ **Daily Schedule Mode** - Renews at fixed times (e.g., 06:00, 11:00, 16:00, 21:00)
- 🚫 **Blackout Period Protection** - Prevents renewals before scheduled start time
- 📊 **Smart Monitoring** - Integrates with [ccusage](https://github.com/ryoppippi/ccusage) for accurate timing
- 🆘 **Emergency Renewal** - Prevents block expiry with 2-minute warning (respects blackout)
- 🎯 **Intelligent Check Intervals** - Adaptive checking based on time remaining
- 📝 **Detailed Logging** - Track all renewal activities with clear status messages
- 🛡️ **Failsafe Design** - Multiple retry mechanisms with up to 10 attempts
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
    # https://www.anthropic.com/claude-code
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

#### Schedule Mode (--at parameter)
When you set a start time (e.g., `--at "06:00"`), the daemon creates a daily schedule:
- **06:00** - First renewal (start time)
- **11:00** - Second renewal (+5 hours)
- **16:00** - Third renewal (+5 hours)
- **21:00** - Fourth renewal (+5 hours)
- **01:00-05:59** - Blackout period (no renewals to preserve 06:00 slot)

#### Smart Features
1. **Blackout Period**: 5 hours before start time, no renewals occur
2. **Emergency Renewal**: If block expires outside blackout, renews immediately
3. **Adaptive Checking**: More frequent checks as renewal time approaches
4. **Retry Logic**: Up to 10 attempts if renewal fails
5. **ccusage Integration**: Real-time block status monitoring

### 💡 Avoid Session Burning

**Problem:** Starting daemon at wrong time wastes your 5-hour block
```bash
# BAD: Start daemon at 6am but want to code 9am-2pm = 3 hours wasted!
./claude-daemon-manager.sh start

# GOOD: Schedule daemon to start monitoring at 9am
./claude-daemon-manager.sh start --at "09:00"
# Your 5-hour block: 9am-2pm (perfect timing!)
```

**Use Cases:**
- 🌅 **Morning Coder**: `--at "09:00"` for 9am-2pm coding sessions
- 🌙 **Night Owl**: `--at "18:00"` for 6pm-11pm evening coding
- 📅 **Planned Session**: `--at "2025-01-28 14:30"` for specific date/time

### Monitoring Schedule

The daemon intelligently adjusts checking frequency:

#### Normal Operation
- **> 30 minutes**: Every 30 minutes
- **10-30 minutes**: Every 10 minutes
- **2-10 minutes**: Every 5 minutes
- **< 2 minutes**: Every minute

#### During Blackout Period
- **> 10 minutes before start**: Every 30 minutes
- **< 10 minutes before start**: Every 2 minutes

#### Based on ccusage
- **> 30 minutes remaining**: Every 30 minutes
- **10-30 minutes remaining**: Every 5 minutes
- **3-10 minutes remaining**: Every 2 minutes
- **< 3 minutes remaining**: Every 30 seconds

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

### 📄 Attribution Guidelines

When forking or redistributing this project, please:
- Keep original attribution in README acknowledgments
- Maintain the MIT License and copyright notice
- Add your own contributions to the acknowledgments section
- Follow standard open source attribution practices

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

### 👨‍💻 Original Author
- **Aniket Karne** - [@aniketkarne](https://github.com/aniketkarne) - Original concept, core development, and start-time scheduling feature

### 🚀 Major Contributors
- **Verlane** - [@verlane](https://github.com/verlane) - Enhanced scheduling with blackout periods, emergency renewal logic, intelligent retry mechanisms, and adaptive check intervals

### 🛠️ Dependencies & Tools
- [ccusage](https://github.com/ryoppippi/ccusage) by @ryoppippi for accurate usage tracking
- Claude Code team for the amazing coding assistant

### 🌟 Community
- Community feedback and contributions
- Open source contributors and testers

## 💡 Tips

- Run `claude-daemon-manager.sh status` regularly to ensure the daemon is active
- Check logs after updates to verify renewals are working
- The daemon is lightweight - uses minimal resources while running
- Can be added to system startup for automatic launch

---

Made with ❤️ for the Claude Code community