#!/bin/bash

# iptables gateway and firewall
# by Mike Stine, 2018

function comment () {
  printf "***($(date +"%H:%M:%S")) $1\n"
}
 
comment "Start"

comment "This script runs at startup through /etc/rc.local"

comment "setting constant variables"
readonly iptbl="/sbin/iptables"

#Firewalls Public Interface to the internet
readonly FW_PUBLIC_INTERFACE="eth0"
readonly FW_PUBLIC_IP="10.111.222.33"

#Firewalls Private Network Gateway Interface & IP
readonly FW_PRIVATE_INTERFACE="eth1"
readonly FW_PRIVATE_IP="192.168.1.1"

readonly DNS1="8.8.8.8"
readonly DNS2="8.4.4.4"

readonly PRIVATE_SUBNET="192.168.0.0/16"

# Create variables for human readible iptables
readonly PRIVATE_COMPUTER_A="192.168.1.64"
readonly PRIVATE_COMPUTER_B="192.168.1.65"

readonly PUBLIC_COMPUTER_A="10.111.222.44"

comment "clearing existing rules"
$iptbl --flush  # Flush all the rules in filter and nat tables
$iptbl --table nat --flush
$iptbl --table mangle --flush
$iptbl --zero
$iptbl --table nat --zero
$iptbl --table mangle --zero
$iptbl --delete-chain # Delete all chains that are not in default filter and nat table
$iptbl --table nat --delete-chain
$iptbl --table mangle --delete-chain

comment "setting default rules"
$iptbl --policy INPUT DROP
$iptbl --policy FORWARD DROP
$iptbl --policy OUTPUT DROP

comment "setting up stateful rules"
$iptbl --append INPUT --match state --state ESTABLISHED,RELATED --jump ACCEPT
$iptbl --append OUTPUT --match state --state ESTABLISHED,RELATED --jump ACCEPT
$iptbl --append FORWARD --match state --state ESTABLISHED,RELATED --jump ACCEPT

comment "setting up natting"
$iptbl --table nat --append POSTROUTING --out-interface $FW_PUBLIC_INTERFACE -j SNAT --to-source $FW_PUBLIC_IP

comment "enable packet forwarding by kernel"
echo 1 > /proc/sys/net/ipv4/ip_forward

comment "allow loopback access"
$iptbl --append INPUT --in-interface lo --jump ACCEPT
$iptbl --append OUTPUT --out-interface lo --jump ACCEPT

comment "allow ping"
$iptbl --append INPUT --protocol icmp --jump ACCEPT
$iptbl --append OUTPUT --protocol icmp --jump ACCEPT
$iptbl --append FORWARD --protocol icmp --jump ACCEPT

comment "allow DNS"
$iptbl --append FORWARD --protocol tcp --dport 53 --jump ACCEPT
$iptbl --append FORWARD --protocol udp --dport 53 --jump ACCEPT

comment "setting individual rules"

comment "Public Network/Internet access for PRIVATE_COMPUTER_A"
$iptbl --append FORWARD --source $PRIVATE_COMPUTER_A --out-interface $FW_PUBLIC_INTERFACE --protocol tcp --match multiport --dports 80,443  --jump ACCEPT

#comment "Public Network/Internet access for ALL Private Computers"
#$iptbl --append FORWARD --source $PRIVATE_SUBNET --jump ACCEPT

comment "Allow SSH from PUBLIC_COMPUTER_A TO PRIVATE Network"
$iptbl --append INPUT --source $PUBLIC_COMPUTER_A --destination $FW_PUBLIC_IP --protocol tcp --dport 22 --jump ACCEPT
$iptbl --append OUTPUT --source $FW_PUBLIC_IP --destination $PUBLIC_COMPUTER_A --protocol tcp --sport 22 --jump ACCEPT

comment "backing up rules"
cp -a "/usr/local/bin/iptables_gateway_and_firewall.sh" "/usr/local/bin/fw_archive/iptables_gateway_and_firewall.sh.bak.$(date +"%Y%m%d-%H%M%S")"

comment "List active iptable rules"
iptables -S

comment "Finished"