#!/bin/bash
# Start the full ProtO-RU Split-7.2 stack
# Usage: run each command in a separate terminal

echo "=== Step 1: Verify Open5GS is running ==="
sudo systemctl is-active open5gs-amfd open5gs-smfd open5gs-upfd open5gs-nrfd

echo ""
echo "=== Step 2: Check veth pair ==="
ip link show veth_du > /dev/null 2>&1 || {
    echo "veth missing, recreating..."
    sudo ip link add veth_du type veth peer name veth_ru
    sudo ip link set veth_du up && sudo ip link set veth_ru up
    sudo ip link set veth_du mtu 9000 && sudo ip link set veth_ru mtu 9000
}
echo "veth_du: $(cat /sys/class/net/veth_du/address)"
echo "veth_ru: $(cat /sys/class/net/veth_ru/address)"

echo ""
echo "=== Ready ==="
echo "Terminal 1: cd ~/oran-stack/ProtO-RU/build/apps/examples/ofh && sudo ./ru_emulator -c ~/proto-ru-configs/ru_emu.yml"
echo "Terminal 2: cd ~/oran-stack/srsRAN/build && sudo ./apps/gnb/gnb -c ~/proto-ru-configs/gnb.yml"
