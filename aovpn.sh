#!/bin/bash
# Automated OpenVPN install script
# Tested on Debian 5, 6, and Ubuntu 10.04, Ubuntu 10.10, Ubuntu 12.04"
# 2013 v1.0
# Author Freek - Based upon the work of Denis D.and Commander Waffles
# http://bluemodule.com/software/openvpn-install-script-for-openvz-vps/
# http://www.putdispenserhere.com/openvpn-debianubuntu-setup-script-for-openvz/
# http://www.VPSwiki.net & http://www.freek.ws

if [ "$(whoami)" != "root" ] ; then
echo "You must be root to execute this script."
exit 1
fi

echo "################################################"
echo "Automated OpenVPN Install Script"
echo "by Freek - http://www.Freek.ws"
echo
echo "Should work on various deb-based Linux distros."
echo "Tested on Debian 5, 6, and Ubuntu 10.04, Ubuntu 10.10, Ubuntu 12.04"
echo
echo "Make sure to message your provider and have them enable"
echo "TUN, IPtables, and NAT modules prior to setting up OpenVPN."
echo
echo "You need to set up the server before creating more client keys."
echo "A separate client keyset is required per connection or machine."
echo "################################################"
echo "Select an option:"
echo "1) Set up new OpenVPN server AND create one client"
echo "2) Create additional clients"
echo "3) Revoke client access"
echo "################################################"
read x
if test $x -eq 1; then

#We need lsb-release to check which distro we're running
#So let's install that now....
apt-get update && apt-get install -y lsb-release

#If running OpenVZ, check if TUN/TAP is(properly) enabled before continuing
echo
echo "######################################################"
echo "Checking if TUN/TAP is properly enabled on OpenVZ...."
echo "######################################################"

case `lscpu` in
*VT-x* )
    if [ -c /dev/net/tun ] ; 
    then echo "TUN/TAP is ENABLED, Continuing"
    else
        mkdir -p /dev/net
        mknod /dev/net/tun c 10 200
        chmod 600 /dev/net/tun
            if [ -c /dev/net/tun ] ; then
                echo TUN/TAP was not setup properly, but now it is. Yay
            else
                echo "TUN/TAP looks DISABLED."
                echo "Please check in SolusVM under 'Settings' if TUN/TAP is Enabled."
                echo "Quitting...."
                exit
            fi
    fi;;
*) echo ;;
esac

#Continue if check above passes
echo "Specify server port number that you want the server to use (eg. 1194 to use OpenVPN defaults or 53 for Captive Portal bypassing - make sure you're not running bind or named):"
read p
echo "Enter client username that you want to create (eg. client1):"
read c

# get the VPS IP
ip=`grep address /etc/network/interfaces | grep -v 127.0.0.1  | awk '{print $2}'`

echo
echo "################################################"
echo "Downloading and Installing OpenVN & Dependencies"
echo "################################################"
echo " "
echo "**** Do you want to install dnsmasq package? - enter Y or N"
read INPUT1
if [[ $INPUT1 == "Y" || $INPUT1 == "y" || $INPUT1 == "YES" || $INPUT1 == "yes" ]]
then

  apt-get install -y openvpn liblzo2-2 libpkcs11-helper1 openvpn-blacklist zip dnsmasq openssl

else

  echo "not installing dnsmasq"
  apt-get install -y openvpn liblzo2-2 libpkcs11-helper1 openvpn-blacklist zip openssl

fi

if [[ $p == "53" ]]
then

  echo "RTFM: You CAN NOT run OpenVPN on port 53 if dnsmasq is going to be installed as well"
  echo "Aborting"
  exit

else

echo
echo "################################################"
echo "Creating Server Config"
echo "\"Common Name\" must be filled."
echo "Please insert : server"
echo "################################################"
cp -R /usr/share/doc/openvpn/examples/easy-rsa/ /etc/openvpn

# creating server.conf file
echo ";local $ip" > /etc/openvpn/server.conf
echo "port $p" >> /etc/openvpn/server.conf
echo "proto udp" >> /etc/openvpn/server.conf
echo "dev tun" >> /etc/openvpn/server.conf
echo "ca /etc/openvpn/keys/ca.crt" >> /etc/openvpn/server.conf
echo "cert /etc/openvpn/keys/server.crt" >> /etc/openvpn/server.conf
echo "key /etc/openvpn/keys/server.key" >> /etc/openvpn/server.conf
echo "dh /etc/openvpn/keys/dh1024.pem" >> /etc/openvpn/server.conf
echo "server 10.8.0.0 255.255.255.0" >> /etc/openvpn/server.conf
echo "ifconfig-pool-persist ipp.txt" >> /etc/openvpn/server.conf
echo "push \"redirect-gateway def1 bypass-dhcp\"" >> /etc/openvpn/server.conf
echo "push \"dhcp-option DNS 10.8.0.1\"" >> /etc/openvpn/server.conf
echo "keepalive 5 30" >> /etc/openvpn/server.conf
echo "comp-lzo" >> /etc/openvpn/server.conf
echo "persist-key" >> /etc/openvpn/server.conf
echo "persist-tun" >> /etc/openvpn/server.conf
echo "status openvpn-status.log" >> /etc/openvpn/server.conf
echo "verb 3" >> /etc/openvpn/server.conf

if [[ $INPUT1 == "Y" || $INPUT1 == "y" || $INPUT1 == "YES" || $INPUT1 == "yes" ]]
then

  #setup DNSMasq
  echo "listen-address=127.0.0.1,10.8.0.1" >> /etc/dnsmasq.conf
  echo "bind-interfaces" >> /etc/dnsmasq.conf
fi
fi

cd /etc/openvpn/easy-rsa/2.0/
. ./vars
./clean-all

echo
echo "################################################"
echo "Building Certifcate Authority"
echo "\"Common Name\" must be filled."
echo "################################################"
./build-ca

echo
echo "################################################"
echo "Building Server Certificate"
echo "\"Common Name\" must be filled."
echo "Please insert : server"
echo "################################################"
./build-key-server server
./build-dh

cp -R /etc/openvpn/easy-rsa/2.0/keys/ /etc/openvpn


echo
echo "################################################"
echo "Starting Server"
echo "################################################"
/etc/init.d/openvpn start
/etc/init.d/dnsmasq restart

echo
echo "################################################"
echo "Forwarding IPv4 and Enabling It On boot"
echo "################################################"
echo 1 > /proc/sys/net/ipv4/ip_forward
# saves ipv4 forwarding and and enables it on-boot
cat >> /etc/sysctl.conf <<END
net.ipv4.ip_forward=1
END
sysctl -p

echo
echo "################################################"
echo "Updating IPtables Routing and Enabling It On boot"
echo "################################################"

# Check platform
if lscpu | grep -i VT-x > /dev/null 2>&1
then
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to $ip
else
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
fi

# saves iptables routing rules and enables them on-boot
iptables-save > /etc/iptables.conf
cat > /etc/network/if-pre-up.d/iptables <<END
#!/bin/sh
iptables-restore < /etc/iptables.conf
END
chmod +x /etc/network/if-pre-up.d/iptables

echo
echo "################################################"
echo "Building certificate for client $c"
echo "\"Common Name\" must be filled."
echo "Please insert like same cert : $c"
echo "################################################"
./build-key $c

echo "client" > /etc/openvpn/keys/$c.ovpn
echo "dev tun" >> /etc/openvpn/keys/$c.ovpn
echo "proto udp" >> /etc/openvpn/keys/$c.ovpn
echo "remote $ip $p" >> /etc/openvpn/keys/$c.ovpn
echo "resolv-retry infinite" >> /etc/openvpn/keys/$c.ovpn
echo "nobind" >> /etc/openvpn/keys/$c.ovpn
echo "persist-key" >> /etc/openvpn/keys/$c.ovpn
echo "persist-tun" >> /etc/openvpn/keys/$c.ovpn
echo "ca ca.crt" >> /etc/openvpn/keys/$c.ovpn
echo "cert $c.crt" >> /etc/openvpn/keys/$c.ovpn
echo "key $c.key" >> /etc/openvpn/keys/$c.ovpn
echo "comp-lzo" >> /etc/openvpn/keys/$c.ovpn
echo "verb 3" >> /etc/openvpn/keys/$c.ovpn

cp /etc/openvpn/easy-rsa/2.0/keys/$c.crt /etc/openvpn/keys
cp /etc/openvpn/easy-rsa/2.0/keys/$c.key /etc/openvpn/keys

cd /etc/openvpn/keys/
zip clientkeys-$c.zip ca.crt $c.crt $c.key $c.ovpn


echo
echo "################################################"
echo "One client keyset for $c generated."
echo "To connect:"
echo "1) Download /etc/openvpn/keys/clientkeys.zip using a client such as WinSCP/FileZilla."
echo "2) Create a folder named VPN in C:\Program Files\OpenVPN\config directory."
echo "3) Extract the contents of clientkeys.zip to the VPN folder."
echo "4) Start openvpn-gui, right click the tray icon and click Connect on your client name."
echo "To generate additonal client keysets, run the script again with option #2."
echo "################################################"


# runs this if option 2 is selected
elif test $x -eq 2; then
	echo "Enter client username that you want to create (eg. client2):"
	read c
	
ip=`grep address /etc/network/interfaces | grep -v 127.0.0.1  | awk '{print $2}'`
p=`grep -n 'port' /etc/openvpn/server.conf | cut -d' ' -f2`

echo
echo "################################################"
echo "Building certificate for client $c"
echo "\"Common Name\" must be filled."
echo "Please insert like same cert : $c"
echo "################################################"
cd /etc/openvpn/easy-rsa/2.0
source ./vars
./vars
./build-key $c

echo "client" > /etc/openvpn/keys/$c.ovpn
echo "dev tun" >> /etc/openvpn/keys/$c.ovpn
echo "proto udp" >> /etc/openvpn/keys/$c.ovpn
echo "remote $ip $p" >> /etc/openvpn/keys/$c.ovpn
echo "resolv-retry infinite" >> /etc/openvpn/keys/$c.ovpn
echo "nobind" >> /etc/openvpn/keys/$c.ovpn
echo "persist-key" >> /etc/openvpn/keys/$c.ovpn
echo "persist-tun" >> /etc/openvpn/keys/$c.ovpn
echo "ca ca.crt" >> /etc/openvpn/keys/$c.ovpn
echo "cert $c.crt" >> /etc/openvpn/keys/$c.ovpn
echo "key $c.key" >> /etc/openvpn/keys/$c.ovpn
echo "comp-lzo" >> /etc/openvpn/keys/$c.ovpn
echo "verb 3" >> /etc/openvpn/keys/$c.ovpn

cp /etc/openvpn/easy-rsa/2.0/keys/$c.crt /etc/openvpn/keys
cp /etc/openvpn/easy-rsa/2.0/keys/$c.key /etc/openvpn/keys

cd /etc/openvpn/keys/
zip clientkeys-$c.zip ca.crt $c.crt $c.key $c.ovpn

echo
echo "################################################"
echo "One client keyset for $c generated."
echo "To connect:"
echo "1) Download /etc/openvpn/keys/clientkeys-$c.zip using a client such as WinSCP/FileZilla."
echo "2) Create a folder named VPN in C:\Program Files\OpenVPN\config directory."
echo "3) Extract the contents of clientkeys-$c.zip to the VPN folder."
echo "4) Start openvpn-gui, right click the tray icon and click Connect on your client name."
echo "################################################"

# runs this if option 3 is selected
elif test $x -eq 3; then
	echo "Enter client username that you want to revoke access (eg. client2):"
	read c
cd /etc/openvpn/easy-rsa/2.0/
 . ./vars
 ./revoke-full $c
cp keys/crl.pem /etc/openvpn/
cd /etc/openvpn/keys 
rm $c.crt $c.key $c.ovpn
mv clientkeys-$c.zip clientkeys-$c-REVOKED.zip

if grep "crl.pem" /etc/openvpn/server.conf
then
    echo
else
    echo "crl-verify /etc/openvpn/crl.pem" >> /etc/openvpn/server.conf
fi

/etc/init.d/openvpn reload
	
echo
echo "################################################"
echo "Access revoked for client $c"
echo "################################################"
	
else
echo "Invalid selection, quitting."
exit
fi
