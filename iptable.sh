#!/bin/sh
#Edit by FuJunyi China LuZhou
#Forwar to 27.donald
#Get ZT ip
#(ip a | grep -A2 ztbpablwcb | awk '/inet/{print $2}'| cut -f 1 -d "/"|awk 'NR==1')
LIP=$(ip a | grep -A1 ztbpablwcb | awk '/inet/{print $2}'| cut -f 1 -d "/")
#Set ipv4 forward 1
sed -i '/net.ipv4.ip_forward=/c\net.ipv4.ip_forward=1' /etc/sysctl.conf
sysctl -p
#Only Tunnel from ZT to 27
sudo iptables -t nat -A PREROUTING -p tcp --dport 3333 -j DNAT --to-destination 10.30.100.27:7626
iptables -t nat -A POSTROUTING -p tcp -d 10.30.100.27 -j SNAT --to-source $LIP
iptables-save > /etc/iptables.rules
echo "#!/bin/bash" > /etc/init.d/donald
echo "### BEGIN INIT INFO" >> /etc/init.d/donald
echo "# Provides:          tuzixini" >> /etc/init.d/donald
echo "# Required-Start:    $local_fs $network" >> /etc/init.d/donald
echo "# Required-Stop:     $local_fs" >> /etc/init.d/donald
echo "# Default-Start:     2 3 4 5" >> /etc/init.d/donald
echo "# Default-Stop:      0 1 6" >> /etc/init.d/donald
echo "# Short-Description: self define auto start" >> /etc/init.d/donald
echo "# Description:       self define auto start" >> /etc/init.d/donald
echo "### END INIT INFO" >> /etc/init.d/donald
echo "iptables-restore < /etc/iptables.rules" >> /etc/init.d/donald
chmod 755 /etc/init.d/donald
update-rc.d donald defaults 90
echo "Complete Establish tunnels from ZT to 27"
exit 0

