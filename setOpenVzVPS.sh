#!/bin/bash

# ---------------------------------------------------
#    1. 创建: 2016-11-21 by yingshf
#    2. 脚本仅适用于Centos7.2_X64
# ---------------------------------------------------

# 添加yum库
echo -e "\n正在检查是否已配置epel源......"
if [ ! -f "/etc/yum.repos.d/epel.repo" ]; then
    echo -e "\n未找到epel源，现在开始安装......"
    yum install epel-release -y >/dev/null 2>&1 || error_exit "yum添加库失败,退出！！"
fi

# 关闭SELinux
echo -e "\n正在检查是否已关闭SELinux......"
CHECKSEL=$(grep SELINUX= /etc/selinux/config | grep -v "#")
if [ "$CHECKSEL" == "SELINUX=enforcing" ]; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
fi

# 修复sysctl
cp /sbin/sysctl /sbin/sysctl.bak
rm -f /sbin/sysctl
ln -s /bin/true /sbin/sysctl

# 由于该脚本依赖于wget,所以需要首先安装wget
if ! [ -x "$(command -v wget)" ]; then
    echo -e "\n由于该脚本依赖wget,所以需要安装它.正在安装wget,请耐心等待......"
    yum install wget -y >/dev/null 2>&1 || error_exit "yum安装wget失败,退出！！"
fi

# 取公网IP
VPSIP=$(curl -s -4 icanhazip.com)
if [[ "$IP" = "" ]]; then
    VPSIP=`curl -s -4 ipinfo.io/ip`
fi

# 常量定义
INFO_PATH="/usr/src/scripts"
INFO_FILE="/usr/src/scripts/dymotd"
PROFILE_FILE="/etc/profile"


FTP_CONF_DIR="/etc/vsftpd/vconf"
FTP_VUSER="myftp"
FTP_VUSER_PASSWD="Abcd,1234"
FTP_HOME_DIR="/home/vsftpd/"
FTP_DATA_DIR=""
FTP_SRV_CONF="/etc/vsftpd/vsftpd.conf"
FTP_VIRUSER_FILE="/etc/vsftpd/virtusers"
FTP_PAM="/etc/pam.d/vsftpd"


SS_PORT="8388"
SS_PASSWORD="Abcd,1234"
SS_PROFILE="/etc/shadowsocks-libev/config.json"
SS_FIREWALLD_CONF="/etc/firewalld/services/shadowsocks.xml"


SQ_USER="myhttp"
SQ_PORT="3128"
SQ_PASSWD="Abcd,1234"
SQ_PASSWD_DIR="/etc/squid3/"
SQ_CONF="/etc/squid/squid.conf"
SQ_FIREWALLD_CONF="/etc/firewalld/services/squid.xml"

MARIADB_PORT="3306"
MARIADB_YUM_REPO="/etc/yum.repos.d/MariaDB.repo"
MARIADB_BASE="/opt/mariadb10.1"
MARIADB_SERVER_CNF="/etc/my.cnf.d/server.cnf"

MONGODB_PORT="27017"
MONGODB_YUM_REPO="/etc/yum.repos.d/mongodb-org-3.4.repo"
MONGODB_PID="/usr/lib/systemd/system/mongod.service"
MONGODB_CNF="/etc/mongod.conf"
MONGODB_BASE="/opt/mongodb3.4"


SSH_FOLDER="/root/.ssh/"
AUTHORIZED_KEYS="/root/.ssh/authorized_keys"
SSH_CONFIG="/etc/ssh/sshd_config"

# 功能函数定义
# ---------------------------------------------------
#   0. delayedStart : 延时启动
#  22. checkSys     : 检查系统是否为Centos7
#  33. getVPSIP     : 获取VPSIP地址
#  99. error_exit   : 错误退出
# ---------------------------------------------------
delayedStart() {
    IFS=''
    echo -e "$1请确认您的选择,程序将于10秒后开始执行,立即执行请按回车[ENTER],取消请按Ctrl+C"
    for (( i=10; i>0; i--)); do
        printf "\rStarting in $i seconds..."
        read -s -N 1 -t 1 key

        if [ "$key" == $'\x0a' ] ;then
            break
        fi
    done
}

error_exit() {
    echo -e "\n$1" 1>&2
    exit 99
}

checkSys() {
    release=""
    # release
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    fi
    # version
    if [[ -s /etc/redhat-release ]]; then
        version=`grep -oE  "[0-9.]+" /etc/redhat-release`
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
    
    main_ver=${version%%.*}

    if [ "$main_ver" != "7" ]||[ "$release" != "centos" ]; then
        echo "您的系统不是Centos7,脚本将退出!"
        exit 99
    fi
}
# ---------------------------------------------------
#   1. modifyLoinInfo : 添加终端登录提示信息
# ---------------------------------------------------
modifyLoinInfo() {
    echo -e "\n开始执行,请耐心等待..."
    
    if [ `rpm -qa | grep figlet |wc -l` -eq 0 ]; then
        echo -e "\n正在安装figlet,请耐心等待....."
        wget ftp://ftp.pbone.net/mirror/ftp.freshrpms.net/pub/freshrpms/pub/dag/redhat/el5/en/x86_64/dries/RPMS/figlet-2.2.2-1.el5.rf.x86_64.rpm >/dev/null 2>&1 || error_exit "wget下载rpm失败,退出"
        rpm -ivh figlet-2.2.2-1.el5.rf.x86_64.rpm >/dev/null 2>&1 || error_exit "rpm安装figlet失败,退出!!"
        rm -rf figlet-2.2.2-1.el5.rf.x86_64.rpm
    fi
    
    echo -e "\n正在创建相关目录和文件,请耐心等待......"
    if [ ! -d "$INFO_PATH" ]; then
        mkdir -p $INFO_PATH
    fi
    
    if [ ! -f "$INFO_FILE" ]; then
        touch $INFO_FILE
        chmod +x $INFO_FILE
    else
        mv $INFO_FILE $INFO_FILE"_bak"
        touch $INFO_FILE
        chmod +x $INFO_FILE
    fi
    
    cd /usr/src
    
    # According to your actual situation to be modified
    cat << 'EOF' > $INFO_FILE
    #!/bin/bash
    
    USER=`whoami`   
    HOSTNAME=`uname -n`
    
    DISK=`df -h / | awk '{print $2}' | tr -d '\n'`
    ROOT=`df -h / | awk '{print $4}' | tr -d '\n'`
    MEMORY=`free -m | grep "Mem" | awk '{print $2,"-",$3,"-",$4}'`
    SWAP=`free -m | grep "Swap" | awk '{print $2,"-",$3,"-",$4}'`
    PSA=`ps -Afl | wc -l`
    # time of day
    HOUR=$(date +"%H")
    if [ $HOUR -lt 12  -a $HOUR -ge 0 ]
    then    TIME="morning"
    elif [ $HOUR -lt 17 -a $HOUR -ge 12 ] 
    then    TIME="afternoon"
    else 
        TIME="evening"
    fi
    #System uptime
    uptime=`cat /proc/uptime | cut -f1 -d.`
    upDays=$((uptime/60/60/24))
    upHours=$((uptime/60/60%24))
    upMins=$((uptime/60%60))
    upSecs=$((uptime%60))
    #System load
    LOAD1=`cat /proc/loadavg | awk {'print $1'}`
    LOAD5=`cat /proc/loadavg | awk {'print $2'}`
    LOAD15=`cat /proc/loadavg | awk {'print $3'}`
    figlet $(hostname)
    printf "\n"
    echo -e "\e[7m                         --- Good $TIME $USER ---                         \e[0m"
    COLOR_COLUMN="\e[1m-"
    COLOR_VALUE="\e[31m"
    RESET_COLORS="\e[0m"
    echo -e "
    ===========================================================================   
     $COLOR_COLUMN- Hostname$RESET_COLORS............: $COLOR_VALUE $HOSTNAME $RESET_COLORS
     $COLOR_COLUMN- Release$RESET_COLORS.............: $COLOR_VALUE `cat /etc/redhat-release` $RESET_COLORS
     $COLOR_COLUMN- Users$RESET_COLORS...............: $COLOR_VALUE Currently `users | wc -w` user(s) logged on $RESET_COLORS 
    =========================================================================== $RESET_COLORS
     $COLOR_COLUMN- Current user$RESET_COLORS........: $COLOR_VALUE $USER $RESET_COLORS
     $COLOR_COLUMN- CPU usage$RESET_COLORS...........: $COLOR_VALUE $LOAD1 - $LOAD5 - $LOAD15 (1-5-15 min) $RESET_COLORS
     $COLOR_COLUMN- Memory used$RESET_COLORS.........: $COLOR_VALUE $MEMORY (total-free-used) $RESET_COLORS
     $COLOR_COLUMN- Swap in use$RESET_COLORS.........: $COLOR_VALUE $SWAP (total-used-free) MB $RESET_COLORS
     $COLOR_COLUMN- Processes$RESET_COLORS...........: $COLOR_VALUE $PSA 个进程正在运行 $RESET_COLORS
     $COLOR_COLUMN- System uptime$RESET_COLORS.......: $COLOR_VALUE $upDays 天 $upHours 小时 $upMins 分钟 $upSecs 秒 $RESET_COLORS
     $COLOR_COLUMN- Disk space All$RESET_COLORS......: $COLOR_VALUE $DISK $RESET_COLORS
     $COLOR_COLUMN- Disk space Avail$RESET_COLORS....: $COLOR_VALUE $ROOT $RESET_COLORS
    ===========================================================================
    "
EOF
    # Delete the 4 spaces at the beginning of the line in "/usr/src/scripts/dymotd"
    #sed -i 's/^....//' $INFO_FILE
    sed -i 's/^[][ ]*//g' $INFO_FILE
    # Add boot
    tail -1 $PROFILE_FILE | grep $INFO_FILE >/dev/null
    if [ $? -ne 0 ]; then
        echo $INFO_FILE >> $PROFILE_FILE
    fi
    # notice
    echo -e "\n已为您自定义登录信息的配置"
    echo -e "\n登录信息放在/usr/src/scripts/dymotd文件中,请自行查看相关内容"
    echo -e "\n登录信息生效放在/etc/profile文件最后一行,系统启动自动加载"
    echo -e "\n如果要取消登录信息,请删除文件/usr/src/scripts/dymotd,并删除/etc/profile最后一行的“/usr/src/scripts/dymotd”"    
}
# 功能函数定义
# ---------------------------------------------------
#   2. installVsftpd : 安装配置Vsftpd
# ---------------------------------------------------
installVsftpd(){
    echo -e "\n开始执行,请耐心等待......"
    
    read -p "请输入想要的ftp账号(直接'回车'则默认为$FTP_VUSER): "
    if [[ "$REPLY" == "" ]];then
        echo -e "\n将为您使用默认账号"$FTP_VUSER
    else
        FTP_VUSER=$REPLY
        echo -e "\n您输入的账号为："$FTP_VUSER
    fi
    
    read -p "请输入想要的ftp密码(直接'回车'则默认为$FTP_VUSER_PASSWD): "
    if [[ "$REPLY" == "" ]];then
        echo -e "\n将为您使用默认密码"$FTP_VUSER_PASSWD
    else
        FTP_VUSER_PASSWD=$REPLY
        echo -e "\n您输入的密码为："$FTP_VUSER_PASSWD
    fi

    echo -e "\n接下来为您设置相关目录,请输入相关设置..."
    FTP_HOME_DIR="$FTP_HOME_DIR$FTP_VUSER"
    read -p "请输入ftp根目录(直接'回车'则默认为$FTP_HOME_DIR): "
    if [[ "$REPLY" == "" ]];then
        echo -e "\n将为您使用默认目录"$FTP_HOME_DIR
    else
        FTP_HOME_DIR=$REPLY
        echo -e "\n您输入的目录为："$FTP_HOME_DIR
    fi

    FTP_DATA_DIR="$FTP_HOME_DIR/ftpdata"
    read -p "请输入ftp数据目录(直接'回车'则默认为$FTP_DATA_DIR): "
    if [[ "$REPLY" == "" ]];then
        echo -e "\n将为您使用默认目录"$FTP_DATA_DIR
    else
        FTP_DATA_DIR=$REPLY
        echo -e "\n您输入的目录为："$FTP_DATA_DIR
    fi
    # 延时10秒用于确认收集的信息是否正确
    echo -e "\n"
    delayedStart

    echo -e "\n开始通过yum安装vsftpd,请耐心等待......"
    yum -y install vsftpd >/dev/null 2>&1 || error_exit "yum安装vsftpd失败,退出!!"
    yum install -y psmisc net-tools systemd-devel libdb-devel perl-DBI >/dev/null 2>&1 || error_exit "yum安装vsftpd依赖失败,退出!!"
    
    echo -e "\n安装vsftpd成功,正在设置其为开机启动......"
    # 设置vsftpd开机启动
    systemctl enable vsftpd.service

    # 新建系统用户vsftpd,用户目录为/home/vsftpd, 用户登录终端设为/bin/false(即使之不能登录系统)
    echo -e "\n正在为您创建不可终端登录的vsftpd用户......"
    useradd vsftpd -d /home/vsftpd -s /bin/false
    chown vsftpd:vsftpd /home/vsftpd -R

    # 建立FTP数据目录并设置相关权限
    echo -e "\n正在为您创建相关目录并授权......"
    if [ ! -d "$FTP_DATA_DIR" ]; then
        mkdir -p $FTP_DATA_DIR
        # 设置FTP上传文件新增权限，最新的vsftpd要求对主目录不能有写的权限所以ftp为755，主目录下面的子目录再设置777权限
        # 以后新增子目录记得授权777
        chmod -R 755 $FTP_HOME_DIR
        chmod -R 777 $FTP_DATA_DIR
    fi

    # 建立虚拟用户个人Vsftp的配置文件和子账号FTP权限
    echo -e "\n正在为您创建配置文件并设置FTP账号权限......"
    if [ ! -d "$FTP_CONF_DIR" ]; then
        mkdir -p $FTP_CONF_DIR
        cd $FTP_CONF_DIR
        # 创建虚拟用户配置文件
        touch $FTP_VUSER
        # 添加配置项
        cat << EOF > $FTP_VUSER
        local_root=$FTP_DATA_DIR
        write_enable=YES
        anon_world_readable_only=NO
        anon_upload_enable=YES
        anon_mkdir_write_enable=YES
        anon_other_write_enable=YES
        allow_writeable_chroot=YES
EOF
    # Delete the 8 spaces
    sed -i 's/^[][ ]*//g' $FTP_VUSER
    fi

    # 配置ftp服务的相关参数
    cp $FTP_SRV_CONF $FTP_SRV_CONF-bak
    sed -i "s/anonymous_enable=YES/anonymous_enable=NO/g" $FTP_SRV_CONF
    sed -i "s/#anon_upload_enable=YES/anon_upload_enable=NO/g" $FTP_SRV_CONF
    sed -i "s/#anon_mkdir_write_enable=YES/anon_mkdir_write_enable=YES/g" $FTP_SRV_CONF
    sed -i "s/#chown_uploads=YES/chown_uploads=NO/g" $FTP_SRV_CONF
    sed -i "s/#async_abor_enable=YES/async_abor_enable=YES/g" $FTP_SRV_CONF
    sed -i "s/#ascii_upload_enable=YES/ascii_upload_enable=YES/g" $FTP_SRV_CONF
    sed -i "s/#ascii_download_enable=YES/ascii_download_enable=YES/g" $FTP_SRV_CONF
    sed -i "s/#ftpd_banner=Welcome to blah FTP service./ftpd_banner=Welcome to Codecore FTP./g" $FTP_SRV_CONF
    echo -e "use_localtime=YES\nlisten_port=21\nchroot_local_user=YES\nidle_session_timeout=300
    \ndata_connection_timeout=1\nguest_enable=YES\nguest_username=vsftpd
    \nuser_config_dir=/etc/vsftpd/vconf\nvirtual_use_local_privs=YES
    \npasv_min_port=10060\npasv_max_port=10090
    \naccept_timeout=5\nconnect_timeout=1" >> $FTP_SRV_CONF
    
    # 生成虚拟用户的数据库文件
    touch $FTP_VIRUSER_FILE
    echo -e "$FTP_VUSER\n$FTP_VUSER_PASSWD" >> $FTP_VIRUSER_FILE
    db_load -T -t hash -f $FTP_VIRUSER_FILE $FTP_VIRUSER_FILE.db
    chmod 600 $FTP_VIRUSER_FILE.db

    # 在/etc/pam.d/vsftpd的文件头部加入以下信息(在后面加入无效),需要先注释掉该文件的所有配置
    cp $FTP_PAM $FTP_PAM-bak
    sed -i 's/^[^#]/#&/' $FTP_PAM # 给所有未注释的行添加注释
    # 由于$FTP_VIRUSER_FILE中含有“/”,所以使用#
    sed -i "1s#^#account sufficient /lib64/security/pam_userdb.so db=$FTP_VIRUSER_FILE\n&#" $FTP_PAM
    sed -i "1s#^#auth    sufficient /lib64/security/pam_userdb.so db=$FTP_VIRUSER_FILE\n&#" $FTP_PAM

    #重启vsftpd服务
    systemctl restart vsftpd.service

    # notice
    echo -e "\n已为您完成Vsftpd的安装和配置(随系统自启停)"
    echo -e "\nVsftpd用户名密码为:$FTP_VUSER/$FTP_VUSER_PASSWD"
    echo -e "\nftp数据目录在$FTP_DATA_DIR,具有读写权限!"
    echo -e "\nftp服务的配置文件在$FTP_SRV_CONF,ftp用户的配置文件在$FTP_VUSER,可以根据需要自行修改!"
}
# 功能函数定义
# ---------------------------------------------------
#   3. installBypy     : 安装百度云客户端
# ---------------------------------------------------
installBypy() {
    echo -e "\n正在为您通过pip安装百度云命令行客户端,请耐心等待..."
    yum -y install python python-pip >/dev/null 2>&1 || error_exit "yum安装python和pip失败,退出!!"
    pip install --upgrade pip >/dev/null 2>&1 || error_exit "升级pip失败,退出!!"
    pip install bypy 

    # Add alias
    echo "alias bdup='bypy -v upload'" >> /etc/bashrc
    echo -e "\nbypy安装完成,已为您添加bdup的命令别名,具体可到/etc/bashrc中查看"
    echo -e "\n请执行任意命令,例如bypy info获取授权码,按提示操作即可!"
}
# 功能函数定义
# ---------------------------------------------------
#   4. installSS      : 安装Shadowsocks并添加到系统服务
# ---------------------------------------------------
installSS() {
    echo -e "\n开始执行,请提供以下3项配置信息..."
    
    echo -e "\n您的IP为$VPSIP,如不正确,请输入正确的IP,否则请直接'回车'"
    read -p "请输入Shadowsocks的服务IP(直接'回车'则默认为$VPSIP): "
    if [[ "$REPLY" == "" ]];then
        echo -e "\n将为您使用默认IP:"$VPSIP
    else
        VPSIP=$REPLY
        echo -e "\n您输入的IP为:"$VPSIP
    fi

    read -p "请输入Shadowsocks的服务端口(直接'回车'则默认为$SS_PORT): "
    if [[ "$REPLY" == "" ]];then
        echo -e "\n将为您使用默认端口:"$SS_PORT
    else
        SS_PORT=$REPLY
        echo -e "\n您输入的端口为:"$SS_PORT
    fi

    read -p "请输入Shadowsocks的密码(直接'回车'则默认为$SS_PASSWORD): "
    if [[ "$REPLY" == "" ]];then
        echo -e "\n将为您使用默认密码:"$SS_PASSWORD
    else
        SS_PASSWORD=$REPLY
        echo -e "\n您输入的密码为:"$SS_PASSWORD
    fi
    
    # 延时10秒用于确认收集的信息是否正确
    echo -e "\n"
    delayedStart

    echo -e "\n配置信息收集完成,开始通过yum安装相关依赖..."
    cat << 'EOF' > /etc/yum.repos.d/dnf-stack-el7.repo
    [dnf-stack-el7]
    name=Copr repo fordnf-stack-el7 owned by @rpm-software-management
    baseurl=https://copr-be.cloud.fedoraproject.org/results/@rpm-software-management/dnf-stack-el7/epel-7-\$basearch/
    skip_if_unavailable=True
    gpgcheck=1
    gpgkey=https://copr-be.cloud.fedoraproject.org/results/@rpm-software-management/dnf-stack-el7/pubkey.gpg
    enabled=1
    enabled_metadata=1
EOF
    # Delete the 4 spaces
    sed -i 's/^....//' /etc/yum.repos.d/dnf-stack-el7.repo
    yum install dnf dnf-conf dnf-automatic -y >/dev/null 2>&1 || error_exit "yum安装dnf失败,退出!!"
    dnf install dnf-plugins-core -y >/dev/null 2>&1 || error_exit "dnf安装plugin失败,退出!!"

    echo -e "\n开始通过dnf安装Shadowsocks libev..."
    dnf copr enable librehat/shadowsocks -y
    dnf update -y >/dev/null 2>&1 || error_exit "dnf升级失败,退出!!"
    dnf install shadowsocks-libev -y >/dev/null 2>&1 || error_exit "dnf安装Shadowsocks失败,退出!!"

    echo -e "\n根据收集的信息创建Shadowsocks libev配置文件,该文件位于$SS_PROFILE..."
    # According to your actual situation to be modified
    cat << EOF > $SS_PROFILE
    {    
      "server": "$VPSIP",  
      "server_port": $SS_PORT,
      "local_address":"127.0.0.1",
      "local_port":1080,
      "password": "$SS_PASSWORD",
      "timeout":600,
      "method": "aes-256-cfb"    
    }
EOF
    # Delete the 4 spaces at the beginning of the line in "/etc/shadowsocks.json"
    sed -i 's/^[][ ]*//g' $SS_PROFILE

    # 启用服务
    systemctl start shadowsocks-libev

    # Add alias
    echo "alias sss='systemctl status shadowsocks-libev -l'" >> /etc/bashrc
    echo "alias ssstop='systemctl stop shadowsocks-libev'" >> /etc/bashrc
    echo "alias ssstart='systemctl start shadowsocks-libev'" >> /etc/bashrc
    # notice
    echo -e "\n已为您完成shadowsocks-libev的安装和配置(随系统自启停)"
    echo -e "\nshadowsocks-libev的配置文件为$SS_PROFILE,如有需要,请自行查看或修改相关内容"
    echo -e "\n为您添加了sss,ssstart,ssstop三个命令别名,分别是查看状态,启动,停止.详情请查看/etc/bashrc中的相关定义"
}
# 功能函数定义
# ---------------------------------------------------
#   5. installSQ      : 安装Squid并添加到系统服务
# ---------------------------------------------------
installTR() {
    # 通过yum安装
    echo -e "\n开始通过yum安装Squid......"
    yum -y install squid httpd-tools >/dev/null 2>&1 || error_exit "yum安装Squid失败,退出!!"    

    echo -e "\n安装完成，现在开始收集账号密码信息......"

    read -p "请输入您要设置的Http(s)代理的账号名(直接'回车'则默认为$SQ_USER): "
    if [[ "$REPLY" == "" ]];then
        echo -e "\n将为您使用默认帐号："$SQ_USER
    else
        SQ_USER=$REPLY
        echo -e "\n您输入的帐号为："$SQ_USER
    fi

    # 生成密码文件
    if [ ! -d "$SQ_PASSWD_DIR" ]; then
        mkdir -p $SQ_PASSWD_DIR
    fi
    
    read -p "请输入您要设置的Http(s)代理的密码，注意密码不要超过8位(直接'回车'则默认为$SQ_PASSWD): "
    if [[ "$REPLY" == "" ]];then
        echo -e "\n将为您使用默认密码："$SQ_PASSWD
    else
        SQ_PASSWD=$REPLY
        echo -e "\n您输入的密码为："$SQ_PASSWD
    fi
    # 生成加密的密码文件
    htpasswd -cb /etc/squid3/passwords $SQ_USER $SQ_PASSWD
    
    read -p "请输入您要设置的Http(s)代理的端口号(直接'回车'则默认为$SQ_PORT): "
    if [[ "$REPLY" == "" ]];then
        echo -e "\n将为您使用默认端口"$SQ_PORT
    else
        SQ_PORT=$REPLY
        echo -e "\n您输入的端口为："$SQ_PORT
    fi

    # 修改配置文件
    cp $SQ_CONF $SQ_CONF.bak
    sed -i 's/http_port 3128/#http_port 3128/g' $SQ_CONF 
    cat << EOF >> $SQ_CONF

    auth_param basic program /usr/lib64/squid/basic_ncsa_auth /etc/squid3/passwords
    auth_param basic realm proxy
    acl authenticated proxy_auth REQUIRED
    http_access allow authenticated
    http_port $SQ_PORT
    acl localnet src 0.0.0.1-255.255.255.255
EOF
    # Delete the spaces
    sed -i 's/^[][ ]*//g' $SQ_CONF
    
    systemctl start squid
    
    # Add alias
    echo "alias sqs='systemctl status squid -l'" >> /etc/bashrc
    echo "alias sqstart='systemctl start squid'" >> /etc/bashrc
    echo "alias sqstop='systemctl stop squid'" >> /etc/bashrc
    # notice
    echo -e "\n已为您完成squid的安装和配置(随系统自启停)"
    echo -e "\n为您添加了sqs,sqstart,sqstop三个命令别名,分别是查看状态,启动,停止.详情请查看/etc/bashrc中的相关定义"
}
# 功能函数定义
# ---------------------------------------------------
#   6. installMariaDB   : 安装MariaDB10.1[Stable]
# ---------------------------------------------------
installMariaDB() {
    if [ `rpm -qa | grep MariaDB |wc -l` -ne 0 ]; then
        echo -e "\n系统中已经发现MariaDB,退出!!"
        exit
    fi
    
    # Add YUM
    echo -e "\n正在添加Mariadb的Yum仓库......"
    if [ ! -f "$MARIADB_YUM_REPO" ]; then
        touch $MARIADB_YUM_REPO
    else
        echo -e "\n系统中已经发现MariaDB的YUM仓库,已经为您备份至/etc/yum.repos.d/MariaDB.repo_bak文件中!!"
        mv $MARIADB_YUM_REPO $MARIADB_YUM_REPO"_bak"
        touch $MARIADB_YUM_REPO
    fi

    cat << 'EOF' > $MARIADB_YUM_REPO
    # MariaDB 10.1 CentOS repository list - created 2016-11-24 09:51 UTC
    # http://downloads.mariadb.org/mariadb/repositories/
    [mariadb]
    name = MariaDB
    baseurl = http://yum.mariadb.org/10.1/centos7-amd64
    gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
    gpgcheck=1
EOF
    # Delete the spaces at the beginning of the line in "/etc/yum.repos.d/MariaDB.repo"
    sed -i 's/^....//' $MARIADB_YUM_REPO

    echo -e "\n系统正在通过Yum安装Mariadb 10.1.xx....."
    yum install MariaDB-server MariaDB-client -y >/dev/null 2>&1 || error_exit "安装MariaDB-server和MariaDB-client失败,退出!!"
    echo -e "\nYum安装完成,正在为您创建数据目录并优化配置文件....."
    # mkdir
    mkdir -p $MARIADB_BASE/data
    mkdir -p $MARIADB_BASE/logs
    mkdir -p $MARIADB_BASE/sys_control
    mkdir -p $MARIADB_BASE/share/mysql

    touch $MARIADB_BASE/logs/slow_query.log
    chmod 666 $MARIADB_BASE/logs/slow_query.log
    touch $MARIADB_BASE/logs/mysqld.log
    chmod 666 $MARIADB_BASE/logs/mysqld.log

    chmod 777 $MARIADB_BASE
    chown -R mysql:mysql $MARIADB_BASE

    cp -a /var/lib/mysql/* $MARIADB_BASE/data
    cp -a /usr/share/mysql/* $MARIADB_BASE/share/mysql

    # 收集端口信息
    read -p "请输入您要设置的Mariadb访问端口号(直接'回车'则默认为$MARIADB_PORT): "
    if [[ "$REPLY" == "" ]];then
        echo -e "\n将为您使用默认端口"$MARIADB_PORT
    else
        MARIADB_PORT=$REPLY
        echo -e "\n您输入的端口为："$MARIADB_PORT
    fi

    # config
    sed -i -e '/\[client-server\]/a socket = \/opt\/mariadb10.1\/sys_control\/mysql.sock' /etc/my.cnf
    mv $MARIADB_SERVER_CNF $MARIADB_SERVER_CNF.bak
    touch $MARIADB_SERVER_CNF
    cat << EOF > $MARIADB_SERVER_CNF
    # 本文件主要参考huge.cnf配置文件,可作为伪生产环境配置(内存为1G-2G)
    #  
    # MariaDB 程序会根据运行的操作系统平台查找一系列的配置文件  
    # 要查看有哪些配置文件会被读取到,执行:
    # 'my_print_defaults --help' 并查看
    # Default options are read from the following files in the given order:
    # (--> 程序会依次读取列出的配置文件.) 这部分下面列出的文件(路径)列表.
    # 更多信息请参考: http://dev.mysql.com/doc/mysql/en/option-files.html
    # 
    # 在本文件的各个小节中,你可以使用该程序支持的所有选项.
    # 如果想要了解程序是否支持某个参数  
    # 可以使用  "--help" 选项来启动该程序,查看帮助信息.
    # MySQL server 配置信息
    [mysqld]
    port = $MARIADB_PORT
    socket = $MARIADB_BASE/sys_control/mysql.sock
    # 以下5条与数据库存放目录和相关日志有关(需要提前建好相关目录)
    basedir = $MARIADB_BASE
    datadir=$MARIADB_BASE/data
    pid-file = $MARIADB_BASE/sys_control/mysql.pid
    log-error = $MARIADB_BASE/logs/mysqld.log
    
    open_files_limit = 65535 
    skip-external-locking
    #暂存的连接数量 
    back_log=3000
    #关闭mysql的dns反查功能
    skip-name-resolve
    #将mysqld 进程锁定在内存中
    memlock
    lower_case_table_names = 1
    #查询缓存  (0 = off、1 = on、2 = demand)
    query_cache_type=1
    #收集数据库服务器性能参数
    performance_schema=0
    #连接繁忙阶段（query）起作用
    net_read_timeout=3600
    net_write_timeout=3600
    
    key_buffer_size = 384M
    #通信缓冲大小
    max_allowed_packet = 128M
    #table高速缓存的数量
    table_open_cache = 1024
    #每个connection（session）第一次需要使用这个buffer的时候，一次性分配设置的内存
    sort_buffer_size = 12M
    #顺序读取数据缓冲区使用内存
    read_buffer_size = 8M
    #随机读取数据缓冲区使用内存
    read_rnd_buffer_size = 32M
    #MyISAM表发生变化时重新排序所需的缓冲
    myisam_sort_buffer_size = 64M
    #重新利用保存在缓存中线程的数量
    thread_cache_size = 120
    query_cache_size = 64M
    #Join操作使用内存
    join_buffer_size = 8M
    #批量插入数据缓存大小
    bulk_insert_buffer_size = 32M
    
    #最大连接（用户）数。每个连接MySQL的用户均算作一个连接
    max_connections=1500
    #最大失败连接限制
    max_connect_errors=30
    #服务器关闭交互式连接前等待活动的秒数
    interactive_timeout=600
    #服务器关闭非交互连接之前等待活动的秒数
    wait_timeout=3600
    #慢查询记录日志
    slow_query_log
    #慢查询记录时间10秒
    long_query_time = 10
    #慢查询日志路径
    slow_query_log_file=$MARIADB_BASE/logs/slow_query.log
    
    #使用线程池处理连接
    thread_handling=pool-of-threads
    thread_pool_oversubscribe=30
    thread_pool_size=64
    thread_pool_idle_timeout=7200
    thread_pool_max_threads=2000
      
    # 可以指定一个专用磁盘的路径来作为临时目录,例如 SSD
    #tmpdir     = /tmp/
      
    # 配置此参数则不启动  TCP/IP 端口 监听.
    # 如果所有的处理程序都只在同一台机器上连接 mysqld, 这是一个很安全的做法,
    # 所有同 mysqld 的交互只能通过Unix sockets 或命名管道(named pipes)完成.
    # 注意,使用此选项而没有开启Windows上的命名管道(named pipes),
    # (通过 "enable-named-pipe" 配置项) 将会导致 mysqld 不可用!
    #skip-networking
      
    # 主服务器配置选项 Replication Master Server (default)
    # 在主从复制时,需要依赖二进制日志
    log-bin=mysql-bin
      
    # 在整个主从复制集群中要求是 1 到 2^32 - 1 之间的唯一ID, 否则或者失败,或者大量出错日志信息.  
    # 如果没有设置 master-host,则默认值是 1
    # 但如果省略了,则(master)不生效
    server-id   = 1
      
    # 从服务器配置选项 Replication Slave (需要将 master 部分注释掉,才能使用这部分)  
    #  
    # 要将服务器配置为从属服务器(replication slave),
    # 有如下两种方案可供选择 :
    #  
    # 1) 通过 CHANGE MASTER TO 命令 (在用户手册中有详细的描述) -
    #    语法如下:
    #  
    #    CHANGE MASTER TO MASTER_HOST=<host>, MASTER_PORT=<port>,
    #    MASTER_USER=<user>, MASTER_PASSWORD=<password> ;
    #  
    #    你可以将 <host>, <user>, <password> 替换为单引号括起来的字符串,
    #    将 <port> 替换为 master 的端口号 (默认是 3306).
    #  
    #    一个示例如下所示:
    #  
    #    CHANGE MASTER TO MASTER_HOST='125.564.12.1', MASTER_PORT=3306,
    #    MASTER_USER='joe', MASTER_PASSWORD='secret';
    #  
    # 或者:
    #  
    # 2) 设置下面的参数. 然而, 一旦你选择了这种方式,
    #    首次启动主从复制时 (即便启动复制失败, 如错误的 master-password 密码,
    #    导致 slave 连接不上等), slave 将会创建一个名为 master.info 的文件,
    #    如果以后再修改本配置文件(xxx.cnf)中下面的这些参数, 则将被忽略,
    #    并继续使用 master.info 文件的内容,
    #    除非关闭 slave 服务器, 然后删除文件 master.info 并重新启动 slaver server.
    #    出于这个原因, 你应该不系统修改下面的相关参数参数(带 <> 的注释部分),
    #    而是使用 CHANGE MASTER TO (上面的方案1)
    #   
    #  
    # 在整个主从复制集群中要求是 2 到 2^32 - 1 之间的唯一ID,
    # 否则或者失败,或者大量出错日志信息.
    # 如果设置了 master-host,则默认值是 2  
    # 但如果省略了,则不会成为 slave
    #server-id       = 2
    #  
    # 此slave 需要连接的 master. - required
    #master-host     =   <hostname>
    #  
    # slave连接到 master 认证时需要的 username
    # - 用户名是必须的(也可以在连接时指定)
    #master-user     =   <username>
    #  
    # slave连接到 master 认证时需要的 password
    # - 密码是必须的(也可以在连接时指定)
    #master-password =   <password>
    #  
    # master 监听的端口号
    # 可选 - 默认是 3306
    #master-port     =  <port>
    #  
    # 开启二进制日志, 对于slave从服务器不是必须的,但推荐开启
    #log-bin=mysql-bin
    #  
    # 二进制日志格式 —— 推荐 mixed
    #binlog_format=mixed
      
    # 如果只使用 InnoDB 表, 请取消下列选项的注释
    #innodb_data_home_dir = /var/lib/mysql
    #innodb_data_file_path = ibdata1:2000M;ibdata2:10M:autoextend  
    #innodb_log_group_home_dir = /var/lib/mysql
    # 如果只使用 InnoDB,可以设置 .._buffer_pool_size 为物理内存的 50 - 80 %
    # 谨防内存使用设置得太高
    #innodb_buffer_pool_size = 384M
    # 附加缓存池大小
    #innodb_additional_mem_pool_size = 20M
    # 设置 .._log_file_size 为  buffer pool size 的 25 % 左右
    #innodb_log_file_size = 100M
    # 日志缓存的大小,不要设置太大,1秒钟刷新一次
    #innodb_log_buffer_size = 8M
    # 默认1,事务提交就刷新日志到硬盘;
    # 设为2,刷新到操作系统缓存,但性能提高很多,设为 0 则可能丢事务.
    #innodb_flush_log_at_trx_commit = 1
    # 表死锁的超时释放时间,单位秒
    #innodb_lock_wait_timeout = 50
    
    # 下面这节是数据导入导出的参数  
    [mysqldump]
    # 快速导出到输出流/硬盘,不在内存中缓存
    quick
    # 最大数据包限制
    max_allowed_packet = 16M
      
    [mysql]
    no-auto-rehash
    # 如果对 SQL不熟悉,可以将下面的注释符去掉,拒绝无where的不安全操作.
    #safe-updates
    
    # 下面这节是数据检测恢复工具的参数
    [myisamchk]
    key_buffer_size = 256M
    sort_buffer_size = 256M
    read_buffer = 2M
    write_buffer = 2M
    
    # 下面这节是数据检测恢复工具的参数
    [isamchk]
    key_buffer_size = 256M
    sort_buffer_size = 256M
    read_buffer = 2M
    write_buffer = 2M
    
    # 下面这节是数据库热备的参数
    [mysqlhotcopy]
    interactive-timeout
EOF
    # Delete the 4 spaces at the beginning of the line in "/etc/my.cnf.d/server.cnf"
    sed -i 's/^....//' $MARIADB_SERVER_CNF
    
    systemctl start mariadb

    # set password
    echo -e "\n配置完成,记得端口是$MARIADB_PORT,现在开始为您设置root用户的密码....."
    mysqladmin flush-privileges password 'X]m2&/3m'
    echo -e "\n您的密码已经设置为:X]m2&/3m,请牢记!"
    echo -e "\n接下来需要设置root可以远程登录,请执行:"
    echo -e "\nmysql -uroot -p"
    echo -e "\n输入(或粘贴)刚才设置的密码,进入mysql提示符下执行:"
    echo -e "\nGRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'X]m2&/3m' WITH GRANT OPTION;"
    echo -e "\n然后回车,输入exit退出即可!"
}
# 功能函数定义
# ---------------------------------------------------
#   7. installMongoDB : 安装MongoDB3.4 Community Edition
# ---------------------------------------------------
installMongoDB() {
    echo -e "\n开始执行,即将添加Mongodb3.4的官方YUM库,请耐心等待..."
    if [ ! -f "$MONGODB_YUM_REPO" ]; then
        touch $MONGODB_YUM_REPO
    else
        echo -e "\n系统中已经发现MongoDB的YUM仓库,已经为您备份至/etc/yum.repos.d/mongodb-org-3.4.repo_bak文件中!!"
        mv $MONGODB_YUM_REPO $MONGODB_YUM_REPO"_bak"
        touch $MONGODB_YUM_REPO
    fi
    # Add YUM
    cat << 'EOF' > $MONGODB_YUM_REPO
    [mongodb-org-3.4]
    name=MongoDB Repository
    baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/3.4/x86_64/
    gpgcheck=1
    enabled=1
    gpgkey=https://www.mongodb.org/static/pgp/server-3.4.asc
EOF
    # Delete the 4 spaces at the beginning of the line in "/etc/yum.repos.d/MariaDB.repo"
    sed -i 's/^....//' $MONGODB_YUM_REPO

    echo -e "\n系统正在通过Yum安装MongoDB 3.4 Community Edition....."
    yum install deltarpm -y >/dev/null 2>&1 || error_exit "安装deltarpm失败,退出!!"
    yum install -y mongodb-org >/dev/null 2>&1 || error_exit "安装MongoDB3.4失败,退出!!"
    echo -e "\nYum安装完成,正在为您创建配置数据目录和文件....."
    
    # mkdir
    echo -e "\n正在创建相关目录....."
    mkdir -p $MONGODB_BASE/data
    mkdir -p $MONGODB_BASE/log
    mkdir -p $MONGODB_BASE/sys_control
    
    touch $MONGODB_BASE/log/mongodb.log
    
    chmod 666 $MONGODB_BASE/log/mongodb.log
    chmod 777 $MONGODB_BASE
    chown -R mongod:mongod $MONGODB_BASE

    # 
    echo -e "\n正在创建相关配置文件并设置参数....."
    sed -i 's/PIDFile=\/var\/run\/mongodb\/mongod.pid/PIDFile=\/opt\/mongodb3.4\/sys_control\/mongobd.pid/g' $MONGODB_PID
    systemctl daemon-reload
    mv $MONGODB_CNF $MONGODB_CNF.bak
    touch $MONGODB_CNF
    # 收集端口信息
    read -p "请输入您要设置的Mongodb访问端口号(直接'回车'则默认为$MONGODB_PORT): "
    if [[ "$REPLY" == "" ]];then
        echo -e "\n将为您使用默认端口"$MONGODB_PORT
    else
        MONGODB_PORT=$REPLY
        echo -e "\n您输入的端口为："$MONGODB_PORT
    fi
    
    cat << EOF > $MONGODB_CNF
    # mongod.conf

    # for documentation of all options, see:
    #   http://docs.mongodb.org/manual/reference/configuration-options/
    
    # where to write logging data.
    systemLog:
      destination: file
      logAppend: true
      path: $MONGODB_BASE/log/mongodb.log
    
    # Where and how to store data.
    storage:
      dbPath: $MONGODB_BASE/data
      journal:
        enabled: true
    #  engine:
    #  mmapv1:
    #  wiredTiger:
    
    # how the process runs
    processManagement:
      fork: true
      pidFilePath: $MONGODB_BASE/sys_control/mongobd.pid
    
    # network interfaces
    net:
      port: $MONGODB_PORT
      bindIp: 0.0.0.0
    
    
    #security:
    
    #operationProfiling:
    
    #replication:
    
    #sharding:
    
    ## Enterprise-Only Options
    
    #auditLog:
    
    #snmp:
EOF
    
    # Delete the 4 spaces at the beginning of the line in "/etc/yum.repos.d/MariaDB.repo"
    sed -i 's/^....//' $MONGODB_CNF

    systemctl enable mongod

    # Add alias
    echo "alias mongo='mongo 127.0.0.1:$MONGODB_PORT'" >> /etc/bashrc

    # add .mongorc.js
    echo -e "\n正在为您创建mongorc.js文件,该文件用于mongo shell....."
    touch ~/.mongorc.js
    cat << 'EOF' > ~/.mongorc.js
    var prompt = function ( ) {
      var host = db.getMongo().toString().replace( 'connection to ', '' );
      var database = db.getName();
      return host + '/' + database + '> ';
    }
    DBQuery.prototype._prettyShell = true
EOF
    sed -i 's/^....//' ~/.mongorc.js
    # deal warning
    echo -e "\n正在为您优化系统参数....."
    echo 0 > /proc/sys/vm/zone_reclaim_mode
    sysctl -w vm.zone_reclaim_mode=0
    echo never > /sys/kernel/mm/transparent_hugepage/enabled
    echo never > /sys/kernel/mm/transparent_hugepage/defrag

    cat << 'EOF' >> /etc/rc.local
    if test -f /sys/kernel/mm/transparent_hugepage/khugepaged/defrag; then
      echo 0 > /sys/kernel/mm/transparent_hugepage/khugepaged/defrag
    fi
    if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
      echo never > /sys/kernel/mm/transparent_hugepage/defrag
    fi
    if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
      echo never > /sys/kernel/mm/transparent_hugepage/enabled
    fi
EOF
    sed -i 's/^....//' /etc/rc.local
    chmod +x /etc/rc.d/rc.local
    
    systemctl start mongod
    cat << EOF
以下请人工执行：
# 步骤1. 在mongo shell下执行
use admin
db.createUser(
   {
      user: "root",
      pwd: "X]m2&/3m",
     roles: [ { role: "root", db: "admin" } ]
   }
)

# 步骤2. 修改/etc/bashrc最后一行的mongo别名
mongo --port 6034 -u "root" -p "X]m2&/3m" --authenticationDatabase "admin"

# 步骤3. 修改/etc/mongod.conf
取消security:的注释，并在下面增加authorization: enabled，完整的样子如下：
security:
  authorization: enabled
EOF
}
# 功能函数定义
# ---------------------------------------------------
#   8. setSSHLogin : 配置SSH登录证书
# ---------------------------------------------------
setSSHLogin() {
    echo -e "\n开始配置..."
    
    read -p "请输入形如'ssh-rsa xxx...xxx'的ssh key: "
    SSHKEY=$REPLY
    
    echo -e "\n开始创建相关文件..."
    if [ ! -f "$AUTHORIZED_KEYS" ]; then
        mkdir -p $SSH_FOLDER
        chmod 700 $SSH_FOLDER
        touch $AUTHORIZED_KEYS
        chmod 600 $AUTHORIZED_KEYS
    else
        echo -e "\n已经存在authorized_keys文件,请处理一下,先退出!!"
        exit
    fi
    # Add SSH Certificate
    echo $SSHKEY >> $AUTHORIZED_KEYS
    echo >> $AUTHORIZED_KEYS

    # Edit "/etc/ssh/sshd_config"
    echo -e "\n开始设置证书登录方式..."
    sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' $SSH_CONFIG
    sed -i 's/#StrictModes yes/StrictModes yes/g' $SSH_CONFIG
    sed -i 's/#RSAAuthentication yes/RSAAuthentication yes/g' $SSH_CONFIG
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' $SSH_CONFIG
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' $SSH_CONFIG
    
    # Restart Service
    echo -e "\n重启SSH服务..."
    systemctl restart sshd.service
    echo -e "\n搞定,退出!!"
}
# ---------------------------------------------------
#                     脚本执行入口
# ---------------------------------------------------

# 判断当前用户是否为root
if [[ $EUID -ne 0 ]]; then
    echo "错误: 脚本必须由root用户执行!" 1>&2
    exit 99
fi

# 判断是否为Centos7系统
checkSys

# 接受选项并执行
read_char() {
    SAVESTTY=`stty -g`
    stty raw
    stty -echo
    dd if=/dev/tty bs=1 count=1 2>/dev/null
    stty -raw
    stty echo
    stty $SAVESTTY
}
while :
do
cat <<MAYDAY
-----------------------------------------------------------
            1: 安装Firewalld并添加终端登录提示信息
            2: 安装配置Vsftpd
            3: 安装bypy(百度云客户端)
            4: 安装Shadowsocks-libev(Socket代理)
            5: 安装Squid(Http/Https代理)
            6: 安装MariaDB 10.1.X [Stable]
            7: 安装MongoDB 3.4.X Community Edition
            8: 配置SSH登录证书
            9:退出
-----------------------------------------------------------
MAYDAY
echo  "请按提示选择[1-5]>"
CHOICE=`read_char`
case $CHOICE in
1)
    delayedStart "《安装Firewalld并添加终端登录提示信息》"
    modifyLoinInfo
    exit 1
    ;;
2)
    delayedStart "《安装配置vsftpd》"
    installVsftpd
    exit 2
    ;;
3)
    delayedStart "《为当前用户安装Git》"
    installBypy
    exit 3
    ;;
4)
    delayedStart "《安装Shadowsocks-libev》"
    installSS
    exit 4
    ;;
5)
    delayedStart "《安装Squid》"
    installTR
    exit 5
    ;;
6)
    delayedStart "《安装MariaDB 10.1[Stable]》"
    installMariaDB
    exit 6
    ;;
7)
    delayedStart "《安装Mongodb 3.4》"
    installMongoDB
    exit 7
    ;;
8)
    delayedStart "《配置SSH登录证书》"
    setSSHLogin
    exit 8
    ;;
9)
    echo "Bye Bye！"
    exit 9
    ;;
*)
    echo "不懂你的选择,我要退出了,再见!"
    exit 99
    ;;
esac
done
