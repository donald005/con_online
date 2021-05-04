# con_online
<p style='color:red'>This is some red text.</p>
## <font color="red">新开CT主机，需要修改DNS以适合更多的场景 opdins And CNNIC</font>

##### #######################Start################################
```bash
sed -i '/#DNS=/c\DNS= 208.67.222.222' /etc/systemd/resolved.conf
sed -i '/#FallbackDNS=/c\FallbackDNS=1.2.4.8' /etc/systemd/resolved.conf
sudo systemctl daemon-reload
sudo systemctl restart systemd-resolved.service
sudo mv /etc/resolv.conf /etc/resolv.conf.bak
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
```
##### #######################END################################

##  优化Tmux的设置
### Tmux Config Install tmux first：
```bash
wget --no-check-certificate https://raw.githubusercontent.com/donald005/con_online/master/.tmux.conf && chmod +666 .tmux.conf
wget --no-check-certificate https://raw.githubusercontent.com/donald005/con_online/master/tdonal.sh && chmod +x tdonal.sh
```
####  **生效需要**
##### reboot

