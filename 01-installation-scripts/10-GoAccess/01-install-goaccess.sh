#!/bin/bash 

# 定义变量
version=1.4
src_dir=00src00

# GeoIP2需要从 MaxMind 下载 城市/国家 数据库，并通过 --geoip-database 设定。
# 如果使用 GeoIP，则不用下载数据库。
# MaxMind官网：https://dev.maxmind.com/geoip/geoip2/geolite2/
# 必须注册登录下载，注册登录后，进入自己的账号界面，有下载链接
#
# 使用 GeoIP2 的话，需要安装依赖库
# wget https://github.com/maxmind/libmaxminddb/releases/download/1.4.3/libmaxminddb-1.4.3.tar.gz
# tar xf libmaxminddb-1.4.3.tar.gz
# cd libmaxminddb-1.4.3
# ./configure
# make
# make install
# sh -c "echo /usr/local/lib  >> /etc/ld.so.conf.d/local.conf"
# ldconfig


# 解压
function untar_tgz(){
    echo -e "\033[32m[+] 解压 $1 中\033[0m"
    tar xf $1
    if [ $? -ne 0 ];then
        echo -e "\033[31m[*] 解压出错，请检查!\033[0m"
        exit 2
    fi
}

# 首先判断当前目录是否有压缩包：
#   I. 如果有压缩包，那么就在当前目录解压；
#   II.如果没有压缩包，那么就检查有没有 ${openssh_source_dir} 表示的目录;
#       1) 如果有目录，那么检查有没有压缩包
#           ① 有压缩包就解压
#           ② 没有压缩包则下载压缩包
#       2) 如果没有,那么就创建这个目录，然后 cd 到目录中，然后下载压缩包，然
#       后解压
# 解压的步骤都在后面，故此处只做下载

# 语法： download_tar_gz 文件名 保存的目录 下载链接
# 使用示例： download_tar_gz openssl-1.1.1h.tar.gz /data/openssh-update https://mirrors.cloud.tencent.com/openssl/source/openssl-1.1.1h.tar.gz
function download_tar_gz(){
    back_dir=$(pwd)
    file_in_the_dir=''  # 这个目录是后面编译目录的父目录

    ls $1 &> /dev/null
    if [ $? -ne 0 ];then
        # 进入此处表示脚本所在目录没有压缩包
        ls -d $2 &> /dev/null
        if [ $? -ne 0 ];then
            # 进入此处表示没有${openssh_source_dir}目录
            mkdir -p $2 && cd $2
            echo -e "\033[32m[+] 下载源码包 $1 至 $(pwd)/\033[0m"
            wget $3
            file_in_the_dir=$(pwd)
            # 返回脚本所在目录，这样这个函数才可以多次使用
            cd ${back_dir}
        else
            # 进入此处表示有${openssh_source_dir}目录
            cd $2
            ls $1 &> /dev/null
            if [ $? -ne 0 ];then
            # 进入此处表示${openssh_source_dir}目录内没有压缩包
                echo -e "\033[32m[+] 下载源码包 $1 至 $(pwd)/\033[0m"
                wget $3
                file_in_the_dir=$(pwd)
                cd ${back_dir}
            else
                # 进入此处，表示${openssh_source_dir}目录内有压缩包
                echo -e "\033[32m[!] 发现压缩包$(pwd)/$1\033[0m"
                file_in_the_dir=$(pwd)
                cd ${back_dir}
            fi
        fi
    else
        # 进入此处表示脚本所在目录有压缩包
        echo -e "\033[32m[!] 发现压缩包$(pwd)/$1\033[0m"
        file_in_the_dir=$(pwd)
    fi
}

download_tar_gz goaccess-${version}.tar.gz ${src_dir} https://tar.goaccess.io/goaccess-${version}.tar.gz
cd ${file_in_the_dir}
untar_tgz goaccess-${version}.tar.gz


echo -e "\033[32m[+] 检查编译环境\033[0m"
yum install -y openssl-devel GeoIP-devel ncurses-devel epel-release gcc

echo -e "\033[32m[>] 编译 goaccess\033[0m"
cd goaccess-${version}
#./configure --enable-utf8 --enable-geoip=mmdb --with-openssl --with-getline --enable-tcb=memhash
./configure --enable-utf8 --enable-geoip=legacy --with-getline --enable-tcb=memhash

# 配置多核编译
assumeused=$(w | grep 'load average' | awk -F': ' '{print $2}' | awk -F'.' '{print $1}')
cpucores=$(cat /proc/cpuinfo | grep -c processor)
compilecore=$(($cpucores - $assumeused - 1))
if [ $compilecore -ge 1 ];then
    make -j $compilecore && make -j $compilecore install
    if [ $? -ne 0 ];then
        echo -e "\n\033[31m[*] 编译出错，请检查脚本\033[0m\n"
        exit 1
    fi
else
    make && make install
    if [ $? -ne 0 ];then
        echo -e "\n\033[31m[*] 编译出错，请检查脚本\033[0m\n"
        exit 1
    fi
fi

echo -e "\033[36m\n[+] 设置配置文件 为 nginx 日志分析模式\033[0m"
sed -i 's@^#time-format %H:%M:%S@time-format %H:%M:%S@' /usr/local/etc/goaccess/goaccess.conf
sed -i 's@^#date-format %d/%b/%Y@date-format %d/%b/%Y@' /usr/local/etc/goaccess/goaccess.conf
sed -i 's@#log-format COMBINED@log-format COMBINED@' /usr/local/etc/goaccess/goaccess.conf

echo -e "\033[32m\n[>] goaccess 已编译安装成功，详细信息如下：\033[0m"
echo -e -n "\033[33m"
echo "配置文件路径：/usr/local/etc/goaccess/goaccess.conf"
goaccess -V
echo 
echo "设置输出html为中文："
echo -e "\033[36mexport LANG=zh_CN.UTF-8\033[33m"
echo "用法举例："
echo -e "\033[36mgoaccess -a -g -f yourlogfile -o output.html\033[0m\n"