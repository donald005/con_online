#!/bin/sh
#Edit by FuJunyi China LuZhou
#Created  : 2021 May 04
#Forwar to 27.donald
#Get ZT ip
#(ip a | grep -A2 ztbpablwcb | awk '/inet/{print $2}'| cut -f 1 -d "/"|awk 'NR==1')
DIP=10.30.100.27
#ip a | grep -A1 ztbpablwcb | awk '/inet/{print $2}'| cut -f 1 -d "/"
LIP=$(ip a | grep ztbpablwcb | awk '/inet/{print $2}'| cut -f 1 -d "/")
#Set ipv4 forward 1
sed -i '/net.ipv4.ip_forward=/c\net.ipv4.ip_forward=1' /etc/sysctl.conf
sysctl -p
#Only Tunnel from ZT to 27
sudo iptables -t nat -A PREROUTING -p tcp --dport 3333 -j DNAT --to-destination $DIP:7626
iptables -t nat -A POSTROUTING -p tcp -d $DIP -j SNAT --to-source $LIP
#Save rules
iptables-save > /etc/iptables.rules
#Modify Restore config
echo '#!/bin/bash' > /etc/init.d/donald
echo "### BEGIN INIT INFO" >> /etc/init.d/donald
echo "# Provides:          DFergus" >> /etc/init.d/donald
echo "# Required-Start:    $local_fs $network" >> /etc/init.d/donald
echo "# Required-Stop:     $local_fs" >> /etc/init.d/donald
echo "# Default-Start:     2 3 4 5" >> /etc/init.d/donald
echo "# Default-Stop:      0 1 6" >> /etc/init.d/donald
echo "# Short-Description: self define auto start" >> /etc/init.d/donald
echo "# Description:       self define auto start" >> /etc/init.d/donald
echo "### END INIT INFO" >> /etc/init.d/donald
echo "iptables-restore < /etc/iptables.rules" >> /etc/init.d/donald
chmod 755 /etc/init.d/donald
#Update rc Start item
update-rc.d donald defaults 90
echo "Complete Establish tunnels from ZT to 27"
exit 0

