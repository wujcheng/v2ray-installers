#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
GREENBG="\033[42;37m"
REDBG="\033[41;37m"
FONT="\033[0m"

INFO="${GREEN}[信息]${FONT}"
ERROR="${RED}[错误]${FONT}"

V2RAY_CONFIG_PATH="/etc/v2ray"
V2RAY_CONFIG="${V2RAY_CONFIG_PATH}/config.json"

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

stty erase '^H' && read -p "请输入 WebSockets 连接端口（默认：2082） => " WEBSOCKETS_PORT
[[ -z ${WEBSOCKETS_PORT} ]] && WEBSOCKETS_PORT="2082"
stty erase '^H' && read -p "请输入 mKCP 连接端口（默认：5353） => " MKCP_PORT
[[ -z ${MKCP_PORT} ]] && MKCP_PORT="5353"

apt update
StatusEcho "更新 APT"
apt install wget -y
StatusEcho "安装 WGET"
apt install curl -y
StatusEcho "安装 CURL"
wget -O v2ray-installer.sh https://install.direct/go.sh
StatusEcho "获取 V2RAY 安装脚本"
bash v2ray-installer.sh --force
StatusEcho "安装 V2RAY"

UUID=$(cat /proc/sys/kernel/random/uuid)

cat > ${V2RAY_CONFIG} << EOF
{
    "inbound": {
EOF

echo -e "        \"port\": ${MKCP_PORT}," >> ${V2RAY_CONFIG}

cat >> ${V2RAY_CONFIG} << EOF
        "listen": "0.0.0.0",
        "protocol": "vmess",
        "settings": {
            "clients": [
                {
EOF

echo -e "                    \"id\":\"${UUID}\"," >> ${V2RAY_CONFIG}

cat >> ${V2RAY_CONFIG} << EOF
                    "alterId": 64
                }
            ]
        },
        "streamSettings": {
            "network": "kcp",
            "kcpSettings": {
                "mtu": 1350,
                "tti": 50,
                "uplinkCapacity": 10,
                "downlinkCapacity": 10,
                "congestion": true,
                "readBufferSize": 2,
                "writeBufferSize": 2,
                "header": {
                    "type": "none"
                }
            }
        }
    },
    "inboundDetour": [
        {
EOF

echo -e "            \"port\": ${WEBSOCKETS_PORT}," >> ${V2RAY_CONFIG}

cat >> ${V2RAY_CONFIG} << EOF
            "listen": "0.0.0.0",
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
EOF

echo -e "                        \"id\": \"${UUID}\"," >> ${V2RAY_CONFIG}

cat >> ${V2RAY_CONFIG} << EOF
                        "alterId": 64
                    }
                ]
            },
            "streamSettings": {
                "network": "ws"
            }
        }
    ],
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

echo -e "${INFO} ${GREENBG} V2RAY WebSockets + mKCP 安装成功！${FONT} "
echo -e "${INFO} ${REDBG} WebSockets 端口： ${FONT} ${WEBSOCKETS_PORT}"
echo -e "${INFO} ${REDBG} mKCP 端口： ${FONT} ${MKCP_PORT}"
echo -e "${INFO} ${REDBG} ID： ${FONT} ${UUID}"

rm -f v2ray-installer.sh > /dev/null 2>&1
rm -f mKCP-WebSockets.sh > /dev/null 2>&1