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

# Using fixed 5-hour intervals starting at 06:00

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

# Function removed - sleep duration now calculated in main loop

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
    
    # Check for start time configuration
    if [ -f "$START_TIME_FILE" ]; then
        start_epoch=$(cat "$START_TIME_FILE")
        start_hour=$(date -d "@$start_epoch" +%H 2>/dev/null || date -r "$start_epoch" +%H)
        schedule1=$(printf "%02d:00" $start_hour)
        schedule2=$(printf "%02d:00" $(((start_hour + 5) % 24)))
        schedule3=$(printf "%02d:00" $(((start_hour + 10) % 24)))
        schedule4=$(printf "%02d:00" $(((start_hour + 15) % 24)))
        blackout_start=$(printf "%02d:00" $(((start_hour + 20) % 24)))
        blackout_end=$(printf "%02d:00" $(((start_hour - 1 + 24) % 24)))
        log_message "Custom schedule: $schedule1, $schedule2, $schedule3, $schedule4 daily"
        log_message "Blackout period: $blackout_start-$blackout_end (preserves $schedule1 slot)"
    else
        log_message "Default schedule: 06:00, 11:00, 16:00, 21:00 daily"
        log_message "Blackout period: 01:00-05:59 (preserves 06:00 slot)"
    fi
    
    # Main loop
    while true; do
        
        # Get current time
        current_epoch=$(date +%s)
        current_hour=$(date +%H)
        current_minute=$(date +%M)
        current_date=$(date +%Y-%m-%d)
        
        # Determine schedule based on start time file
        if [ -f "$START_TIME_FILE" ]; then
            start_epoch=$(cat "$START_TIME_FILE")
            start_hour=$(date -d "@$start_epoch" +%H 2>/dev/null || date -r "$start_epoch" +%H)
            
            # Calculate custom renewal times
            hour1=$start_hour
            hour2=$(((start_hour + 5) % 24))
            hour3=$(((start_hour + 10) % 24))
            hour4=$(((start_hour + 15) % 24))
            
            renewal_1=$(date -d "$current_date $(printf "%02d:00:00" $hour1)" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$current_date $(printf "%02d:00:00" $hour1)" +%s)
            renewal_2=$(date -d "$current_date $(printf "%02d:00:00" $hour2)" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$current_date $(printf "%02d:00:00" $hour2)" +%s)
            renewal_3=$(date -d "$current_date $(printf "%02d:00:00" $hour3)" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$current_date $(printf "%02d:00:00" $hour3)" +%s)
            renewal_4=$(date -d "$current_date $(printf "%02d:00:00" $hour4)" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$current_date $(printf "%02d:00:00" $hour4)" +%s)
            tomorrow_renewal_1=$((renewal_1 + 86400))
            
            # Check if we're in blackout period (5 hours before start time)
            blackout_start_hour=$(((start_hour + 20) % 24))
            blackout_end_hour=$(((start_hour - 1 + 24) % 24))
            
            in_blackout=false
            if [ $blackout_start_hour -lt $blackout_end_hour ]; then
                # Normal case: blackout doesn't cross midnight
                if [ "$current_hour" -ge $blackout_start_hour ] && [ "$current_hour" -lt $blackout_end_hour ]; then
                    in_blackout=true
                fi
            else
                # Blackout crosses midnight
                if [ "$current_hour" -ge $blackout_start_hour ] || [ "$current_hour" -lt $blackout_end_hour ]; then
                    in_blackout=true
                fi
            fi
        else
            # Default schedule: 06:00, 11:00, 16:00, 21:00
            renewal_1=$(date -d "$current_date 06:00:00" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$current_date 06:00:00" +%s)
            renewal_2=$(date -d "$current_date 11:00:00" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$current_date 11:00:00" +%s)
            renewal_3=$(date -d "$current_date 16:00:00" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$current_date 16:00:00" +%s)
            renewal_4=$(date -d "$current_date 21:00:00" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$current_date 21:00:00" +%s)
            tomorrow_renewal_1=$((renewal_1 + 86400))
            
            # Check if we're in blackout period (01:00-05:59)
            in_blackout=false
            if [ "$current_hour" -ge 1 ] && [ "$current_hour" -lt 6 ]; then
                in_blackout=true
            fi
        fi
        
        # Check if we should renew (within 5 minutes of any renewal time)
        should_renew=false
        next_renewal_epoch=0
        
        # Check each renewal time
        for renewal_epoch in $renewal_1 $renewal_2 $renewal_3 $renewal_4; do
            time_diff=$((current_epoch - renewal_epoch))
            abs_time_diff=${time_diff#-}  # absolute value
            
            # If we're within 5 minutes before or after a renewal time
            if [ "$abs_time_diff" -le 300 ]; then
                # Skip if in blackout period and this is the first renewal
                if [ "$in_blackout" = true ] && [ $renewal_epoch -eq $renewal_1 ]; then
                    renewal_hour=$(date -d "@$renewal_epoch" +%H:%M 2>/dev/null || date -r "$renewal_epoch" +%H:%M)
                    log_message "In blackout period, skipping renewal at $renewal_hour"
                else
                    should_renew=true
                    renewal_hour=$(date -d "@$renewal_epoch" +%H:%M 2>/dev/null || date -r "$renewal_epoch" +%H:%M)
                    if [ $time_diff -lt 0 ]; then
                        log_message "✅ Scheduled renewal time approaching! ($renewal_hour in $((abs_time_diff/60)) minutes)"
                    else
                        log_message "✅ Scheduled renewal time reached! ($renewal_hour)"
                    fi
                fi
                break
            fi
        done
        
        # Find next renewal time for logging
        if [ $current_epoch -lt $renewal_1 ]; then
            next_renewal_epoch=$renewal_1
        elif [ $current_epoch -lt $renewal_2 ]; then
            next_renewal_epoch=$renewal_2
        elif [ $current_epoch -lt $renewal_3 ]; then
            next_renewal_epoch=$renewal_3
        elif [ $current_epoch -lt $renewal_4 ]; then
            next_renewal_epoch=$renewal_4
        else
            # After last renewal, next is tomorrow's first renewal
            next_renewal_epoch=$tomorrow_renewal_1
        fi
        
        # Perform renewal if needed
        if [ "$should_renew" = true ]; then
            # Try to start session with retries
            retry_count=0
            max_retries=10
            renewal_success=false
            
            while [ $retry_count -lt $max_retries ]; do
                if start_claude_session; then
                    log_message "Renewal successful!"
                    renewal_success=true
                    # Sleep for 5 minutes after successful renewal
                    sleep 300
                    break
                else
                    retry_count=$((retry_count + 1))
                    if [ $retry_count -lt $max_retries ]; then
                        log_message "Renewal failed (attempt $retry_count/$max_retries), will retry in 1 minute"
                        sleep 60
                    else
                        log_message "ERROR: Renewal failed after $max_retries attempts. Will check again later."
                    fi
                fi
            done
            
            # Continue to next loop iteration after renewal attempts
            continue
        fi
        
        # Calculate how long to sleep
        time_to_next_renewal=$((next_renewal_epoch - current_epoch))
        
        # If within 5 minutes of next renewal, check every minute
        if [ $time_to_next_renewal -le 300 ]; then
            sleep_duration=60  # 1 minute
        else
            sleep_duration=1800  # 30 minutes
        fi
        
        # Log status
        next_renewal_time=$(date -d "@$next_renewal_epoch" +%H:%M 2>/dev/null || date -r "$next_renewal_epoch" +%H:%M)
        if [ "$in_blackout" = true ]; then
            log_message "Next scheduled renewal at $next_renewal_time ($((time_to_next_renewal/60)) min), checking in $((sleep_duration/60)) min (blackout period)"
        else
            log_message "Next scheduled renewal at $next_renewal_time ($((time_to_next_renewal/60)) min), checking in $((sleep_duration/60)) min"
        fi
        
        # Sleep until next check
        sleep "$sleep_duration"
    done
}

# Start the daemon
main