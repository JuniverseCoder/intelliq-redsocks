# 简介

本项目实现了在 Linux 系统下的全局翻墙方案，其中包括两部分：

1. **使用 redsocks 配合 iptables 代理 TCP 连接：**

   此部分使用 iptables 将指定的 TCP 连接代理到 redsocks，然后使用 redsocks 将流量转发到配置的 Socket5 代理服务器上。

2. **使用 dnsmasq 和 pdnsd 代理 DNS 请求：**

   此部分配置了 dnsmasq 和 pdnsd，以代理系统的 DNS 请求。dnsmasq 将本地的 DNS 请求转发给 pdnsd，而 pdnsd 将 DNS 请求发送到 Socket5 代理服务器。整个 DNS 请求流程如下所示：

   本地应用程序 (resolv.conf) <-------> dnsmasq:53 (UDP) <-------> pdnsd:5300 (TCP) <-------> redsocks <-------> Socket5 代理服务器

# 使用 redsocks 配合 iptables 代理 TCP 连接

为了方便使用，我们提供了一个针对 `redsocks` 的预编译版本，无需手动安装依赖，可用于 x86 和 aarch64 架构的系统。以下是使用方法：

## 安装

```bash
Shell> git clone 本仓库
Shell> ./install_redsocks.sh
please tell me you sock_server:127.0.0.1 # 输入 Socket5 代理服务器的地址
please tell me you sock_port:7070        # 输入 Socket5 代理服务器的端口
```

## 启动 redsocks

```bash
Shell > service redsocks start
```

## 选择代理模式

**全局代理模式**

```bash
Shell> proxyall      # 启动全局代理模式，此模式下将代理所有的访问

 your iptables OUTPUT chain like this....
 Chain PREROUTING (policy ACCEPT 0 packets, 0 bytes)
 num   pkts bytes target     prot opt in     out     source               destination

 Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 num   pkts bytes target     prot opt in     out     source               destination

 Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 num   pkts bytes target     prot opt in     out     source               destination
 1        0     0 RETURN     tcp  --  *      *       0.0.0.0/0            192.168.188.0/24
 2        0     0 RETURN     tcp  --  *      *       0.0.0.0/0            127.0.0.1
 3        0     0 RETURN     tcp  --  *      *       0.0.0.0/0            127.0.0.1
 4        0     0 REDIRECT   tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            redir ports 12345

 Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 num   pkts bytes target     prot opt in     out     source               destination
```

**代理指定主机**

此模式下仅代理 `GFlist.txt` 中指定的主机。

```bash
Shell> proxy

this ip[216.58.194.99] will use proxy connected ....
this ip[180.97.33.107] will use proxy connected ....
your iptables OUTPUT chain like this....
   Chain PREROUTING (policy ACCEPT 0 packets, 0 bytes)
   num   pkts bytes target     prot opt in     out     source               destination

   Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
   num   pkts bytes target     prot opt in     out     source               destination

   Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
   num   pkts bytes target     prot opt in     out     source               destination
   1        0     0 RETURN     tcp  --  *      *       0.0.0.0/0            192.168.188.0/24
   2        0     0 RETURN     tcp  --  *      *       0.0.0.0/0            127.0.0.1
   3        0     0 RETURN     tcp  --  *      *       0.0.0.0/0            127.0.0.1
   4        0     0 REDIRECT   tcp  --  *      *       0.0.0.0/0            216.58.194.99        redir ports 12345
   5        0     0 REDIRECT   tcp  --  *      *       0.0.0.0/0            180.97.33.107        redir ports 12345

   Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
   num   pkts bytes target     prot opt in     out     source               destination
```

## 清理代理与关闭代理

```bash
Shell> iptables -t nat -F                  # 清理所有的代理模式
Shell> service redsocks stop             # 关闭代理
```

# 使用 dnsmasq 和 pdnsd 代理 DNS 请求

使用此部分可代理系统的 DNS 请求。以下是使用方法：

## 安装

```bash
Shell> git clone 本仓库
Shell> ./install_dns.sh
Please enter PROXY_DNS_PORT (default: 5300): # 输入 pdnsd 的监听端口
Please enter DEFAULT_NAMESERVER (default: $DEFAULT_NAMESERVER): # 输入默认的 DNS 服务器

┌─────────────────────────────────────────────┤ pdnsd ├─────────────────────────────────────────────┐
│ Please select the pdnsd configuration method that best meets your needs.                          │
│                                                                                                   │
│  - Use resolvconf  : use informations provided by resolvconf.                                     │
│  - Use root servers: make pdnsd behave like a caching, recursive DNS                              │
│                      server.                                                                      │
│  - Manual          : completely manual configuration. The pdnsd daemon                            │
│                      will not start until you edit /etc/pdnsd.conf and                            │
│                      /etc/default/pdnsd.                                                          │
│                                                                                                   │
│                                                                                                   │
│ Note: If you already use a DNS server that listens to 127.0.0.1:53, you have to choose "Manual".  │
│                                                                                                   │
│ General type of pdnsd configuration:                                                              │
│                                                                                                   │
│                                         Use resolvconf                                            │
│                                         Use root servers                                          │
│                                         Manual                                                    │
│                                                                                                   │
│                                                                                                   │
│                                              <Ok>                                                 │
│                                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘
# 选择Manual

```

注意可能linux会自动覆盖 `/etc/resolv.conf`，导致 DNS 请求不会被代理，此时需要手动修改 `/etc/resolv.conf`，将 `nameserver` 修改为 `127.0.0.1`.

## 修改代理的 DNS 名单

需要在 `proxy_dns.txt` 中添加域名，每行一个。使用 `.` 作为前缀将匹配所有子域名，例如：

```bash
.google.com
.youtube.com
```

修改后重新执行脚本：

```bash
Shell> ./install_dns.sh
```


