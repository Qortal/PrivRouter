#!/bin/bash

if (( $EUID != 0 )); then
  echo "This must be run as root. Type in 'sudo bash $0' to run it as root."
  exit 1
fi

echo "$(tput setaf 2)                          
                   ..         
                  ,:          
          .      ::           
          .:    :2.           
           .:,  1L            
            .v: Z, ..::,      
             :k:N.Lv:         
              22ukL           
              JSYk.$(tput bold ; tput setaf 7)           
             ,B@B@i           
             BO@@B@.          
           :B@L@Bv:@7         
         .PB@iBB@  .@Mi       
       .P@B@iE@@r  . 7B@i     
      5@@B@:NB@1$(tput setaf 5) r  ri:$(tput bold ; tput setaf 7)7@M    
    .@B@BG.OB@B$(tput setaf 5)  ,.. .i, $(tput bold ; tput setaf 7)MB,  
    @B@BO.B@@B$(tput setaf 5)  i7777,    $(tput bold ; tput setaf 7)MB. 
   PB@B@.OB@BE$(tput setaf 5)  LririL,.L. $(tput bold ; tput setaf 7)@P 
   B@B@5iB@B@i$(tput setaf 5)  :77r7L, L7 $(tput bold ; tput setaf 7)O@ 
   @B1B27@B@B,$(tput setaf 5) . .:ii.  r7 $(tput bold ; tput setaf 7)BB 
   O@.@M:B@B@:$(tput setaf 5) v7:    ::.  $(tput bold ; tput setaf 7)BM 
   :Br7@L5B@BO$(tput setaf 5) irL: :v7L. $(tput bold ; tput setaf 7)P@, 
    7@,Y@UqB@B7$(tput setaf 5) ir ,L;r: $(tput bold ; tput setaf 7)u@7  
     r@LiBMBB@Bu$(tput setaf 5)   rr:.$(tput bold ; tput setaf 7):B@i   
       FNL1NB@@@@:   ;OBX     
         rLu2ZB@B@@XqG7$(tput sgr0 ; tput setaf 2)      
            . rJuv::          
                             
            $(tput setaf 2)PRD

"

echo "$(tput setaf 6)This script will auto-setup PRD for you.$(tput sgr0)"

echo "Tor - configure your Pi into a TOR proxy."

echo "This script will auto-setup a Tor proxy for you. It is recommend that you run this script on a fresh installation of Brooklyn."

read -p "Press [Enter] key to begin.." pause

DEFAULT_IP_ADDRESS="192.168.42.1"
DEFAULT_SSID="PRD"
DEFAULT_WPA2="dmax911e"
DEFAULT_CHANNEL="6"

# read -p "Enter the IP Address you wish to assign to your RaspTor <${IP_ADDRESS}> :" IP_ADDRESS

read -p "Enter your desired WLAN SSID [${DEFAULT_SSID}] :" SSID

read -p "Enter your desired WPA2 key [${DEFAULT_WPA2}] :" WPA2

read -p "Enter your desired WLAN radio channel [${DEFAULT_CHANNEL}] :" CHANNEL

# Set up default variables
IP_ADDRESS=$DEFAULT_IP_ADDRESS
SSID="${SSID:-$DEFAULT_SSID}"
WPA2="${WPA2:-$DEFAULT_WPA2}"
CHANNEL="${CHANNEL:-$DEFAULT_CHANNEL}"

/bin/echo "Updating package index.."
/usr/bin/apt-get update -y

/bin/echo "Removing Wolfram Alpha Enginer due to bug. More info:
http://www.raspberrypi.org/phpBB3/viewtopic.php?f=66&t=68263"
/usr/bin/apt-get remove -y wolfram-engine

/bin/echo "Updating out-of-date packages.."
/usr/bin/apt-get upgrade -y

/bin/echo "Downloading and installing hostapd , DHCP server and Tor itself.."
/usr/bin/apt-get install -y hostapd isc-dhcp-server tor 

# DHCP
/bin/echo "Configuring DHCP.."
cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.sample
/bin/cat /dev/null > /etc/dhcp/dhcpd.conf
/bin/cat <<dhcp_configuration >> /etc/dhcp/dhcpd.conf
ddns-update-style none;
default-lease-time 600;
max-lease-time 7200;
authoritative;
log-facility local7;

subnet 192.168.42.0 netmask 255.255.255.0 {
range 192.168.42.10 192.168.42.50;
option broadcast-address 192.168.42.255;
option routers 192.168.42.1;
default-lease-time 600;
max-lease-time 7200;
option domain-name "local";
option domain-name-servers 208.67.222.222, 208.67.220.220;
}
dhcp_configuration

cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.sample
/bin/cat /dev/null > /etc/default/isc-dhcp-server
/bin/cat <<isc_dhcp_configuration >> /etc/default/isc-dhcp-server
INTERFACES="wlan0"
isc_dhcp_configuration

/bin/echo "Configuring Interfaces.."

cp /etc/network/interfaces /etc/network/interfaces.sample
/bin/cat /dev/null > /etc/network/interfaces
/bin/cat <<interfaces_configuration >> /etc/network/interfaces
auto lo

iface lo inet loopback
iface eth0 inet dhcp

allow-hotplug wlan0
iface wlan0 inet static
  address ${IP_ADDRESS}
  netmask 255.255.255.0

up iptables-restore < /etc/iptables.ipv4.nat

interfaces_configuration

sudo ifconfig wlan0 $IP_ADDRESS

/bin/echo "Configuring hostapd.."
cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.sample
/bin/cat /dev/null > /etc/hostapd/hostapd.conf
/bin/cat <<hostapd_configuration >> /etc/hostapd/hostapd.conf
interface=wlan0
driver=nl80211
ssid=${SSID}
hw_mode=g
channel=${CHANNEL}
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=${WPA2}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
hostapd_configuration

cp /etc/default/hostapd /etc/default/hostapd.sample
/bin/cat /dev/null > /etc/default/hostapd
/bin/cat <<hostapd_default >> /etc/default/hostapd
DAEMON_CONF="/etc/hostapd/hostapd.conf"
hostapd_default

/bin/echo "Configuring NAT and Routing.."
cp /etc/sysctl.conf /etc/sysctl.conf.sample
/bin/cat /dev/null > /etc/sysctl.conf
/bin/cat <<sysctl_configuration >> /etc/sysctl.conf
vm.swappiness=1
vm.min_free_kbytes = 8192
net.ipv4.ip_forward=1
sysctl_configuration

/bin/echo "Set up routing tables.."
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"

/bin/echo "Registering daemons as a service.."
sudo service hostapd start
sudo service isc-dhcp-server start
sudo update-rc.d hostapd enable
sudo update-rc.d isc-dhcp-server enable


/bin/echo "Configuring Tor.."
/bin/cat /dev/null > /etc/tor/torrc_tmp
/bin/cat <<tor_configuration_tmp >> /etc/tor/torrc_tmp
Log notice file /var/log/tor/notices.log
VirtualAddrNetwork 10.192.0.0/10
AutomapHostsSuffixes .onion,.exit
AutomapHostsOnResolve 1
TransPort 9040
TransListenAddress ${IP_ADDRESS}
DNSPort 53
DNSListenAddress ${IP_ADDRESS}
tor_configuration_tmp

/bin/cat /etc/tor/torcc >> /etc/tor/torrc_tmp
/bin/cat /etc/tor/torrc_tmp > /etc/tor/torrc

/bin/echo "Configuring routing tables to redirect TCP traffic through TOR.."
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 22 -j REDIRECT --to-ports 22
sudo iptables -t nat -A PREROUTING -i wlan0 -p udp --dport 53 -j REDIRECT --to-ports 53
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --syn -j REDIRECT --to-ports 9040

sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"


/bin/echo "Enabling TOR to start on boot.."
sudo update-rc.d tor enable

/bin/echo "Installation complete! Reboot once if it does not work for you immediately.."

exit