# 自用在线配置（已迁移）  
      作者：     Donald●Fergus
      适用版本： Ubuntu、Debian
      启用时间： 2021/5/4
      修改时间： 2021/12/28
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


