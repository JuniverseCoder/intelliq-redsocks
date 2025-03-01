#!/bin/bash
cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd
binfile="redsocks_$(uname --machine)"
cp "${binfile}" /usr/bin/redsocks

# 默认值
DEFAULT_SOCK_SERVER="127.0.0.1"
DEFAULT_SOCK_PORT="7070"
DEFAULT_PROXY_PORT="12345"

rm -rf redsocks.conf
cp redsocks.conf.example /etc/redsocks.conf

CONFIG_FILE="/etc/redsocksenv"

if [[ ! -f $CONFIG_FILE ]]; then
    # 本地不存在代理服务器的配置
    read -p "Please tell me your sock_server (default: ${DEFAULT_SOCK_SERVER}): " sock_server
    SOCK_SERVER="${sock_server:-${DEFAULT_SOCK_SERVER}}"

    read -p "Please tell me your sock_port (default: ${DEFAULT_SOCK_PORT}): " sock_port
    SOCK_PORT="${sock_port:-${DEFAULT_SOCK_PORT}}"

    read -p "Please tell me your proxy_port (default: ${DEFAULT_PROXY_PORT}): " proxy_port
    PROXY_PORT="${proxy_port:-${DEFAULT_PROXY_PORT}}"

    echo "SOCK_SERVER=${SOCK_SERVER}" > $CONFIG_FILE
    echo "SOCK_PORT=${SOCK_PORT}" >> $CONFIG_FILE
    echo "PROXY_PORT=${PROXY_PORT}" >> $CONFIG_FILE
else
    # 本地已经存在了代理服务的配置信息，直接读取就好了
    source $CONFIG_FILE
fi


# 函数用于更新 redsocks.conf 文件
update_redsocks_conf() {
    sed -i '18s/daemon.*/daemon = on;/g' /etc/redsocks.conf
    sed -i '44s/local_port.*/local_port = '${PROXY_PORT}';/g' /etc/redsocks.conf
    sed -i '61s/ip.*/ip = '${SOCK_SERVER}';/g' /etc/redsocks.conf
    sed -i '62s/port.*/port = '${SOCK_PORT}';/g' /etc/redsocks.conf
}

# 更新 redsocks.conf
update_redsocks_conf

# 检查当前初始化系统类型
if [[ $(ps -p 1 -o comm=) == "systemd" ]]; then
    # systemd 初始化系统的服务管理命令
    cp redsocks.service /lib/systemd/system/
    sed -i 's/SOCK_SERVER/'${SOCK_SERVER}'/g' /lib/systemd/system/redsocks.service
    systemctl daemon-reload
    systemctl enable redsocks.service

    # 检查服务是否已经存在
    if systemctl is-active --quiet redsocks; then
        echo "redsocks service already exists, restarting..."
        systemctl restart redsocks.service
    else
        systemctl start redsocks.service
    fi
else
    # SysV init 初始化系统的服务管理命令
    cp redsocks-service /etc/init.d/redsocks
    sed -i 's/SOCK_SERVER/'${SOCK_SERVER}'/g' /etc/init.d/redsocks
    chmod +x /etc/init.d/redsocks

    # 检查服务是否已经存在
    if service redsocks status >/dev/null 2>&1; then
        echo "redsocks service already exists, restarting..."
        service redsocks restart
    else
        service redsocks start
    fi
fi


# 复制代理设置
/bin/cp NoProxy.txt /etc/NoProxy.txt
/bin/cp GFlist.txt /etc/GFlist.txt

# 复制代理脚本
/bin/cp -rf proxy.sh /usr/local/bin/proxy && chmod +x /usr/local/bin/proxy && sed -i 's/SED_SOCK_SERVER/'${SOCK_SERVER}'/g' /usr/local/bin/proxy && sed -i 's/SED_PROXY_PORT/'${PROXY_PORT}'/g' /usr/local/bin/proxy

# 设置启动时自动代理
if [[ $(ps -p 1 -o comm=) == "systemd" ]]; then
    # systemd 初始化系统的服务管理命令
    cp redsocks_proxy.service /lib/systemd/system/
    systemctl daemon-reload
    systemctl enable redsocks_proxy.service
    systemctl restart redsocks_proxy.service
else
    # SysV init 初始化系统的服务管理命令
    cp redsocks_proxy-service /etc/init.d/redsocks_proxy
    chmod +x /etc/init.d/redsocks_proxy
    service redsocks restart
fi