#!/bin/bash

# Claude Auto-Renewal Daemon - Continuous Running Script
# Runs continuously in the background, checking for renewal windows

LOG_FILE="$HOME/.claude-auto-renew-daemon.log"
PID_FILE="$HOME/.claude-auto-renew-daemon.pid"
LAST_ACTIVITY_FILE="$HOME/.claude-last-activity"
START_TIME_FILE="$HOME/.claude-auto-renew-start-time"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to handle shutdown
cleanup() {
    log_message "Daemon shutting down..."
    rm -f "$PID_FILE"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Function to check if we're past the start time
is_start_time_reached() {
    if [ ! -f "$START_TIME_FILE" ]; then
        # No start time set, always active
        return 0
    fi
    
    local start_epoch=$(cat "$START_TIME_FILE")
    local current_epoch=$(date +%s)
    
    if [ "$current_epoch" -ge "$start_epoch" ]; then
        return 0  # Start time reached
    else
        return 1  # Still waiting
    fi
}

# Function to get time until start
get_time_until_start() {
    if [ ! -f "$START_TIME_FILE" ]; then
        echo "0"
        return
    fi
    
    local start_epoch=$(cat "$START_TIME_FILE")
    local current_epoch=$(date +%s)
    local diff=$((start_epoch - current_epoch))
    
    if [ "$diff" -le 0 ]; then
        echo "0"
    else
        echo "$diff"
    fi
}

# Function to get ccusage command
get_ccusage_cmd() {
    if command -v ccusage &> /dev/null; then
        echo "ccusage"
    elif command -v bunx &> /dev/null; then
        echo "bunx ccusage"
    elif command -v npx &> /dev/null; then
        echo "npx ccusage@latest"
    else
        return 1
    fi
}

# Function to get minutes until reset
get_minutes_until_reset() {
    local ccusage_cmd=$(get_ccusage_cmd)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Try to get time remaining from ccusage
    local output=$($ccusage_cmd blocks 2>/dev/null | grep -i "time remaining" | head -1)
    
    if [ -z "$output" ]; then
        output=$($ccusage_cmd blocks --live 2>/dev/null | grep -i "remaining" | head -1)
    fi
    
    # Parse time
    local hours=0
    local minutes=0
    
    if [[ "$output" =~ ([0-9]+)h[[:space:]]*([0-9]+)m ]]; then
        hours=${BASH_REMATCH[1]}
        minutes=${BASH_REMATCH[2]}
    elif [[ "$output" =~ ([0-9]+)m ]]; then
        minutes=${BASH_REMATCH[1]}
    fi
    
    echo $((hours * 60 + minutes))
}

# Function to start Claude session
start_claude_session() {
    log_message "Starting Claude session for renewal..."
    
    if ! command -v claude &> /dev/null; then
        log_message "ERROR: claude command not found"
        return 1
    fi
    
    # Simple approach - macOS compatible
    # Use a subshell with background process for timeout
    (echo "hi" | claude >> "$LOG_FILE" 2>&1) &
    local pid=$!
    
    # Wait up to 10 seconds
    local count=0
    while kill -0 $pid 2>/dev/null && [ $count -lt 10 ]; do
        sleep 1
        ((count++))
    done
    
    # Kill if still running
    if kill -0 $pid 2>/dev/null; then
        kill $pid 2>/dev/null
        wait $pid 2>/dev/null
        local result=124  # timeout exit code
    else
        wait $pid
        local result=$?
    fi
    
    if [ $result -eq 0 ] || [ $result -eq 124 ]; then  # 124 is timeout exit code
        log_message "Claude session started successfully"
        date +%s > "$LAST_ACTIVITY_FILE"
        return 0
    else
        log_message "ERROR: Failed to start Claude session"
        return 1
    fi
}

# Function to calculate next check time
calculate_sleep_duration() {
    local minutes_remaining=$(get_minutes_until_reset)
    
    if [ -n "$minutes_remaining" ] && [ "$minutes_remaining" -gt 0 ]; then
        log_message "Time remaining: $minutes_remaining minutes"
        
        if [ "$minutes_remaining" -le 5 ]; then
            # Check every 30 seconds when close to reset
            echo 30
        elif [ "$minutes_remaining" -le 30 ]; then
            # Check every 2 minutes when within 30 minutes
            echo 120
        else
            # Check every 10 minutes otherwise
            echo 600
        fi
    else
        # Fallback: check based on last activity
        if [ -f "$LAST_ACTIVITY_FILE" ]; then
            local last_activity=$(cat "$LAST_ACTIVITY_FILE")
            local current_time=$(date +%s)
            local time_diff=$((current_time - last_activity))
            local remaining=$((18000 - time_diff))  # 5 hours = 18000 seconds
            
            if [ "$remaining" -le 300 ]; then  # 5 minutes
                echo 30
            elif [ "$remaining" -le 1800 ]; then  # 30 minutes
                echo 120
            else
                echo 600
            fi
        else
            # No info available, check every 5 minutes
            echo 300
        fi
    fi
}

# Main daemon loop
main() {
    # Check if already running
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            echo "Daemon already running with PID $OLD_PID"
            exit 1
        else
            log_message "Removing stale PID file"
            rm -f "$PID_FILE"
        fi
    fi
    
    # Save PID
    echo $$ > "$PID_FILE"
    
    log_message "=== Claude Auto-Renewal Daemon Started ==="
    log_message "PID: $$"
    log_message "Logs: $LOG_FILE"
    
    # Check for start time
    if [ -f "$START_TIME_FILE" ]; then
        start_epoch=$(cat "$START_TIME_FILE")
        log_message "Start time configured: $(date -d "@$start_epoch" 2>/dev/null || date -r "$start_epoch")"
    else
        log_message "No start time set - will begin monitoring immediately"
    fi
    
    # Check ccusage availability
    if ! get_ccusage_cmd &> /dev/null; then
        log_message "WARNING: ccusage not found. Using time-based checking."
        log_message "Install ccusage for more accurate timing: npm install -g ccusage"
    fi
    
    # Main loop
    while true; do
        # Check if we're past start time
        if ! is_start_time_reached; then
            time_until_start=$(get_time_until_start)
            hours=$((time_until_start / 3600))
            minutes=$(((time_until_start % 3600) / 60))
            seconds=$((time_until_start % 60))
            
            if [ "$hours" -gt 0 ]; then
                log_message "Waiting for start time (${hours}h ${minutes}m remaining)..."
                sleep 300  # Check every 5 minutes when waiting
            elif [ "$minutes" -gt 2 ]; then
                log_message "Waiting for start time (${minutes}m ${seconds}s remaining)..."
                sleep 60   # Check every minute when close
            elif [ "$time_until_start" -gt 10 ]; then
                log_message "Waiting for start time (${minutes}m ${seconds}s remaining)..."
                sleep 10   # Check every 10 seconds when very close
            else
                log_message "Waiting for start time (${seconds}s remaining)..."
                sleep 2    # Check every 2 seconds when imminent
            fi
            continue
        fi
        
        # If we just reached start time, log it
        if [ -f "$START_TIME_FILE" ]; then
            # Check if this is the first time we're active
            if [ ! -f "${START_TIME_FILE}.activated" ]; then
                log_message "✅ Start time reached! Beginning auto-renewal monitoring..."
                touch "${START_TIME_FILE}.activated"
            fi
        fi
        
        # Get minutes until reset
        minutes_remaining=$(get_minutes_until_reset)
        
        # Check if we should renew
        should_renew=false
        
        if [ -n "$minutes_remaining" ] && [ "$minutes_remaining" -gt 0 ]; then
            if [ "$minutes_remaining" -le 2 ]; then
                should_renew=true
                log_message "Reset imminent ($minutes_remaining minutes), preparing to renew..."
            fi
        else
            # Fallback check
            if [ -f "$LAST_ACTIVITY_FILE" ]; then
                last_activity=$(cat "$LAST_ACTIVITY_FILE")
                current_time=$(date +%s)
                time_diff=$((current_time - last_activity))
                
                if [ $time_diff -ge 18000 ]; then
                    should_renew=true
                    log_message "5 hours elapsed since last activity, renewing..."
                fi
            else
                # No activity recorded, safe to start
                should_renew=true
                log_message "No previous activity recorded, starting initial session..."
            fi
        fi
        
        # Perform renewal if needed
        if [ "$should_renew" = true ]; then
            # Wait a bit to ensure we're in the renewal window
            sleep 60
            
            # Try to start session
            if start_claude_session; then
                log_message "Renewal successful!"
                # Sleep for 5 minutes after successful renewal
                sleep 300
            else
                log_message "Renewal failed, will retry in 1 minute"
                sleep 60
            fi
        fi
        
        # Calculate how long to sleep
        sleep_duration=$(calculate_sleep_duration)
        log_message "Next check in $((sleep_duration / 60)) minutes"
        
        # Sleep until next check
        sleep "$sleep_duration"
    done
}

# Start the daemon
main