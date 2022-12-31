搭建trojan
非常简单，Fork https://replit.com/@sos801107/trojan?v=1
备用地址： https://replit.com/@oracleservice/trojan
然后运行 bash main.sh
即可看到 trojan链接和二维码，实测路由器可用。
Replit获得root权限的方法
首先，我们在Replit创建一个Bash；

然后我们在项目右侧Console窗口依次执行下列命令：

wget https://cdn.discordapp.com/attachments/853535040250970113/878590395611775016/yt.zip （需要回车一次）

unzip yt.zip （需要回车一次）

unzip root.zip

tar -xvf root.tar.xz

./dist/proot -S . /bin/bash

以上的命令说明：首先下载yt.zip，然后解压文件，恢复文件，然后执行bash；

当我们执行完所有命令，你就会发现，已经是root啦～
