#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 <action> [options]"
    echo "Actions:"
    echo "  up      Bring up CAN interfaces"
    echo "  down    Bring down CAN interfaces"
    echo "Options:"
    echo "  -b <bitrate>      Set the bitrate (default: 125000)"
    echo "  -i <interface>    Specify the CAN interface (default: all interfaces)"
    echo "  -q <txqueuelen>   Set the txqueuelen (default: 1000)"
    exit 1
}

# Function to bring up a CAN interface with a specified bitrate and txqueuelen
bring_up_can_interface() {
    local interface=$1
    local bitrate=$2
    local txqueuelen=$3

    # Check if the interface is already up
    if ip link show $interface | grep -q "<.*UP.*>"; then
        echo "CAN interface $interface is already up. Bringing it down to reset."
        sudo ip link set down $interface
    fi

    sudo ip link set $interface type can bitrate $bitrate
    sudo ip link set $interface txqueuelen $txqueuelen
    sudo ip link set up $interface
    echo "CAN interface $interface is up with a bitrate of $bitrate and txqueuelen of $txqueuelen"
}

# Function to bring down a CAN interface
bring_down_can_interface() {
    local interface=$1
    sudo ip link set down $interface
    echo "CAN interface $interface is down"
}

# List of allowed bitrates for CAN2.0
ALLOWED_BITRATES=(50000 125000 250000 500000 800000 1000000)

# Default values
BITRATE=125000
TXQUEUELEN=1000
CAN_INTERFACE=""

# Check if no arguments are provided
if [ "$#" -eq 0 ]; then
    usage
fi

# Validate action
ACTION=$1
if [[ "$ACTION" != "up" && "$ACTION" != "down" ]]; then
    echo "Error: Action must be 'up' or 'down'."
    usage
fi
shift

# Parse options
while getopts ":b:i:q:" opt; do
    case ${opt} in
        b )
            BITRATE=$OPTARG
            ;;
        i )
            CAN_INTERFACE=$OPTARG
            ;;
        q )
            TXQUEUELEN=$OPTARG
            ;;
        \? )
            echo "Invalid option: -$OPTARG" 1>&2
            usage
            ;;
        : )
            echo "Option -$OPTARG requires an argument" 1>&2
            usage
            ;;
    esac
done
shift $((OPTIND -1))

# Validate remaining arguments
if [[ "$#" -gt 0 ]]; then
    echo "Error: Invalid arguments: $@"
    usage
fi

# Validate bitrate if action is 'up'
if [[ "$ACTION" == "up" ]]; then
    if ! [[ "$BITRATE" =~ ^[0-9]+$ ]]; then
        echo "Error: Bitrate must be a number."
        usage
    fi
    if [[ ! " ${ALLOWED_BITRATES[@]} " =~ " ${BITRATE} " ]]; then
        echo "Error: Bitrate $BITRATE is not allowed. Allowed bitrates are: ${ALLOWED_BITRATES[*]}"
        usage
    fi
fi

# Perform the specified action
if [ "$ACTION" == "up" ]; then
    # If no CAN interface is specified, bring up all CAN interfaces
    if [ -z "$CAN_INTERFACE" ]; then
        for interface in $(ls /sys/class/net | grep can); do
            bring_up_can_interface $interface $BITRATE $TXQUEUELEN
        done
    else
        bring_up_can_interface $CAN_INTERFACE $BITRATE $TXQUEUELEN
    fi
elif [ "$ACTION" == "down" ]; then
    # If no CAN interface is specified, bring down all CAN interfaces
    if [ -z "$CAN_INTERFACE" ]; then
        for interface in $(ls /sys/class/net | grep can); do
            bring_down_can_interface $interface
        done
    else
        bring_down_can_interface $CAN_INTERFACE
    fi
fi
