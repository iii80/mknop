#!/bin/bash

out_dir=out
openwrt_dir=openwrt
boot_dir=/media/boot
rootfs_dir=/media/rootfs

copy_opfile() {
    echo -e "${green}\n提取OpenWrt ROOTFS...$white"

    df -h | grep $rootfs_dir > /dev/null 2>&1
    [ $? -eq 0 ] && {
        sudo cp -a $rootfs_dir/* $out_dir/openwrt/
        sudo umount $rootfs_dir
        sudo losetup -d $loop
    }

    sudo chown -R root:root armbian/rootfs/
    sudo cp -a armbian/rootfs/* $out_dir/openwrt/
    sudo sed -i '/FAILSAFE/a\\n\tulimit -n 51200' $out_dir/openwrt/etc/init.d/boot
}

copy2bootimg() {
    echo -e "${green}\n复制文件到镜像...$white"

    [ $loop ] && {
        sudo mkdir -p $boot_dir

        sudo mount ${loop}p1 $boot_dir
        sudo mount ${loop}p2 $rootfs_dir

        sudo cp -r armbian/boot/* $boot_dir
        sudo cp -a $out_dir/openwrt/* $rootfs_dir
        
        sync
    }
}

mount_opimg() {
    [ ! -d $out_dir/openwrt ] && mkdir -p $out_dir/openwrt
    [ ! -d $rootfs_dir ] && sudo mkdir $rootfs_dir

    if [ -f $openwrt_dir/*.tar.gz ]; then
        tar -xzf $openwrt_dir/*.tar.gz -C $out_dir/openwrt && return
    elif [ -f $openwrt_dir/*.gz ]; then
        gzip -d $openwrt_dir/*.gz
    elif [ -f $openwrt_dir/*.img ]; then
        test
    else
        echo -e "${red}\noopenwrt目录下不存在固件或固件类型不受支持！" && exit
    fi

    [ -f $openwrt_dir/*.img ] && {
        loop=$(sudo losetup -P -f --show $openwrt_dir/*.img)
        sudo mount ${loop}p2 $rootfs_dir
        [ $? -ne 0 ] && echo -e "${red}\n挂载OpenWrt镜像失败！" && exit
    }
}

umount() {
    df -h | grep $boot_dir > /dev/null 2>&1
    [ $? -eq 0 ] && sudo umount $boot_dir

    df -h | grep $rootfs_dir > /dev/null 2>&1
    [ $? -eq 0 ] && sudo umount $rootfs_dir

    [ $loop ] && sudo losetup -d $loop
}

mk_bootimg() {
    echo && read -p "请输入ROOTFS分区大小(单位MB)，默认256M: " rootsize
    [ ! $rootsize ] && rootsize=256

    armbiansize=$(sudo du -hs armbian/rootfs | cut -d "M" -f 1)
    openwrtsize=$(sudo du -hs $out_dir/openwrt | cut -d "M" -f 1)

    toltalszie=$(($armbiansize+$openwrtsize))
    [ $rootsize -lt $toltalszie ] && echo -e "${red}\nROOTFS分区最少需要${toltalszie}M! " && exit

    echo -e "${green}\n生成空image镜像...$white"
    dd if=/dev/zero of="$out_dir/$(date +%Y-%m-%d)-openwrt-n1 automake.img" bs=1M count=$(($rootsize+128)) > /dev/null 2>&1

    echo -e "${green}\n分区...$white"
    echo -e "n\n\n\n\n+128M\nn\n\n\n\n\nw" | fdisk $out_dir/*.img > /dev/null 2>&1
    echo -e "t\n1\ne\nw" | fdisk $out_dir/*.img > /dev/null 2>&1

    echo -e "${green}\n格式化...$white"
    loop=$(sudo losetup -P -f --show $out_dir/*.img)
    sudo mkfs.fat -n "BOOT" -F 16 ${loop}p1 > /dev/null 2>&1
    sudo mkfs.ext4 -m 0 -L "ROOTFS" ${loop}p2 > /dev/null 2>&1
    #sudo losetup -d $loop
}

mk() {
    if [ -d $out_dir ]; then
        sudo rm -rf $out_dir/*
    else
        mkdir $out_dir
    fi

    mount_opimg
    copy_opfile
    mk_bootimg
    copy2bootimg
    
    umount
    sudo rm -rf $boot_dir
    sudo rm -rf $rootfs_dir
    sudo rm -rf $out_dir/openwrt

    echo -e "${green}\n制作成功，输出文件夹: $out_dir"
}

clean() {
    [ -d $out_dir ] && sudo rm -rf $out_dir/*

    umount

    [ -d $boot_dir ] && sudo rm -rf $boot_dir
    [ -d $rootfs_dir ] && sudo rm -rf $rootfs_dir

    echo -e "$green\n清理完成！"
}

export loop

green="\033[32m"
red="\033[31m"
white="\033[0m"

echo 
echo -e "------ N1一键制作OpenWrt镜像脚本 ------
 版本: 0.1 beta
 作者: tuanqing\n
$green 1.$white 一键制作
$green 2.$white 清理目录
$green 3.$white 退出
"

read -p "请输入数字 [1-3]: " choose

case $choose in
    1) mk
    ;;
    2) clean 0
    ;;
    3) exit 0
    ;;
    *) echo "请输入正确的数字 [1-3]"
    ;;
esac

