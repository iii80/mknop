#!/bin/bash

out_dir=out
openwrt_dir=openwrt
boot_dir=/media/boot
rootfs_dir=/media/rootfs

cp_opfiles() {
    echo -e "${green}\n提取OpenWrt ROOTFS...$white"

    [ $loop ] && {
        sudo cp -a $rootfs_dir/* $out_dir/openwrt/
        sudo umount $rootfs_dir
        sudo losetup -d $loop
    }

    sudo chown -R root:root armbian/rootfs/
    sudo cp -a armbian/rootfs/* $out_dir/openwrt/
    sudo sed -i '/FAILSAFE/a\\n\tulimit -n 51200' $out_dir/openwrt/etc/init.d/boot
}

cp2bootimg() {
    echo -e "${green}\n拷贝文件到启动镜像...$white"

    sudo mkdir -p $boot_dir

    sudo mount ${loop}p1 $boot_dir
    sudo mount ${loop}p2 $rootfs_dir

    sudo cp -r armbian/boot/* $boot_dir
    sudo cp -a $out_dir/openwrt/* $rootfs_dir
    
    sync
}

mount_opimg() {
    [ ! -d $rootfs_dir ] && sudo mkdir $rootfs_dir
    [ ! -d $out_dir/openwrt ] && mkdir -p $out_dir/openwrt

    if [ -f $openwrt_dir/*rootfs.tar.gz ]; then
        sudo tar -xzf $openwrt_dir/*rootfs.tar.gz -C $out_dir/openwrt && return
    elif [ -f $openwrt_dir/*ext4-factory.img.gz ]; then
        gzip -d $openwrt_dir/*ext4-factory.img.gz
    elif [ -f $openwrt_dir/*ext4-factory.img ]; then
        [ ]
    else
        echo -e "${red}\nopenwrt目录下不存在固件或固件类型不受支持! " && exit
    fi

    if [ -f $openwrt_dir/*ext4-factory.img ]; then
        loop=$(sudo losetup -P -f --show $openwrt_dir/*ext4-factory.img)
        sudo mount ${loop}p2 $rootfs_dir
        [ $? -ne 0 ] && echo -e "${red}\n挂载OpenWrt镜像失败! " && exit
    else
        echo -e "${red}\nOpenWrt固件解压失败! " && exit
    fi
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
    [ $rootsize ] || rootsize=256

    armbiansize=$(sudo du -hs armbian/rootfs | cut -d "M" -f 1)
    openwrtsize=$(sudo du -hs $out_dir/openwrt | cut -d "M" -f 1)

    toltalszie=$(($armbiansize+$openwrtsize))
    [ $rootsize -lt $toltalszie ] && echo -e "${red}\nROOTFS分区最少需要${toltalszie}M! " && exit

    echo -e "${green}\n生成空镜像(.img)...$white"
    dd if=/dev/zero of="$out_dir/$(date +%Y-%m-%d)-openwrt-n1-auto-generate.img" bs=1M count=$(($rootsize+128)) > /dev/null 2>&1

    echo -e "${green}\n分区...$white"
    echo -e "n\n\n\n\n+128M\nn\n\n\n\n\nw" | fdisk $out_dir/*.img > /dev/null 2>&1
    echo -e "t\n1\ne\nw" | fdisk $out_dir/*.img > /dev/null 2>&1

    echo -e "${green}\n格式化...$white"
    loop=$(sudo losetup -P -f --show $out_dir/*.img)
    if [ $loop ]; then
        sudo mkfs.fat -n "BOOT" -F 16 ${loop}p1 > /dev/null 2>&1
        sudo mkfs.ext4 -L "ROOTFS" -m 0 ${loop}p2 > /dev/null 2>&1
    else
        echo -e "${red}\n格式化失败! " && exit
    fi
}

mk() {
    if [ -d $out_dir ]; then
        sudo rm -rf $out_dir/*
    else
        mkdir $out_dir
    fi

    mount_opimg
    cp_opfiles
    mk_bootimg
    cp2bootimg
    
    umount
    sudo rm -rf $boot_dir
    sudo rm -rf $rootfs_dir
    sudo rm -rf $out_dir/openwrt

    echo -e "${green}\n制作成功, 输出文件夹 --> $out_dir"
}

clean() {
    sudo rm -rf $out_dir/*

    umount
    sudo rm -rf $boot_dir
    sudo rm -rf $rootfs_dir

    echo -e "$green\n清理完成! "
}

export loop

red="\033[31m"
green="\033[32m"
white="\033[0m"

echo -e "\n------ N1一键制作OpenWrt镜像脚本 ------
 版本: 0.2 beta
 作者: tuanqing\n
$green 1.$white 一键制作
$green 2.$white 清理目录
$green 3.$white 退出
"

read -p "请输入数字 [1-3]: " choose
[ $choose ] || choose=1

case $choose in
    1) mk
    ;;
    2) clean
    ;;
    3) exit 0
    ;;
    *) echo -e "${red}\n请输入正确的数字 [1-3]! "
    ;;
esac

