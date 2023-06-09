# wg_testenv2.sh

This script supports three modes: `wg`, `wg+vxlan` and `wg+vxlan+batman`. In the first mode, it sets only a wireguard tunnel up. In the second mode, it additionally configures a vxlan on top of it. In the third mode, batman is added on top of the stack.

The script always configures the IPs `192.168.122.1` and `192.168.122.2` on the top layer interfaces. So no matter which of the three modes you are using, you can always do iperf3 between the top layers based on these two IPs.

## `wg`

Run `./wg_testenv2.sh`. Then the following interface config is applied:

```mermaid
graph TD
    A --- D(wgtest1)
    D --> E>192.168.122.1, fe80::1]
    B --> C>192.168.232.1]
    B --> D
    A[side1] --- B($lower_iface)
    
    X(LAN) --> B
    X --> G
    
    F[side2] --- G($lower_iface)
    G --> H>192.168.232.2]
    G --> I
    F --- I(wgtest2)
    I --> J>192.168.122.2, fe80::2]

linkStyle 4 stroke-width:0px;
linkStyle 0 stroke-width:0px;
linkStyle 7 stroke-width:0px;
linkStyle 10 stroke-width:0px;

classDef SkipLevel width:0px,text-align:center;
class A,F SkipLevel
```

(The IPs on $lower_iface are also assigned by `wg_testenv2.sh`.)

## `wg+vxlan`

Run `./wg_testenv2.sh vxlan`. Then the following interface config is applied:

``` mermaid
graph TD
    S --> T>192.168.122.1]
    A --- D(wgtest1)
    D --> E>fe80::1]
    B --> C>192.168.232.1]
    B --> D
    A[side1] --- B($lower_iface)
    D --> S(mesh-vpn1/vxlan)
    
    X(LAN) --> B
    X --> G
    
    F[side2] --- G($lower_iface)
    G --> H>192.168.232.2]
    G --> I
    F --- I(wgtest2)
    I --> J>fe80::2]
    I --> K(mesh-vpn2/vxlan)
    K --> L>192.168.122.2]

linkStyle 9 stroke-width:0px;
linkStyle 5 stroke-width:0px;
linkStyle 1 stroke-width:0px;
linkStyle 12 stroke-width:0px;

classDef SkipLevel width:0px,text-align:center;
class A,F SkipLevel
```

(The IPs on $lower_iface are also assigned by `wg_testenv2.sh`.)

## `wg+vxlan+batman`

Run `./wg_testenv2.sh batman`. Then the following interface config is applied:

``` mermaid
graph TD
    S --> S2(bat-test1/batman)
    S2 --> T>192.168.122.1]
    A --- D(wgtest1)
    D --> E>fe80::1]
    B --> C>192.168.232.1]
    B --> D
    A[side1] --- B($lower_iface)
    D --> S(mesh-vpn1/vxlan)
    
    X(LAN) --> B
    X --> G
    
    F[side2] --- G($lower_iface)
    G --> H>192.168.232.2]
    G --> I
    F --- I(wgtest2)
    I --> J>fe80::2]
    I --> K(mesh-vpn2/vxlan)
    K --> K2(bat-test2/batman)
    K2 --> L>192.168.122.2]

linkStyle 2 stroke-width:0px;
linkStyle 6 stroke-width:0px;
linkStyle 10 stroke-width:0px;
linkStyle 13 stroke-width:0px;

classDef SkipLevel width:0px,text-align:center;
class A,F SkipLevel
```

(The IPs on $lower_iface are also assigned by `wg_testenv2.sh`.)

## Performance Testing

You can use the 192.168.122.X ips to do iperf3 on the highest interface level.
```
root@side1 # iperf3 -s 
root@side2 # iperf3 -c 192.168.122.1
```

## Install/Setup

Run these theps on both sides:
- `apt install batctl`
- `apt install wireguard`
- open 4750/udp for vxlan in your ipv6 firewall (if you have a firewall).
- open wg_testenv2.sh and adjust the variables `lower_iface=...` and `side=X` to your needs.
- run `./wg_testenv2.sh ...`

You can always cleanup with:
- `./wg_testenv2.sh cleanup`

## Debugging

### Tcpdump

```
root@side1 # tcpdump -n -i wgtest1
root@side1 # tcpdump -n -i mesh-vpn1
root@side1 # tcpdump -n -i bat-test1
root@side2 # tcpdump -n -i wgtest2
root@side2 # tcpdump -n -i mesh-vpn2
root@side2 # tcpdump -n -i bat-test2
```

### Batman

Observe the TQ of the batman neighbors:

```
root@side1 # batctl -m bat-test1 o
Warning - option -m was deprecated and will be removed in the future
[B.A.T.M.A.N. adv 2022.3, MainIF/MAC: mesh-vpn1/be:e6:02:f7:76:dc (bat-test1/46:44:a0:1a:45:13 BATMAN_IV)]
    Originator        last-seen (#/255) Nexthop           [outgoingIF]
  * 76:ac:92:89:9f:57    0.340s   (147) 76:ac:92:89:9f:57 [ mesh-vpn1]
```