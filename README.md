# 自用在线配置（不要问我有什么用）  
      作者：     Donald●Fergus
      适用版本： Ubuntu、Debian
      启用时间： 2021/5/4
      修改时间： 2021/5/4
## 1. 新开CT主机，需要修改DNS以适合更多的场景 openDNS And CNNIC

#######################Start################################    
```bash
sed -i '/#DNS=/c\DNS= 208.67.222.222' /etc/systemd/resolved.conf
sed -i '/#FallbackDNS=/c\FallbackDNS=1.2.4.8' /etc/systemd/resolved.conf
sudo systemctl daemon-reload
sudo systemctl restart systemd-resolved.service
sudo mv /etc/resolv.conf /etc/resolv.conf.bak
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
```
#######################END################################    
验证**DNS**设置是否成功：dig github.com   

##  2.  优化Tmux的设置
Tmux Config need Install tmux first：    
```bash
wget --no-check-certificate https://raw.githubusercontent.com/donald005/con_online/master/.tmux.conf && chmod +666 .tmux.conf
wget --no-check-certificate https://raw.githubusercontent.com/donald005/con_online/master/tdonal.sh && chmod +x tdonal.sh
```
###  2.1  优化Tmux的设置（CDN）
```bash
wget --no-check-certificate https://cdn.jsdelivr.net/gh/donald005/con_online/.tmux.conf && chmod +666 .tmux.conf
wget --no-check-certificate https://cdn.jsdelivr.net/gh/donald005/con_online/tdonal.sh && chmod +x tdonal.sh
```
**生效需要**    
**reboot** 

## 3. Tunnel Forward CT to ZT.27    
**You need to install the ZT main program before using the script**      
```bash
bash <(curl -sSL https://raw.githubusercontent.com/donald005/con_online/master/iptable.sh)
```

## 4. VPS performance test    
```bash
网上多，自己搜索一下
bash <(curl -sSL https://raw.githubusercontent.com/qd201211/Linux-SpeedTest/master/superbench.sh)
```
## 5. VPS to VPS Domestic transfer of VPS    
```bash
sip=
sport=8855
dip=
dport=443
sudo iptables -t nat -A PREROUTING -p tcp --dport $sport -j DNAT --to-destination $dip:$dport
iptables -t nat -A POSTROUTING -p tcp -d $dip -j SNAT --to-source $sip
iptables-save > /etc/iptables.rules
```
## 6. 开关warp    
```bash
开：          
systemctl enable wg-quick@wgcf
systemctl start wg-quick@wgcf

重启
systemctl restart wg-quick@wgcf

关闭：         
systemctl stop wg-quick@wgcf
systemctl disable wg-quick@wgcf
```
## 7. 时间修改    
显示时区        
date -R           
北京时间        
cp /usr/share/zoneinfo/Asia/Shanghai  /etc/localtime        
timedatectl set-timezone Asia/Shanghai            
sudo date -s MM/DD/YY //修改日期        
sudo date -s hh:mm:ss //修改时间        
硬件时间依赖于系统时间
sudo hwclock --systohc  

## 8. 小鸡一键脚本   
```bash
wget -N --no-check-certificate https://raw.githubusercontent.com/xiaoyaoguangshijie/xiaoyao1/master/DDfuhe/DD.sh && chmod +x DD.sh && bash DD.sh  
```
##  END
