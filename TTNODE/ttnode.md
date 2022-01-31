# TTNODE 操作  
## 设置CRONTAB    
```bash
30 5 * * * /root/gram/clean.sh >> /dev/shm/clean.log
0 1 * * 1 rm /dev/shm/clean.log
```
