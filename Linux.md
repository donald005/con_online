## 1. 删除N天前文件

#######################Start################################    
```bash
find 路径 -mtime +天数 -type f -name "文件名" -exec rm -rf {} ;
find . +10 -type d #当前目录下10天前文件夹
find /tmp -mtime +30 -type f -name "*" -exec rm -rf {} \;
/tmp --设置查找的目录；
-mtime +30 --设置修改时间为30天前；
-type f --设置查找的类型为文件；其中f为文件，d则为文件夹
-name "*" --设置文件名称，可以使用通配符；
-exec rm -rf --查找完毕后执行删除操作；
 {} \; --固定写法
```
#######################END################################    
## 2. 查看空间

df -hl  #磁盘空间  
du -sh  #目录空间  
## 3. 清理空间
    
```bash

#!/bin/bash
# execute sql stat
times = ("43200" "14400" "7200" "1440" "720")
for time in ${times[@]};do
    free_ratio=`df | grep '/$'| awk '{print $(NF-1)}' | awk -F'%' '{print $1}'`
    if((free_ratio>90)); then
        echo "开始清理，$(date "+%Y-%m-%d %H:%M:%S")占用率$free_ratio%"
        `find /root/program/ttnode/.yfnode/cache -type d -cmin +$time | xargs rm -rf`
        echo "清理距离现在$(expr $time / 1440)天数据后，$(date "+%Y-%m-%d %H:%M:%S")占用率$free_ratio%"
    else
        echo "暂不清理，$(date "+%Y-%m-%d %H:%M:%S")占用率$free_ratio%"
        break
    fi
done
```

