#! /bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
export PATH=$PATH:/usr/local/bin

os_arch=""

pre_check() {
    # check root
    [[ $EUID -ne 0 ]] && echo -e "${red}错误: 请使用root用户运行此脚本!${plain}" && exit 1

    clear

    ## os_arch
    if [[ $(uname -m | grep 'x86_64') != "" ]]; then
        os_arch="amd64"
        elif [[ $(uname -m | grep 'i386\|i686') != "" ]]; then
        os_arch="386"
        elif [[ $(uname -m | grep 'aarch64\|armv8b\|armv8l') != "" ]]; then
        os_arch="arm64"
        elif [[ $(uname -m | grep 'arm') != "" ]]; then
        os_arch="arm"
    fi

    echo os_arch: ${os_arch}

    # check os type and os version
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        if [[ $ID == "debian" ]]; then
            systemFlag="1"
            os_version=$VERSION_ID
        elif [[ $ID == "ubuntu" ]]; then
            systemFlag="2"
            os_version=$VERSION_ID
        elif [[ $ID == "centos"|| $ID == "rocky" || $ID == "alma" || $ID_LIKE == "rhel" ]]; then
            systemFlag="3"
            os_version=$(echo $VERSION_ID | awk -F '.' '{print $1}')
        else
            echo "您的操作系统为 $PRETTY_NAME ，这是不支持的操作系统"
            echo -e "${red}如果您确信您的系统可以使用该脚本"
            echo -e "如果您认为您的系统是Debian，请输入 1"
            echo -e "如果您认为您的系统是Ubuntu，请输入 2"
            echo -e "如果您认为您的系统是CentOS/RHEL，请输入 3${plain}"
            read -e -r -p "请输入您的选择: " systemFlag
            echo -e "${red}请输入您的系统版本，假如您的系统为 Ubuntu 22.04 请输入 “22”（无需双引号）${plain}"
            read -e -r -p "请输入您的系统版本: " os_version
            echo -e "${red}请注意：您的系统不受脚本支持${plain}"
        fi
    else
        echo -e "${red}无法判断系统信息，退出脚本${plain}"
        exit 1
    fi

    ## China_IP
    if [[ -z "${CN}" ]]; then
        if [[ $(curl -m 10 -s https://ipapi.co/json | grep 'China') != "" ]]; then
            echo "根据ip-api的数据，当前IP可能在中国"
            read -e -r -p "是否选用中国镜像完成安装? [Y/n] " input
            case $input in
                [yY][eE][sS] | [yY])
                    echo "使用中国镜像"
                    CN=true
                ;;

                [nN][oO] | [nN])
                    echo "不使用中国镜像"
                ;;
                *)
                    echo "使用中国镜像"
                    CN=true
                ;;
            esac
        fi
    fi

    if [[ -z "${CN}" ]]; then
        LSKYPRO_RELEASE_URL="https://github.com/lsky-org/lsky-pro/releases/download"
        LSKY_VERSION=$(curl -s "https://api.github.com/repos/lsky-org/lsky-pro/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        SURY_PACKAGE_URL="https://packages.sury.org"
        REMI_RPMS_URL="https://rpms.remirepo.net"
        MARIADB_PACKAGE_URL="https://mirrors.xtom.com/mariadb"
    else
        LSKYPRO_RELEASE_URL="https://mirror.ghproxy.com/https://github.com/lsky-org/lsky-pro/releases/download"
        LSKY_VERSION=$(curl -s "https://api.github.com/repos/lsky-org/lsky-pro/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        SURY_PACKAGE_URL="https://mirror.nju.edu.cn/sury"
        REMI_RPMS_URL="https://mirrors.aliyun.com/remi"
        MARIADB_PACKAGE_URL="https://mirrors.aliyun.com/mariadb"
    fi
}

install_soft() {
    (command -v apt >/dev/null 2>&1 && apt update && apt install $* -y) ||
    (command -v apt-get >/dev/null 2>&1 && apt-get update && apt-get install $* -y) ||
    (command -v yum >/dev/null 2>&1 && yum install $* -y) ||
    (command -v dnf >/dev/null 2>&1 && dnf makecache && dnf install $* -y)
}

install_base() {
    echo -e "${green}开始安装基础组件${plain}"
    (command -v git >/dev/null 2>&1 && command -v curl >/dev/null 2>&1 && command -v wget >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1 && command -v getenforce >/dev/null 2>&1 && command -v gnupg >/dev/null 2>&1 && command -v lsb_release >/dev/null) ||
    (install_soft curl wget git unzip gnupg lsb-release ca-certificates)
}

install_base
pre_check

echo -e "${yellow}是否进行全自动安装？${plain}"
read -e -r -p "[Y/n]:" autoFlag
case $autoFlag in
    [yY][eE][sS] | [yY])
        autoFlag="1"
        ;;
    [nN][oO] | [nN])
        autoFlag="0"
        ;;
    *)
        autoFlag="1"
        ;;
esac

install_php() {
    echo -e "${green}开始安装PHP${plain}"
    echo "默认安装php8.1"
    # add repo
    if [[ $systemFlag == "1" ]]; then
        wget -O /usr/share/keyrings/php.gpg ${SURY_PACKAGE_URL}/php/apt.gpg
        echo "deb [signed-by=/usr/share/keyrings/php.gpg] ${SURY_PACKAGE_URL}/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
    elif [[ $systemFlag == "2" ]]; then
        add-apt-repository ppa:ondrej/php
    elif [[ $systemFlag == "3" ]]; then
        dnf install ${REMI_RPMS_URL}/enterprise/remi-release-${os_version}.rpm -y
        dnf module reset php -y
        dnf module install php:remi-8.1 -y
    fi

    if [[ $systemFlag == "1" ]] || [[ $systemFlag == "2" ]]; then
        apt update && apt install php8.1 php8.1-{cli,fpm,mbstring,mysql,bcmath,xml,xmlrpc,imagick,curl,gmp,imap,opcache,mailparse,soap,gd,zip} -y
        sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/8.1/fpm/php.ini
        sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 10M/' /etc/php/8.1/fpm/php.ini
        sed -i 's/post_max_size = 8M/post_max_size = 10M/' /etc/php/8.1/fpm/php.ini
        # 关闭open_basedir
        sed -i 's/;open_basedir =/open_basedir =/g' /etc/php/8.1/fpm/php.ini
    elif [[ $systemFlag == "3" ]]; then
        dnf install php php-{cli,fpm,mbstring,mysqlnd,bcmath,xml,xmlrpc,imagick,curl,gmp,imap,opcache,mailparse,soap,gd,zip} -y
        sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php.ini
        sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 10M/' /etc/php.ini
        sed -i 's/post_max_size = 8M/post_max_size = 10M/' /etc/php.ini
        # 关闭open_basedir
        sed -i 's/;open_basedir =/open_basedir =/g' /etc/php.ini
    fi
}

install_apache() {
    echo -e "${green}开始安装Apache${plain}"
    if [[ $systemFlag == "1" ]]; then
        wget -O /usr/share/keyrings/apache2.gpg ${SURY_PACKAGE_URL}/apache2/apt.gpg
        echo "deb [signed-by=/usr/share/keyrings/apache2.gpg] ${SURY_PACKAGE_URL}/apache2/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/apache2.list
    elif [[ $systemFlag == "2" ]]; then
        add-apt-repository ppa:ondrej/apache2
    fi

    if [[ $systemFlag == "1" ]] || [[ $systemFlag == "2" ]]; then
        apt update && apt install apache2 -y
        a2enconf php8.1-fpm
        a2enmod proxy_fcgi
        a2enmod headers
        a2enmod http2
        a2enmod remoteip
        a2enmod ssl
        a2enmod rewrite
        a2enmod expires
        systemctl restart apache2
        systemctl restart php8.1-fpm
    elif [[ $systemFlag == "3" ]]; then
        dnf install httpd -y
        ln -s /etc/httpd/conf.d/php8.1-fpm.conf /etc/httpd/conf.modules.d/15-php8.1-fpm.conf
        modules=("proxy_fcgi" "headers" "http2" "remoteip" "ssl" "rewrite" "expires")
        for module in "${modules[@]}"; do
            echo "LoadModule ${module}_module modules/mod_${module}.so" > /etc/httpd/conf.modules.d/10-${module}.conf
        done
        systemctl restart httpd
        systemctl restart php-fpm.service
fi
}

install_maraidb() {
    echo -e "${green}开始安装MariaDB${plain}"
    if [[ $systemFlag == "1" && $os_version == "11" ]] || [[ $systemFlag == "2" ]]; then
        curl -sSL https://mariadb.org/mariadb_release_signing_key.asc | gpg --dearmor > /usr/share/keyrings/mariadb.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/mariadb.gpg] ${MARIADB_PACKAGE_URL}/repo/10.6/debian $(lsb_release -sc) main" > /etc/apt/sources.list.d/mariadb.list
        apt update && apt install mariadb-server -y
    elif [[ $systemFlag == "1" && $os_version == "12" ]]; then
        apt update && apt install mariadb-server -y
    elif [[ $systemFlag == "3" ]]; then
        dnf install ${MARIADB_PACKAGE_URL}/yum/10.6/centos/${os_version}/x86_64/mariadb-release-10.6-1.el8.noarch.rpm -y
        dnf install MariaDB-server MariaDB-client -y
    fi
    if [[ $autoFlag == "0" ]]; then
        read -e -r -p "是否快速配置MariaDB? [Y/n] 默认 Y(es)" input
        case $input in
            [yY][eE][sS] | [yY])
                echo "开始快速配置MariaDB"
                mysql_secure_installation
            ;;
            [nN][oO] | [nN])
                echo "不快速配置MariaDB"
            ;;
            *)
                echo "开始快速配置MariaDB"
                mysql_secure_installation
            ;;
        esac
    else
        PWD = "$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"
        mysql_secure_installation <<EOF

y
$PWD
$PWD
y
y
y
y
EOF
    fi
}

install_php
install_apache
install_maraidb

setup_database() {
    echo -e "${green}开始配置数据库${plain}"
    echo -e "${yellow}请无比妥善保存以下信息${plain}"
    echo "自动生成数据库信息请输入1，手动输入请输入2，其他情况自动生成"
    read -e -r -p "请输入您的选择: " dbFlag
    if [[ $dbFlag == "1" ]]; then
        db_user="lsky_$(openssl rand -base64 12 | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)"
        db_name="lsky_$(openssl rand -base64 12 | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)"
        db_password="$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"
    elif [[ $dbFlag == "2" ]]; then
        read -e -r -p "请输入数据库用户名: " db_user
        read -e -r -p "请输入数据库名称: " db_name
        read -e -r -p "请输入数据库密码: " db_password
    else
        db_user="lsky_$(openssl rand -base64 12 | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)"
        db_name="lsky_$(openssl rand -base64 12 | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)"
        db_password="$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"
    fi
    echo -e "${yellow}数据库用户名: ${db_user}${plain}"
    echo -e "${yellow}数据库名称: ${db_name}${plain}"
    echo -e "${yellow}数据库密码: ${db_password}${plain}"
    mysql -e "CREATE DATABASE IF NOT EXISTS ${db_name} DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -e "GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@'localhost' IDENTIFIED BY '${db_password}';"
    mysql -e "FLUSH PRIVILEGES;"
}

setup_database

# 下载 Lsky Pro
download_lsky() {
    echo -e "${green}开始下载 Lsky Pro${plain}"
    mkdir -p /var/www/lsky
    cd /var/www/lsky || echo "error, can't cd"
    wget -O lsky.zip "${LSKYPRO_RELEASE_URL}"/"${LSKY_VERSION}"/lsky-pro-"${LSKY_VERSION}".zip
    unzip lsky.zip -q
    rm -rf lsky.zip
    chown -R www-data:www-data /var/www
}

setup_apache() {
    echo -e "${green}开始配置 Apache${plain}"
    read -e -r -p "请输入域名: " domain
    cat > /etc/apache2/sites-available/lsky.conf <<EOF
<VirtualHost *:80>
    ServerName ${domain}
    DocumentRoot /var/www/lsky/public
    DirectoryIndex index.php

    ErrorLog \${APACHE_LOG_DIR}/lsky_error.log
    CustomLog \${APACHE_LOG_DIR}/lsky_access.log combined

    <Directory /var/www/lsky/public>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

</VirtualHost>
EOF
    if [[ $systemFlag == "1" ]] || [[ $systemFlag == "2" ]]; then
        a2ensite lsky.conf
        systemctl restart apache2
    elif [[ $systemFlag == "3" ]]; then
        systemctl restart php-fpm.service
        systemctl restart httpd
    fi
}

download_lsky
setup_apache

echo -e "${green}安装完成${plain}"

if [[ $autoFlag == "0" ]]; then
    echo -e "${green}请访问 http://${domain} 完成后续配置 ${plain}"
else
    touch /var/www/lsky/install.lock
fi