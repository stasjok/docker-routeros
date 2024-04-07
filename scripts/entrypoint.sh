#!/usr/bin/env bash

case ${0##*/} in
entrypoint_with_four_interfaces.sh)
   number_of_interfaces=4
   ;;
entrypoint_for_docker_8interfaces.sh)
   number_of_interfaces=8
   ;;
*)
   number_of_interfaces=${NUM_INTERFACES:-1}
   ;;
esac

QEMU_BRIDGE_PREFIX=qemubr

# DHCPD must have an IP address to run, but that address doesn't have to
# be valid. This is the dummy address dhcpd is configured to use.
DUMMY_DHCPD_IP='10.0.0.1'

# The name of the dhcpd config file we make
DHCPD_CONF_FILE='/routeros/dhcpd.conf'

# First step, we run the things that need to happen before we start mucking
# with the interfaces. We start by generating the DHCPD config file based
# on our current address/routes. We "steal" the container's IP, and lease
# it to the VM once it starts up.
/routeros/generate-dhcpd-conf.py ${QEMU_BRIDGE_PREFIX}1 >$DHCPD_CONF_FILE

function prepare_intf() {
   #First we clear out the IP address and route
   ip addr flush dev $1
   # Next, we create our bridge, and add our container interface to it.
   ip link add $2 type bridge
   ip link set dev $1 master $2
   # Then, we toggle the interface and the bridge to make sure everything is up
   # and running.
   ip link set dev $1 up
   ip link set dev $2 up
}

prepare_qemu_ifup_script() {
   local bridge=$1
   local path="$HOME/qemu_ifup_$bridge"

   echo "#!/usr/bin/env bash" >"$path"
   echo "ip link set dev \$1 up" >>"$path"
   echo "ip link set dev \$1 master $bridge" >>"$path"
   chmod +x "$path"

   echo "$path"
}

prepare_qemu_ifdown_script() {
   local bridge=$1
   local path="$HOME/qemu_ifdown_$bridge"

   echo "#!/usr/bin/env bash" >"$path"
   echo "ip link set dev \$1 nomaster" >>"$path"
   echo "ip link set dev \$1 down" >>"$path"
   chmod +x "$path"

   echo "$path"
}

# Prepare network interfaces
nic_opts=()
for ((i = 1; i <= number_of_interfaces; i++)); do
   qemu_bridge="qemubr$i"
   dev="eth$((i - 1))"
   qemu_id="qemu$i"
   qemu_ifup=$(prepare_qemu_ifup_script "$qemu_bridge")
   qemu_ifdown=$(prepare_qemu_ifdown_script "$qemu_bridge")
   mac="54:05:AB:CD:12:3$i"

   prepare_intf "$dev" "$qemu_bridge"
   nic_opts+=(-nic "tap,id=${qemu_id},mac=$mac,script=$qemu_ifup,downscript=$qemu_ifdown")
done

# Finally, start our DHCPD server
udhcpd -I $DUMMY_DHCPD_IP -f $DHCPD_CONF_FILE &

kvm_opts=()
if [ -e /dev/kvm ] && grep -q -e vmx -e svm /proc/cpuinfo; then
   echo "Enabling KVM"
   kvm_opts+=(-cpu "host,kvm=on" -machine accel=kvm -enable-kvm)
else
   echo "KVM not available, running in emulation mode. This will be slow."
fi

# And run the VM! A brief explanation of the options here:
# -enable-kvm: Use KVM for this VM (much faster for our case).
# -nographic: disable SDL graphics.
# -serial mon:stdio: use "monitored stdio" as our serial output.
# -nic: Use a TAP interface with our custom up/down scripts.
# -drive: The VM image we're booting.
# mac: Set up your own interfaces mac addresses here, cause from winbox you can not change these later.
exec qemu-system-x86_64 \
   -serial mon:stdio \
   -nographic \
   -m 512 \
   -smp "${NUM_CPU:-$(nproc)}" \
   "${kvm_opts[@]}" \
   "${nic_opts[@]}" \
   "$@" \
   -hda $ROUTEROS_IMAGE
