#!/bin/sh

side=1
lower_iface=enp0s25

if [ "$1" = "vxlan" ]; then 
	vxlan=1
elif [ "$1" = "batman" ]; then 
	vxlan=1
	batman=1
elif [ "$1" = "cleanup" ]; then
	cleanup_only=1
fi

set -x

# cleanup
if [ "${side}" -eq 1 ]; then
	test -d /sys/class/net/bat-test1 && ip link del bat-test1
	test -d /sys/class/net/mesh-vpn1 && ip link del mesh-vpn1
	test -d /sys/class/net/wgtest1 && ip link del wgtest1
	if ip address show ${lower_iface} | grep 192.168.122.1; then
		ip addr del 192.168.122.1/24 dev ${lower_iface}
	fi
else
	test -d /sys/class/net/wgtest2 && ip link del wgtest2
	test -d /sys/class/net/mesh-vpn2 && ip link del mesh-vpn2
	test -d /sys/class/net/bat-test2 && ip link del bat-test2
	if ip address show ${lower_iface} | grep 192.168.122.2; then
		ip addr del 192.168.122.2/24 dev ${lower_iface}
	fi
fi

if [ "$cleanup_only" = 1 ]; then
	exit 0
fi

set -e

PRIV_KEY1="eHv2ZoAgJTD1B+XdtHwrhAlatiRWDVhH70MDHOFwwEU="
PUB_KEY1=`echo "$PRIV_KEY1" | wg pubkey`
PRIV_KEY2="cJAUU/ox+gyW5C3Gw69tkexwKJY2i7Gbrv77I/bzZVA="
PUB_KEY2=`echo "$PRIV_KEY2" | wg pubkey`

if [ "${side}" = 1 ]; then
	ip addr add 192.168.232.1/24 dev ${lower_iface}

	ip link add wgtest1 type wireguard
	echo -n "$PRIV_KEY1" | wg set wgtest1 private-key /proc/self/fd/0
	wg set wgtest1 listen-port 52821 peer $PUB_KEY2 allowed-ips "192.168.121.0/24,fe80::/64" endpoint 192.168.232.2:52822
	ip link set wgtest1 up
	ip a a fe80::1/64 dev wgtest1
else
	ip addr add 192.168.232.2/24 dev ${lower_iface}

	ip link add wgtest2 type wireguard
	echo -n "$PRIV_KEY2" | wg set wgtest2 private-key /proc/self/fd/0
	wg set wgtest2 listen-port 52822 peer $PUB_KEY1 allowed-ips "192.168.121.0/24,fe80::/64" endpoint 192.168.232.1:52821
	ip link set wgtest2 up
	ip a a fe80::2/64 dev wgtest2
fi

topif=wgtest

if [ "$vxlan" = 1 ]; then
	if [ "${side}" = 1 ]; then
		ip link add mesh-vpn1 type vxlan id "1337" \
			local fe80::1 remote fe80::2 dev wgtest1 dstport 4750 udp6zerocsumtx udp6zerocsumrx
		ip link set mesh-vpn1 up
	else
		ip link add mesh-vpn2 type vxlan id "1337" \
			local fe80::2 remote fe80::1 dev wgtest2 dstport 4750 udp6zerocsumtx udp6zerocsumrx
		ip link set mesh-vpn2 up
	fi

	topif=mesh-vpn

	if [ "$batman" = 1 ]; then
		if [ "${side}" = 1 ]; then
			batctl -m bat-test1 if add mesh-vpn1
			ip link set mtu 1280 bat-test1 up
		else
			batctl -m bat-test2 if add mesh-vpn2
			ip link set mtu 1280 bat-test2 up
		fi

		topif=bat-test
	fi
fi

if [ "${side}" = 1 ]; then
	ip a a 192.168.121.1/24 dev ${topif}1
else
	ip a a 192.168.121.2/24 dev ${topif}2
fi
set +x
echo SUCCESS!
