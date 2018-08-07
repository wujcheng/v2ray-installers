#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
GREENBG="\033[42;37m"
REDBG="\033[41;37m"
FONT="\033[0m"

INFO="${GREEN}[信息]${FONT}"
ERROR="${RED}[错误]${FONT}"

V2RAY_CONFIG_PATH="/etc/v2ray"
V2RAY_CONFIG_FILE="${V2RAY_CONFIG_PATH}/config.json"

StatusEcho(){
    if [[ $? -eq 0 ]]; then
        echo -e "${INFO} ${GREENBG} $1 完成 ${FONT} "
    else
        echo -e "${ERROR} ${REDBG} $1 失败 ${FONT} "
        exit 1
    fi
}

echo -e "${INFO} Cloudflare 支持的端口列表："
echo -e "${INFO} HTTP 协议：80、8080、8880、2052、2082、2086、2095"
echo -e "${INFO} HTTPS 协议：443、2053、2083、2087、2096、8443"
echo -e "${INFO} 在专业套餐及更高版本上，可以使用 WAF 规则 ID 100015 阻止除 80 和 443 之外的所有端口的请求"
echo -e "${INFO} 80 和 443 端口是 Cloudflare Apps 能够使用的唯一端口"
echo -e "${INFO} 80 和 443 端口是 Cloudflare Cache 能够使用的唯一端口"

stty erase '^H' && read -p "请输入连接端口（默认：443） => " PORT
[[ -z ${PORT} ]] && PORT="443"
stty erase '^H' && read -p "请输入您的域名（例如：hacking001.com） => " DOMAIN
DOMAIN_IP=`ping ${DOMAIN} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
echo -e "${INFO} ${GREENBG} 正在获取 IP 信息，请耐心等待 ${FONT} "
LOCAL_IP=`curl -4 ip.sb`
echo -e "域名 IP： ${DOMAIN_IP}"
echo -e "本机 IP： ${LOCAL_IP}"
echo -e "${INFO} ${REDBG} IP 不同会导致下面的安装失败 ${FONT} "

yum install wget -y
StatusEcho "安装 WGET"
yum install curl -y
StatusEcho "安装 CURL"
wget -O v2ray-installer.sh https://install.direct/go.sh
StatusEcho "获取 V2RAY 安装脚本"
bash v2ray-installer.sh --force
StatusEcho "安装 V2RAY"
yum install nc -y
StatusEcho "安装 ACME 依赖"
wget -O acme-installer.sh https://get.acme.sh
StatusEcho "获取 ACME 安装脚本"
sh acme-installer.sh
StatusEcho "安装 ACME"
~/.acme.sh/acme.sh --issue -d ${DOMAIN} --standalone -k ec-256 --force
if [[ $? -eq 0 ]]; then
    ~/.acme.sh/acme.sh --installcert -d ${DOMAIN} --fullchainpath /etc/v2ray/http2.crt -keypath /etc/v2ray/http2.key -ecc
    if [[ $? -eq 0 ]]; then
        echo -e "${INFO} ${GREENBG} SSL 证书生成成功 ${FONT} "
    fi
else
    echo -e "${ERROR} ${REDBG} SSL 证书生成失败 ${FONT} "
    exit 1
fi

UUID=$(cat /proc/sys/kernel/random/uuid)

cat > ${V2RAY_CONFIG_FILE} << EOF
{
    "inbound": {
EOF

echo -e "        \"port\": ${PORT}," >> ${V2RAY_CONFIG_FILE}

cat >> ${V2RAY_CONFIG_FILE} << EOF
        "listen": "0.0.0.0",
        "protocol": "vmess",
        "settings": {
            "clients": [
                {
EOF

echo -e "                    \"id\":\"${UUID}\"," >> ${V2RAY_CONFIG_FILE}

cat >> ${V2RAY_CONFIG_FILE} << EOF
                    "alterId": 64
                }
            ]
        },
        "streamSettings": {
            "network": "h2"
        },
        "security": "tls",
        "tlsSettings": {
            "certificates": [
                {
EOF

echo -e "                    \"certificateFile\":\"${V2RAY_CONFIG_PATH}/http2.crt\"," >> ${V2RAY_CONFIG_FILE}
echo -e "                    \"keyFile\":\"${V2RAY_CONFIG_PATH}/http2.key\"" >> ${V2RAY_CONFIG_FILE_FILE}

cat >> ${V2RAY_CONFIG_FILE} << EOF
                }
            ]
        }
    },
    "outbound": {
        "protocol": "freedom",
        "settings": {}
    },
    "outboundDetour": [
        {
            "protocol": "freedom",
            "settings": {},
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "settings": {
                "response": {
                    "type": "http"
                }
            },
            "tag": "shield"
        }
    ],
    "routing": {
        "strategy": "rules",
        "settings": {
            "domainStrategy": "IPIfNonMatch",
            "rules": [
                {
                    "type": "chinaip",
                    "outboundTag": "shield"
                },
                {
                    "type": "field",
                    "ip": [
                        "0.0.0.0/8",
                        "10.0.0.0/8",
                        "100.64.0.0/10",
                        "127.0.0.0/8",
                        "169.254.0.0/16",
                        "172.16.0.0/12",
                        "192.0.0.0/24",
                        "192.0.2.0/24",
                        "192.168.0.0/16",
                        "198.18.0.0/15",
                        "198.51.100.0/24",
                        "203.0.114.0/24",
                        "::1/128",
                        "fc00::/7",
                        "fe00::/10"
                    ],
                    "outboundTag": "shield"
                }
            ]
        }
    }
}
EOF

service v2ray restart
StatusEcho "V2RAY 加载配置"

echo -e "${INFO} ${GREENBG} V2RAY HTTP2 安装成功！${FONT} "
echo -e "${INFO} ${REDBG} 端口： ${FONT} ${PORT}"
echo -e "${INFO} ${REDBG} ID： ${FONT} ${UUID}"

rm -f v2ray-installer.sh > /dev/null 2>&1
rm -f acme-installer.sh > /dev/null 2>&1
rm -f HTTP2.sh > /dev/null 2>&1