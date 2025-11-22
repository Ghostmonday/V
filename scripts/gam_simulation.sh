#!/bin/bash

# Global Access Mode (GAM) Network Simulation Script
# Usage: ./gam_simulation.sh [mode]
# Modes: firewall, bad_wifi, high_latency, reset

MODE=$1
ANCHOR="com.apple/gam_test"

function reset_network() {
    echo "Resetting network conditions..."
    sudo dnctl -f flush
    sudo pfctl -a $ANCHOR -F all
    echo "Network reset complete."
}

function setup_firewall() {
    echo "Simulating Corporate Firewall (Blocking UDP ports 50000-60000)..."
    reset_network
    
    # Create a dummynet pipe that drops everything (bandwidth 0)
    sudo dnctl pipe 1 config bw 0bit/s
    
    # Route UDP traffic to the drop pipe
    # Note: Adjust ports if your LiveKit server uses a different range
    echo "dummynet in quick proto udp from any to any port 50000-60000 pipe 1" | sudo pfctl -a $ANCHOR -f -
    
    echo "UDP Block active. GAM should fallback to TCP/TLS."
}

function setup_bad_wifi() {
    echo "Simulating Bad WiFi (20% Packet Loss, 100ms Jitter)..."
    reset_network
    
    # Configure pipe with packet loss and delay
    sudo dnctl pipe 1 config plr 0.20 delay 50ms 100ms
    
    # Apply to all traffic (or specific ports if preferred)
    echo "dummynet in quick proto udp from any to any pipe 1" | sudo pfctl -a $ANCHOR -f -
    echo "dummynet in quick proto tcp from any to any pipe 1" | sudo pfctl -a $ANCHOR -f -
    
    echo "Bad WiFi simulation active."
}

function setup_high_latency() {
    echo "Simulating High Latency (600ms RTT)..."
    reset_network
    
    # Configure pipe with 300ms delay (one way)
    sudo dnctl pipe 1 config delay 300ms
    
    # Apply to all traffic
    echo "dummynet in quick proto udp from any to any pipe 1" | sudo pfctl -a $ANCHOR -f -
    echo "dummynet in quick proto tcp from any to any pipe 1" | sudo pfctl -a $ANCHOR -f -
    
    echo "High Latency simulation active."
}

# Main Execution
case "$MODE" in
    "firewall")
        setup_firewall
        ;;
    "bad_wifi")
        setup_bad_wifi
        ;;
    "high_latency")
        setup_high_latency
        ;;
    "reset")
        reset_network
        ;;
    *)
        echo "Usage: $0 {firewall|bad_wifi|high_latency|reset}"
        echo "  firewall: Blocks UDP ports 50000-60000"
        echo "  bad_wifi: Adds 20% packet loss and jitter"
        echo "  high_latency: Adds 600ms RTT latency"
        echo "  reset: Clears all simulations"
        exit 1
        ;;
esac
