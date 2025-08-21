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
    # Skip ccusage if SKIP_CCUSAGE is set
    if [ "$SKIP_CCUSAGE" = "true" ]; then
        return 1
    fi
    
    local ccusage_cmd=$(get_ccusage_cmd)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Try to get time remaining from ccusage with timeout
    local output=$(timeout 5 $ccusage_cmd blocks 2>/dev/null | grep -i "time remaining" | head -1)
    
    if [ -z "$output" ]; then
        output=$(timeout 5 $ccusage_cmd blocks --live 2>/dev/null | grep -i "remaining" | head -1)
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
        # Log message moved outside of this function to avoid interfering with return value
        
        if [ "$minutes_remaining" -le 3 ]; then
            # Check every 30 seconds when very close to reset
            echo 30
        elif [ "$minutes_remaining" -le 10 ]; then
            # Check every 2 minutes when close to reset
            echo 120
        elif [ "$minutes_remaining" -le 30 ]; then
            # Check every 5 minutes when moderately close
            echo 300
        else
            # Check every 30 minutes otherwise
            echo 1800
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
                echo 1800  # 30 minutes
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
        
        # Check if we should renew based on scheduled time
        should_renew=false
        
        if [ -f "$START_TIME_FILE" ]; then
            # Schedule-based renewal
            start_epoch=$(cat "$START_TIME_FILE")
            current_epoch=$(date +%s)
            
            # Calculate time since the original start time
            time_since_start=$((current_epoch - start_epoch))
            
            # Check if we're at a scheduled renewal time (05:00, 10:00, 15:00, 20:00)
            if [ $time_since_start -ge 0 ]; then
                # Get the hour and minute from the original start time
                start_hour=$(date -d "@$start_epoch" +%H 2>/dev/null || date -r "$start_epoch" +%H)
                start_minute=$(date -d "@$start_epoch" +%M 2>/dev/null || date -r "$start_epoch" +%M)
                
                # Get current date at midnight
                current_date=$(date +%Y-%m-%d)
                
                # Calculate today's start time
                today_start_epoch=$(date -d "$current_date $start_hour:$start_minute:00" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$current_date $start_hour:$start_minute:00" +%s)
                
                # Check if we're within 5 minutes of any scheduled renewal time (before or after)
                for offset in 0 18000 36000 54000; do
                    renewal_time=$((today_start_epoch + offset))
                    time_diff=$((current_epoch - renewal_time))
                    abs_time_diff=${time_diff#-}  # absolute value
                    
                    # If we're within 5 minutes before or after a renewal time
                    if [ "$abs_time_diff" -le 300 ]; then
                        should_renew=true
                        renewal_hour=$(date -d "@$renewal_time" +%H:%M 2>/dev/null || date -r "$renewal_time" +%H:%M)
                        if [ $time_diff -lt 0 ]; then
                            log_message "✅ Scheduled renewal time approaching! ($renewal_hour in $((abs_time_diff/60)) minutes)"
                        else
                            log_message "✅ Scheduled renewal time reached! ($renewal_hour)"
                        fi
                        # For scheduled renewals, skip emergency renewal check
                        skip_emergency_check=true
                        break
                    fi
                done
                
                # Emergency renewal if ccusage shows very low time
                # BUT not during the blackout period (start_time - 5 hours) to start_time
                if [ -z "$should_renew" ] || [ "$should_renew" = false ]; then
                    # Get the hour from the original start time
                    start_hour=$(date -d "@$start_epoch" +%H 2>/dev/null || date -r "$start_epoch" +%H)
                    start_minute=$(date -d "@$start_epoch" +%M 2>/dev/null || date -r "$start_epoch" +%M)
                    
                    # Get current date at midnight
                    current_date=$(date +%Y-%m-%d)
                    
                    # Calculate today's start time
                    today_start_epoch=$(date -d "$current_date $start_hour:$start_minute:00" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$current_date $start_hour:$start_minute:00" +%s)
                    
                    # If we're already past today's start time, check tomorrow's blackout
                    if [ $current_epoch -ge $today_start_epoch ]; then
                        tomorrow_start=$((today_start_epoch + 86400))
                        blackout_start=$((tomorrow_start - 18000))
                        blackout_end=$tomorrow_start
                    else
                        blackout_start=$((today_start_epoch - 18000))
                        blackout_end=$today_start_epoch
                    fi
                    
                    # Only do emergency renewal if NOT in blackout period
                    if [ $current_epoch -lt $blackout_start ] || [ $current_epoch -ge $blackout_end ]; then
                        minutes_remaining=$(get_minutes_until_reset)
                        if [ -n "$minutes_remaining" ] && [ "$minutes_remaining" -gt 0 ] && [ "$minutes_remaining" -le 2 ]; then
                            should_renew=true
                            log_message "⚠️ Emergency renewal - only $minutes_remaining minutes remaining!"
                        fi
                    else
                        # We're in blackout period, log warning but don't renew
                        minutes_remaining=$(get_minutes_until_reset)
                        if [ -n "$minutes_remaining" ] && [ "$minutes_remaining" -gt 0 ] && [ "$minutes_remaining" -le 10 ]; then
                            log_message "⚠️ Block expiring ($minutes_remaining min) but in blackout period before $(date -d "@$today_start_epoch" +%H:%M 2>/dev/null || date -r "$today_start_epoch" +%H:%M) - NOT renewing"
                        fi
                    fi
                fi
                
                # Fallback: if no activity recorded recently
                if [ ! -f "$LAST_ACTIVITY_FILE" ] && [ $time_since_start -gt 60 ]; then
                    should_renew=true
                    log_message "No recent activity record, starting session..."
                fi
            fi
        else
            # No scheduled time - use ccusage or fallback
            # Get minutes until reset
            minutes_remaining=$(get_minutes_until_reset)
            
            if [ -n "$minutes_remaining" ] && [ "$minutes_remaining" -gt 0 ]; then
                if [ "$minutes_remaining" -le 2 ]; then
                    should_renew=true
                    log_message "Reset imminent ($minutes_remaining minutes), preparing to renew..."
                fi
            else
                # Fallback check when ccusage is not available
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
        fi
        
        # Perform renewal if needed
        if [ "$should_renew" = true ]; then
            # For scheduled renewals, don't wait; for emergency renewals, wait a bit
            if [ "$skip_emergency_check" != true ]; then
                sleep 60
            fi
            
            # Try to start session with retries
            local retry_count=0
            local max_retries=10
            local renewal_success=false
            
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
        if [ -f "$START_TIME_FILE" ]; then
            # Schedule-based sleep calculation
            start_epoch=$(cat "$START_TIME_FILE")
            current_epoch=$(date +%s)
            
            # Get current block time remaining from ccusage if available
            minutes_remaining=$(get_minutes_until_reset)
            if [ -n "$minutes_remaining" ] && [ "$minutes_remaining" -gt 0 ]; then
                log_message "Current block: $minutes_remaining minutes remaining (ccusage)"
            fi
            
            # Calculate next scheduled renewal based on daily schedule
            time_since_start=$((current_epoch - start_epoch))
            
            # If we're past the start time, calculate next interval
            if [ $time_since_start -ge 0 ]; then
                # Get hour of start time
                start_hour=$(date -d "@$start_epoch" +%H 2>/dev/null || date -r "$start_epoch" +%H)
                
                # Calculate today's base epoch (start time today)
                today_start_epoch=$((start_epoch + ((current_epoch - start_epoch) / 86400) * 86400))
                
                # Define the 4 daily renewal times based on start hour
                renewal_1=$today_start_epoch  # e.g., 05:00
                renewal_2=$((today_start_epoch + 18000))  # +5 hours (10:00)
                renewal_3=$((today_start_epoch + 36000))  # +10 hours (15:00)
                renewal_4=$((today_start_epoch + 54000))  # +15 hours (20:00)
                tomorrow_renewal_1=$((today_start_epoch + 86400))  # Next day 05:00
                
                # Find the next renewal time
                if [ $current_epoch -lt $renewal_1 ]; then
                    next_renewal_epoch=$renewal_1
                elif [ $current_epoch -lt $renewal_2 ]; then
                    next_renewal_epoch=$renewal_2
                elif [ $current_epoch -lt $renewal_3 ]; then
                    next_renewal_epoch=$renewal_3
                elif [ $current_epoch -lt $renewal_4 ]; then
                    next_renewal_epoch=$renewal_4
                else
                    # After 20:00, wait for tomorrow's 05:00
                    next_renewal_epoch=$tomorrow_renewal_1
                fi
                
                scheduled_remaining=$((next_renewal_epoch - current_epoch))
                
                # Check if we're in blackout period
                blackout_start=$((today_start_epoch - 18000))  # 5 hours before start
                if [ $current_epoch -ge $today_start_epoch ]; then
                    tomorrow_start=$((today_start_epoch + 86400))
                    blackout_start=$((tomorrow_start - 18000))
                fi
                
                in_blackout=false
                if [ $current_epoch -ge $blackout_start ] && [ $current_epoch -lt $today_start_epoch ]; then
                    in_blackout=true
                fi
                
                # Use the shorter of ccusage time or scheduled time for sleep calculation
                if [ "$in_blackout" = true ]; then
                    # During blackout period, check more frequently when close to start time
                    if [ "$scheduled_remaining" -le 300 ]; then  # 5 minutes before start
                        sleep_duration=60  # 1 minute
                    elif [ "$scheduled_remaining" -le 600 ]; then  # 10 minutes before start
                        sleep_duration=120  # 2 minutes
                    else
                        sleep_duration=1800  # 30 minutes
                    fi
                    log_message "Next scheduled renewal in $((scheduled_remaining/60)) minutes (at $(date -d "@$next_renewal_epoch" +%H:%M 2>/dev/null || date -r "$next_renewal_epoch" +%H:%M)), checking again in $((sleep_duration/60)) minutes (blackout period)"
                # ALWAYS prioritize scheduled renewal times over ccusage
                elif [ "$scheduled_remaining" -le 300 ]; then
                    # Very close to scheduled renewal - check every minute regardless of ccusage
                    sleep_duration=60
                    log_message "Next scheduled renewal in $((scheduled_remaining/60)) minutes (at $(date -d "@$next_renewal_epoch" +%H:%M 2>/dev/null || date -r "$next_renewal_epoch" +%H:%M)), checking again in $((sleep_duration/60)) minutes"
                elif [ -n "$minutes_remaining" ] && [ "$minutes_remaining" -gt 0 ]; then
                    # Use ccusage time if it's less than scheduled time
                    if [ "$minutes_remaining" -lt $((scheduled_remaining / 60)) ]; then
                        # Base sleep duration on ccusage time
                        if [ "$minutes_remaining" -le 3 ]; then
                            sleep_duration=30
                        elif [ "$minutes_remaining" -le 10 ]; then
                            sleep_duration=120
                        elif [ "$minutes_remaining" -le 30 ]; then
                            sleep_duration=300
                        else
                            sleep_duration=1800
                        fi
                        log_message "Next scheduled renewal in $((scheduled_remaining/60)) minutes (at $(date -d "@$next_renewal_epoch" +%H:%M 2>/dev/null || date -r "$next_renewal_epoch" +%H:%M)), checking again in $((sleep_duration/60)) minutes (based on ccusage)"
                    else
                        # Base sleep duration on scheduled time
                        if [ "$scheduled_remaining" -le 300 ]; then  # 5 minutes
                            sleep_duration=60  # 1 minute
                        elif [ "$scheduled_remaining" -le 600 ]; then  # 10 minutes
                            sleep_duration=120  # 2 minutes
                        elif [ "$scheduled_remaining" -le 1800 ]; then  # 30 minutes
                            sleep_duration=300  # 5 minutes
                        else
                            sleep_duration=1800  # 30 minutes max
                        fi
                        log_message "Next scheduled renewal in $((scheduled_remaining/60)) minutes (at $(date -d "@$next_renewal_epoch" +%H:%M 2>/dev/null || date -r "$next_renewal_epoch" +%H:%M)), checking again in $((sleep_duration/60)) minutes"
                    fi
                else
                    # No ccusage data, use scheduled time only
                    if [ "$scheduled_remaining" -le 300 ]; then  # 5 minutes
                        sleep_duration=60  # 1 minute
                    elif [ "$scheduled_remaining" -le 600 ]; then  # 10 minutes
                        sleep_duration=120  # 2 minutes
                    elif [ "$scheduled_remaining" -le 1800 ]; then  # 30 minutes
                        sleep_duration=300  # 5 minutes
                    else
                        sleep_duration=1800  # 30 minutes max
                    fi
                    log_message "Next scheduled renewal in $((scheduled_remaining/60)) minutes (at $(date -d "@$next_renewal_epoch" +%H:%M 2>/dev/null || date -r "$next_renewal_epoch" +%H:%M)), checking again in $((sleep_duration/60)) minutes"
                fi
            else
                # Waiting for first scheduled renewal
                start_epoch=$(cat "$START_TIME_FILE")
                current_epoch=$(date +%s)
                time_until_start=$((start_epoch - current_epoch))
                
                if [ $time_until_start -gt 0 ]; then
                    if [ $time_until_start -le 60 ]; then
                        sleep_duration=10
                    elif [ $time_until_start -le 600 ]; then
                        sleep_duration=60
                    else
                        sleep_duration=300
                    fi
                    log_message "Scheduled renewal in $((time_until_start/60)) minutes, checking again in $((sleep_duration/60)) minutes"
                else
                    sleep_duration=30  # We might have just missed it, check frequently
                    log_message "Next check in $((sleep_duration/60)) minutes"
                fi
            fi
        else
            # Original logic for non-scheduled mode
            sleep_duration=$(calculate_sleep_duration)
            # Don't call get_minutes_until_reset again - it's already been called
            if [ -n "$minutes_remaining" ] && [ "$minutes_remaining" -gt 0 ]; then
                log_message "Time remaining: $minutes_remaining minutes"
            fi
            log_message "Next check in $((sleep_duration / 60)) minutes"
        fi
        
        # Record when we start sleeping
        local sleep_start=$(date +%s)
        
        # Sleep until next check
        sleep "$sleep_duration"
    done
}

# Start the daemon
main