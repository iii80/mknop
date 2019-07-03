# 斐讯N1一键制作OpenWrt镜像脚本

usage:
1. 编译, 不会的可以去 https://github.com/coolsnowwolf/lede <br>
   target可以选"Raspberry Pi 3B/3B+" / "ARMv8 multiplatform" <br>
2. 将编译好的固件放入到"openwrt"目录 <br>
   注意: 固件格式只支持"ext4-factory.img.gz"、"ext4-factory.img"和"rootfs.tar.gz"<br>
3. 执行bash mk.sh, 默认输出路径“out/xxx.img”
4. 写入U盘启动OpenWrt
