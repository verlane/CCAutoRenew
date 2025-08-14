# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CC AutoRenew is a bash-based daemon system that automatically renews Claude Code 5-hour usage blocks to prevent gaps and session burning. It integrates with the `ccusage` CLI tool for accurate timing and provides scheduled start times to optimize when monitoring begins.

## Key Commands

### Running Tests
```bash
# Quick test (<1 minute) - syntax and basic functionality
./test-quick.sh

# Comprehensive test including start-time feature
./test-start-time-feature.sh

# Legacy comprehensive test
./test-claude-renewal.sh
```

### Managing the Daemon
```bash
# Start daemon
./claude-daemon-manager.sh start
./claude-daemon-manager.sh start --at "09:00"

# Check status
./claude-daemon-manager.sh status

# View logs
./claude-daemon-manager.sh logs
./claude-daemon-manager.sh logs -f

# Stop/restart
./claude-daemon-manager.sh stop
./claude-daemon-manager.sh restart
```

## Architecture

### Core Components

1. **claude-daemon-manager.sh** - Main control interface that manages daemon lifecycle
   - Handles start/stop/restart/status operations
   - Manages PID files and scheduled start times
   - Provides log viewing functionality

2. **claude-auto-renew-daemon.sh** - Core daemon process that runs continuously
   - Monitors Claude usage via ccusage or time-based fallback
   - Implements smart check intervals (10min → 2min → 30sec as renewal approaches)
   - Handles scheduled start times (WAITING → ACTIVE state transitions)
   - Executes renewal by running `echo "hi" | claude`

3. **Key State Files** (in $HOME)
   - `.claude-auto-renew-daemon.pid` - Daemon process ID
   - `.claude-auto-renew-daemon.log` - Activity logs
   - `.claude-auto-renew-start-time` - Scheduled start epoch timestamp
   - `.claude-last-activity` - Last renewal timestamp

### Daemon State Machine

- **WAITING**: Daemon running but waiting for scheduled start time
- **ACTIVE**: Monitoring and renewing as needed
- The daemon checks `is_start_time_reached()` to transition states

### Check Intervals

The daemon uses progressive check intervals based on time remaining:
- Normal: 600s (10 minutes)
- <30 minutes: 120s (2 minutes)  
- <5 minutes: 30s (30 seconds)
- Post-renewal: 300s (5 minute cooldown)

### Integration Points

- **ccusage**: External tool for accurate Claude usage tracking (`ccusage blocks`)
- **Claude CLI**: Must be installed and authenticated (`echo "hi" | claude`)
- Falls back to time-based checking if ccusage unavailable

## Important Behaviors

1. **Session Burning Prevention**: The `--at` parameter prevents wasting block hours by delaying monitoring until the specified time

2. **Atomic Operations**: PID file operations use write-then-move pattern for safety

3. **Signal Handling**: Daemon responds to SIGTERM/SIGINT for clean shutdown

4. **Logging**: All renewal activities logged with timestamps to `~/.claude-auto-renew-daemon.log`

5. **Error Recovery**: Daemon continues running even if individual renewal attempts fail