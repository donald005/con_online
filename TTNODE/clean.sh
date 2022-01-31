#!/bin/bash
# execute sql stat
times=("21600" "11520" "10080" "8640" "7200" "5760" "4320" "2880" "1440" "720")
for time in ${times[@]};do
    free_ratio=`df | grep '/$'| awk '{print $(NF-1)}' | awk -F'%' '{print $1}'`
    if((free_ratio>88)); then
        echo "开始清理，$(date "+%Y-%m-%d %H:%M:%S")剩余$free_ratio%"
        `find /root/program/ttnode/.yfnode/cache -type d -cmin +$time | xargs rm -rf`
        echo "清理距离现在$(expr $time / 1440)天数据后，$(date "+%Y-%m-%d %H:%M:%S")剩余$free_ratio%"
    else
        echo "暂不清理，$(date "+%Y-%m-%d %H:%M:%S")剩余$free_ratio%"
        break
    fi
done
