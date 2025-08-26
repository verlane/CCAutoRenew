# CC AutoRenew 🚀

> Automatic Claude Code session renewal with customizable daily scheduling.

## 🎯 Problem & Solution

Claude Code operates on 5-hour blocks. Missing renewal windows creates gaps in your coding time.

**CC AutoRenew Solution:**
- 🔄 **Automatic Renewal** - Never miss a renewal window
- ⏰ **Custom Scheduling** - Set your preferred daily schedule (e.g., 05:00, 10:00, 15:00, 20:00)
- 🚫 **Smart Blackout** - Prevents renewals 5 hours before your start time
- 🎯 **Perfect Timing** - Renewals happen exactly when you need them

## ✨ Features

- 🔄 **Automatic Renewal** - Starts Claude sessions at fixed 5-hour intervals
- ⏰ **Fixed Schedule** - Renews at 06:00, 11:00, 16:00, 21:00 daily
- 🚫 **Blackout Period Protection** - No renewals between 01:00-05:59 to preserve 06:00 slot
- 🎯 **Smart Check Intervals** - Checks every 30 minutes, every minute near renewal time
- 📝 **Detailed Logging** - Track all renewal activities with timestamps
- 🛡️ **Robust Retry Logic** - Up to 10 retry attempts with 1-minute intervals
- 🖥️ **Cross-platform** - Works on macOS and Linux
- 🎯 **Simple & Reliable** - No external dependencies, pure bash implementation

## 🚀 Quick Start

```bash
# Clone and setup
git clone https://github.com/aniketkarne/CCAutoRenew.git
cd CCAutoRenew
chmod +x *.sh

# Start daemon with default schedule (06:00, 11:00, 16:00, 21:00)
./claude-daemon-manager.sh start

# OR start with custom schedule (e.g., 05:00, 10:00, 15:00, 20:00)
./claude-daemon-manager.sh start --at "05:00"
```

## 📋 Prerequisites

- [Claude CLI](https://www.anthropic.com/claude-code) installed and authenticated
- Bash 4.0+ (pre-installed on macOS/Linux)

## 🔧 Installation

1. **Install Claude CLI**: Follow the [official guide](https://www.anthropic.com/claude-code)
2. **Clone repository**: `git clone https://github.com/aniketkarne/CCAutoRenew.git`
3. **Make executable**: `chmod +x *.sh`
4. **Test setup**: `./test-quick.sh`

## 📖 Usage

### Commands

```bash
# Start daemon
./claude-daemon-manager.sh start                    # Default: 06:00, 11:00, 16:00, 21:00
./claude-daemon-manager.sh start --at "05:00"       # Custom: 05:00, 10:00, 15:00, 20:00

# Manage daemon
./claude-daemon-manager.sh status                   # Check status
./claude-daemon-manager.sh logs                     # View logs
./claude-daemon-manager.sh logs -f                  # Follow logs
./claude-daemon-manager.sh stop                     # Stop daemon
./claude-daemon-manager.sh restart                  # Restart daemon
```

### How It Works

**Default Schedule (06:00 start)**:
- 06:00, 11:00, 16:00, 21:00
- Blackout: 01:00-05:59

**Custom Schedule (e.g., 05:00 start)**:
- 05:00, 10:00, 15:00, 20:00  
- Blackout: 01:00-04:59

**Features**:
- ±5 minute renewal window
- 10 retry attempts if renewal fails
- Smart checking: 30min normally, 1min near renewal time

## 🧪 Testing

```bash
./test-quick.sh  # Quick validation (< 1 minute)
```

## 📁 Files

- `claude-daemon-manager.sh` - Main control script
- `claude-auto-renew-daemon.sh` - Core daemon process  
- `test-quick.sh` - Quick test suite

## 🔍 Logs & Troubleshooting

```bash
# View logs
./claude-daemon-manager.sh logs
tail -f ~/.claude-auto-renew-daemon.log

# Check status
./claude-daemon-manager.sh status

# Verify Claude CLI
which claude && echo "hi" | claude
```

## 📜 License

MIT License - see [LICENSE](LICENSE) file.

## 🙏 Acknowledgments

- **Aniket Karne** ([@aniketkarne](https://github.com/aniketkarne)) - Original concept and core development
- **Verlane** ([@verlane](https://github.com/verlane)) - Enhanced scheduling and simplified implementation  
- Claude Code team for the amazing coding assistant

---

*Made with ❤️ for the Claude Code community*