#!/bin/bash

# Copyright (c) 2019, Arm Limited and Contributors. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

# Run the Wifi and Wired tests

# Default to any device

pattern="mbed-linux-os"

while [ "$1" != "" ]; do
    case $1 in
        -v | --venv )   shift
                        # shellcheck source=/dev/null
                        source  "$1"/bin/activate
                        ;;
        -t | --dev )    shift
                        device_type=$1
                        ;;
        -d | --dut )    shift
                        pattern=$1
                        ;;
        * )             echo "Invalid Parameter"
                        exit 1
    esac
    shift
done

# Function to run ping on an interface.
# The interface in in $1, the address to ping in $2 and the expected result 
# in $3
#
run_ping_test()
{
    local test_command="ping -c 1 -I $1 $2"
    local mbl_cli_command="$mbl_cli_shell '$test_command'"
    local expected_result=$3
    local result="not tested"

    if eval "$mbl_cli_command"; then
        result="pass"
        if [ "$expected_result" == "pass" ]; then
            printf "<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=%s-expected-%s RESULT=pass>\n" "${test_command// /-}" "${expected_result// /-}"
        else
            printf "<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=%s-expected-%s RESULT=fail>\n" "${test_command// /-}" "${expected_result// /-}"
            overall_result="fail"
        fi
    else
        result="fail"
        if [ "$expected_result" == "pass" ]; then
            printf "<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=%s-expected-%s RESULT=fail>\n" "${test_command// /-}" "${expected_result// /-}"
            overall_result="fail"
        else
            printf "<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=%s-expected-%s RESULT=pass>\n" "${test_command// /-}" "${expected_result// /-}"
        fi
    fi
    printf "Attempted to ping %s using interface %s. Expected result is %s. Actual result is %s.\n" "$2" "$1" "$3" "$result"
}

# Function to disable an interface
# The interface in in $1
#
disable_interface()
{
    local test_command="su -l -c \"ip link set $1 down\""
    local mbl_cli_command="$mbl_cli_shell '$test_command'"
    eval "$mbl_cli_command"
    # Wait for the interface to be removed and the routing tables etc to be updated
    sleep 30
}

# Run the test

# Find the address of the first device found by the mbl-cli containing the
# pattern
mbl-cli list > device_list
dut_address=$(grep "$pattern" device_list | head -1 | cut -d":" -f3-)

# list the devices for debug
cat device_list

# Tidy up
rm device_list

mbl_cli_shell="mbl-cli -a $dut_address shell"
mbl_command="mbl-cli -a $dut_address"

# Only proceed if a device has been found

if [ -z "$dut_address" ]
then
    printf "ERROR - mbl-cli failed to find MBL device\n"
    printf "<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=wifi-access RESULT=fail>\n"
else

    overall_result="pass"

    if [ "$device_type" !=  "imx7s-warp-mbl" ]
    then
        # Bring down the wired interface
        disable_interface "eth0"
    fi

    # Wait to allow the interface to properly be enabled with a routing tables etc.
    sleep 60

    # Check status
    $mbl_cli_shell 'connmanctl scan wifi'
    $mbl_cli_shell 'connmanctl services'
    $mbl_cli_shell 'su -l -c "ifconfig -a"'
    $mbl_cli_shell 'su -l -c "route"'

    # Check we can ping using the wifi interface, using both forms of addressing.
    run_ping_test "wlan0" "8.8.8.8" "pass"
    run_ping_test "wlan0" "www.google.com" "pass"

    # Swap to the open Network.

    # Disable WiFi
    $mbl_cli_shell 'connmanctl disable wifi'

    # Provide open access configuration
    $mbl_command put /root/.wifi-open-access.config /config/user/connman/wifi-access.config

    # Enable WiFi
    $mbl_cli_shell 'connmanctl enable wifi'

    # Wait for WiFi to be re-enabled and routing tables etc.
    sleep 60

    # Check status
    $mbl_cli_shell 'connmanctl scan wifi'
    $mbl_cli_shell 'connmanctl services'
    $mbl_cli_shell 'su -l -c "ifconfig -a"'
    $mbl_cli_shell 'su -l -c "route"'

    # Check we can ping using the wifi interface, using both forms of addressing.
    run_ping_test "wlan0" "echo.mbedcloudtesting.com" "pass"
    run_ping_test "wlan0" "8.8.8.8" "pass"
    run_ping_test "wlan0" "www.google.com" "pass"

    # Output overall result
    printf "<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=wifi-access RESULT=%s>\n" $overall_result
fi
