#!/bin/bash

# 检查并安装 openssl（如果不存在）- 仅适配 Ubuntu/Debian
if ! command -v openssl &> /dev/null; then
    echo "检测到系统未安装 openssl，正在安装..."
    sudo apt-get update && sudo apt-get install -y openssl
    
    if command -v openssl &> /dev/null; then
        echo "openssl 安装成功"
    else
        echo "错误：openssl 安装失败"
        echo "请确保系统是 Ubuntu 或 Debian，并且 apt 可用"
        exit 1
    fi
fi

# 处理命令行参数
IMAGE_TAG="latest"  # 默认使用 latest
CHANNEL=""          # 暂存渠道
SEALDICE_COUNT=""   # 海豹数量参数
LOGIN_METHOD="napcat"  # 登录方式: napcat/llbot/builtin，默认为 napcat

# 允许的渠道值
ALLOWED_CHANNELS=("latest" "stable" "pre")

# 如果用户没有提供参数，显示交互式引导
if [ $# -eq 0 ]; then
    echo ""
    echo "   ███████╗███████╗ █████╗ ██╗     ██████╗ ██╗ ██████╗███████╗"
    echo "   ██╔════╝██╔════╝██╔══██╗██║     ██╔══██╗██║██╔════╝██╔════╝"
    echo "   ███████╗█████╗  ███████║██║     ██║  ██║██║██║     █████╗  "
    echo "   ╚════██║██╔══╝  ██╔══██║██║     ██║  ██║██║██║     ██╔══╝  "
    echo "   ███████║███████╗██║  ██║███████╗██████╔╝██║╚██████╗███████╗"
    echo "   ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═════╝ ╚═╝ ╚═════╝╚══════╝"
    echo "=================================================================="
    echo "          海豹核心一键部署脚本 by DiceZone 2026-03-29 "
    echo "=================================================================="
    echo ""
    
    # 询问部署数量
    while true; do
        read -p "请输入要部署的海豹数量 (1-99，默认1): " num_input
        num_input=${num_input:-1}
        
        if [[ $num_input =~ ^[1-9][0-9]?$ ]] && [ $num_input -le 99 ]; then
            SEALDICE_COUNT=$num_input
            break
        else
            echo "错误：请输入 1-99 之间的数字"
        fi
    done
    
    # 询问版本渠道
    echo ""
    echo "请选择版本渠道："
    echo "1) latest - 最新版本"
    echo "2) stable - 稳定版本（推荐）"
    echo "3) pre - 预发布版本"
    
    while true; do
        read -p "请输入选择 (1-3，默认2): " choice
        choice=${choice:-2}
        
        case $choice in
            1) CHANNEL="latest" ; break ;;
            2) CHANNEL="stable" ; break ;;
            3) CHANNEL="pre" ; break ;;
            *) echo "错误：请输入 1-3 之间的数字" ;;
        esac
    done
    
    # 询问登录方式
    echo ""
    echo "请选择登录方式："
    echo "1) NapCat"
    echo "2) LLBot"
    echo "3) 内置登录"
    
    while true; do
        read -p "请输入选择 (1-3，默认1): " login_choice
        login_choice=${login_choice:-1}
        
        case $login_choice in
            1) LOGIN_METHOD="napcat" ; break ;;
            2) LOGIN_METHOD="llbot" ; break ;;
            3) LOGIN_METHOD="builtin" ; break ;;
            *) echo "错误：请输入 1-3 之间的数字" ;;
        esac
    done
    
    # 确认执行
    echo ""
    echo "即将部署 $SEALDICE_COUNT 个海豹，使用 $CHANNEL 版本渠道，登录方式: $LOGIN_METHOD"
    read -p "确认执行？(y/N): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "已取消部署"
        exit 0
    fi
    
    echo ""
else
    # 原有参数处理逻辑
    while getopts ":c:n:m:" opt; do
      case $opt in
        c)
          CHANNEL="$OPTARG"
          ;;
        n)
          SEALDICE_COUNT="$OPTARG"
          ;;
        m)
          LOGIN_METHOD="$OPTARG"
          ;;
        \?)
          echo "无效选项: -$OPTARG" >&2
          exit 1
          ;;
        :)
          echo "选项 -$OPTARG 需要参数." >&2
          exit 1
          ;;
      esac
    done
    
    # 验证登录方式参数
    if [ -n "$LOGIN_METHOD" ]; then
      if [[ "$LOGIN_METHOD" != "napcat" && "$LOGIN_METHOD" != "llbot" && "$LOGIN_METHOD" != "builtin" ]]; then
        echo "错误：-m 参数的值必须是 napcat、llbot 或 builtin"
        exit 1
      fi
    fi
    
    # 验证渠道参数
    if [ -n "$CHANNEL" ]; then
      if ! [[ " ${ALLOWED_CHANNELS[@]} " =~ " $CHANNEL " ]]; then
        echo "错误：-c 参数的值必须是 latest、stable 或 pre"
        exit 1
      fi
    fi
    
    # 验证海豹数量参数
    if [ -n "$SEALDICE_COUNT" ]; then
      if ! [[ $SEALDICE_COUNT =~ ^[1-9][0-9]?$ ]] || [ $SEALDICE_COUNT -gt 99 ]; then
        echo "错误：-n 参数的值必须是 1-99 之间的数字"
        exit 1
      fi
    else
      SEALDICE_COUNT=1  # 默认部署1个海豹
    fi
fi

# 设置镜像标签
if [ -n "$CHANNEL" ]; then
  IMAGE_TAG="$CHANNEL"
fi
echo "将使用镜像标签: shiaworkshop/sealdice:$IMAGE_TAG"
sleep 1

# 检测 Docker 是否已安装
check_docker_installed() {
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 配置目录和文件路径
SEALDICE_BASE_DIR="/opt/SealDice-Docker"
QQ_ACCOUNTS=()  # 存储所有QQ号

echo "将部署 $SEALDICE_COUNT 个海豹实例"
sleep 1

# 收集所有QQ号
for ((i=1; i<=SEALDICE_COUNT; i++)); do
    # 交互式输入QQ号
    while true; do
        read -p "请输入第 $i 个海豹QQ号（必须输入）: " QQ_INPUT
        
        if [ -z "$QQ_INPUT" ]; then
            echo "错误：QQ号不能为空"
            continue
        elif [[ ! $QQ_INPUT =~ ^[0-9]+$ ]]; then
            echo "错误：QQ号必须是纯数字"
            continue
        elif [[ " ${QQ_ACCOUNTS[@]} " =~ " $QQ_INPUT " ]]; then
            echo "错误：该QQ号已存在，请输入不同的QQ号"
            continue
        else
            echo "已输入第 $i 个海豹QQ号: $QQ_INPUT"
            sleep 1
            break
        fi
    done
    
    QQ_ACCOUNTS+=("$QQ_INPUT")
done

echo "已收集所有QQ号: ${QQ_ACCOUNTS[*]}"
sleep 1

# 初始化密码存储数组
LLBOT_PASSWORDS=()
NAPCAT_PASSWORDS=()

# 生成随机MAC地址
generate_mac() {
    random_bytes=$(openssl rand -hex 4)
    formatted_bytes=$(echo "$random_bytes" | sed -E 's/(..)(..)(..)(..)/\1:\2:\3:\4/')
    echo "02:42:$formatted_bytes"
}
echo "MAC地址生成函数已准备就绪"
sleep 1

# 生成16位随机密码
generate_password() {
    password=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-16)
    echo "$password"
}
echo "密码生成函数已准备就绪"
sleep 1

# 安装 MCSM
echo "正在安装 MCSManager..."
sleep 1
sudo su -c "wget -qO- https://script.mcsmanager.com/setup_cn.sh | bash"
echo "MCSManager 安装完成"
sleep 1

# 检测并安装 Docker
if check_docker_installed; then
    echo "Docker 和 Docker Compose 已安装，跳过安装步骤"
    sleep 1
else
    echo "正在安装 Docker..."
    sleep 1
    
    max_retries=3
    retry_count=0
    install_success=false
    
    while [ $retry_count -lt $max_retries ]; do
        echo "尝试 #$((retry_count+1)) 安装 Docker..."
        
        # 使用自维护安装脚本镜像源解决国内网络问题
        curl --retry 3 --retry-delay 5 --connect-timeout 20 --max-time 60 \
             -fsSL https://dice.zone/bash/docker_install.sh -o get-docker.sh
        echo "已下载Docker安装脚本"
        sleep 1
        
        # 替换为腾讯云镜像源
        sed -i 's|https://download.docker.com|https://mirrors.tencent.com/docker-ce|g' get-docker.sh
        echo "已配置腾讯云镜像源"
        sleep 1
        
        sudo sh get-docker.sh
        echo "执行Docker安装脚本"
        sleep 1
        
        # 验证安装
        if command -v docker &> /dev/null && docker compose version &> /dev/null; then
            install_success=true
            break
        else
            echo "部分安装步骤失败，正在重试..."
            retry_count=$((retry_count+1))
            sleep 1
        fi
    done
    
    # 清理临时文件
    sudo rm -f get-docker.sh
    
    # 最终验证安装
    if ! $install_success; then
        echo ""
        echo "============================================================"
        echo "错误：Docker 安装失败！可能原因："
        echo "1. 网络连接不稳定或被限制"
        echo "2. 系统软件源配置问题"
        echo "3. 安装源被阻止"
        echo ""
        echo "建议解决方案："
        echo "1. 检查网络连接并重试"
        echo "2. 手动安装 Docker：https://docs.docker.com/engine/install/"
        echo "============================================================"
        exit 1
    else
        echo "Docker 安装成功！"
        sleep 1
    fi
    
    # 添加当前用户到docker组
    sudo usermod -aG docker $USER
    echo "已将当前用户添加到docker组"
    sleep 1
fi

# 使用毫秒镜像服务加速
echo "配置毫秒镜像服务加速..."
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null <<EOF
{
  "registry-mirrors": [
    "https://docker.1ms.run"
  ]
}
EOF
echo "已配置镜像加速"
sleep 1

sudo systemctl restart docker
sudo systemctl enable docker
echo "已重启并启用Docker服务"
sleep 1

# 验证 Docker 服务状态
if ! sudo systemctl is-active --quiet docker; then
    echo "警告：Docker 服务未运行，正在尝试启动..."
    sudo systemctl start docker
    sleep 1
    if ! sudo systemctl is-active --quiet docker; then
        echo "错误：无法启动 Docker 服务"
        exit 1
    else
        echo "Docker服务已成功启动"
        sleep 1
    fi
else
    echo "Docker服务运行正常"
    sleep 1
fi

# 创建 MCSManager 实例配置文件
MCS_CONFIG_DIR="/opt/mcsmanager/daemon/data/InstanceConfig"
echo "配置 MCSManager 实例..."
sudo mkdir -p "$MCS_CONFIG_DIR"
echo "已创建MCSManager配置目录"
sleep 1

# 创建 SealDice-Docker 基础目录
echo "设置 SealDice-Docker 环境..."
sudo mkdir -p -m 755 "$SEALDICE_BASE_DIR"
echo "已创建 SealDice-Docker 基础目录: $SEALDICE_BASE_DIR"
sleep 1

# 为每个海豹创建独立的配置和目录
for i in "${!QQ_ACCOUNTS[@]}"; do
    ACCOUNT="${QQ_ACCOUNTS[$i]}"
    SEALDICE_DIR="$SEALDICE_BASE_DIR/$ACCOUNT"
    COMPOSE_FILE="$SEALDICE_DIR/docker-compose.yml"
    MCS_CONFIG_FILE="$MCS_CONFIG_DIR/sealdice-$ACCOUNT.json"
    
    # 计算端口分配
    SEALDICE_PORT=$((32110 + i))
    
    # 两种登录方式都使用相同的端口规则
    WEBUI_PORT=$((22000 + i))
    
    echo "配置第 $((i+1)) 个海豹 (QQ: $ACCOUNT)..."
    sleep 1
    
    # 为每个实例生成独立的MAC地址
    MAC_ADDRESS=$(generate_mac)
    echo "为海豹 $ACCOUNT 生成MAC地址: $MAC_ADDRESS"
    
    # 创建海豹专属目录
    sudo mkdir -p "$SEALDICE_DIR"
    
    # 创建MCSManager实例配置
    sudo tee "$MCS_CONFIG_FILE" > /dev/null <<EOF
{
    "nickname": "SealDice-$ACCOUNT",
    "startCommand": "docker compose up",
    "stopCommand": "^C",
    "cwd": "$SEALDICE_DIR",
    "ie": "utf8",
    "oe": "utf8",
    "createDatetime": $(date +%s)000,
    "lastDatetime": $(date +%s)000,
    "type": "universal",
    "tag": [
        "sealdice"
    ],
    "endTime": 0,
    "fileCode": "utf8",
    "processType": "general",
    "updateCommand": "docker compose pull",
    "crlf": 1,
    "category": 0,
    "enableRcon": false,
    "rconPassword": "",
    "rconPort": 0,
    "rconIp": "",
    "actionCommandList": [],
    "terminalOption": {
        "haveColor": false,
        "pty": true,
        "ptyWindowCol": 164,
        "ptyWindowRow": 40
    },
    "eventTask": {
        "autoStart": $([ $i -eq 0 ] && echo "true" || echo "false"),
        "autoRestart": true,
        "ignore": false
    },
    "docker": {
        "containerName": "",
        "image": "",
        "ports": [],
        "extraVolumes": [],
        "memory": 0,
        "networkMode": "bridge",
        "networkAliases": [],
        "cpusetCpus": "",
        "cpuUsage": 0,
        "maxSpace": 0,
        "io": 0,
        "network": 0,
        "workingDir": "/data",
        "env": [],
        "changeWorkdir": true
    },
    "pingConfig": {
        "ip": "",
        "port": 25565,
        "type": 1
    },
    "extraServiceConfig": {
        "openFrpTunnelId": "",
        "openFrpToken": "",
        "isOpenFrp": false
    }
}
EOF
    echo "MCSManager 实例配置已创建: $MCS_CONFIG_FILE"
    
    # 生成docker-compose.yml，根据登录方式不同生成不同配置
    if [ "$LOGIN_METHOD" == "llbot" ]; then
        # LLBot 模式配置
        sudo tee "$COMPOSE_FILE" > /dev/null <<EOF
services:
  sealdice:
    image: shiaworkshop/sealdice:$IMAGE_TAG
    container_name: sealdice-${ACCOUNT}
    ports:
      - "${SEALDICE_PORT}:3211"
    volumes:
      - "\${PWD}/data:/sealdice/data"
      - "\${PWD}/backups:/sealdice/backups"
      - "\${PWD}/llbot/config:/app/llbot/data"
    networks:
      - sealdice
    environment:
      - MODE=llbot

  pmhq:
    image: linyuchen/pmhq:latest
    privileged: true
    container_name: pmhq-${ACCOUNT}
    environment:
      - ENABLE_HEADLESS=false
      - AUTO_LOGIN_QQ=${ACCOUNT}
    networks:
      - sealdice
    volumes:
      - "\${PWD}/llbot/QQ_DATA:/root/.config/QQ"
      - "\${PWD}/data:/sealdice/data"
      - "\${PWD}/backups:/sealdice/backups"

  llbot:
    image: linyuchen/llbot:latest
    ports:
      - "${WEBUI_PORT}:3080"
    container_name: llbot-${ACCOUNT}
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - PMHQ_HOST=pmhq
      - WEBUI_PORT=3080
    networks:
      - sealdice
    volumes:
      - "\${PWD}/llbot/QQ_DATA:/root/.config/QQ"
      - "\${PWD}/data:/sealdice/data"
      - "\${PWD}/backups:/sealdice/backups"
      - "\${PWD}/llbot/config:/app/llbot/data:rw"
      - "\${PWD}/qrcode:/app/llbot/data/temp"
    depends_on:
      - pmhq

networks:
  sealdice:
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.$((100 + i)).0/24
EOF
        
        # 为当前 LLBot 实例生成密码
        LLBOT_PASSWORD=$(generate_password)
        LLBOT_PASSWORDS+=("$LLBOT_PASSWORD")
        
        # 创建LLBot目录结构（先创建目录）
        sudo mkdir -p "$SEALDICE_DIR/data" "$SEALDICE_DIR/backups" "$SEALDICE_DIR/llbot/config" "$SEALDICE_DIR/llbot/QQ_DATA"
        
        # 生成默认配置文件
        sudo tee "$SEALDICE_DIR/llbot/config/config_${ACCOUNT}.json" > /dev/null <<EOF
{
  "milky": {
    "enable": false,
    "reportSelfMessage": false,
    "http": {
      "host": "",
      "port": 3000,
      "prefix": "/milky",
      "accessToken": ""
    },
    "webhook": {
      "urls": [],
      "accessToken": ""
    }
  },
  "satori": {
    "enable": false,
    "host": "",
    "port": 5500,
    "token": ""
  },
  "ob11": {
    "enable": true,
    "connect": [
      {
        "type": "ws",
        "enable": true,
        "host": "",
        "port": 1234,
        "token": "",
        "reportSelfMessage": false,
        "reportOfflineMessage": false,
        "messageFormat": "array",
        "debug": false,
        "heartInterval": 30000
      }
    ]
  },
  "webui": {
    "enable": true,
    "host": "",
    "port": 3080
  }
}
EOF
        
        # 创建 webui_token.txt 文件
        sudo tee "$SEALDICE_DIR/llbot/config/webui_token.txt" > /dev/null <<EOF
$LLBOT_PASSWORD
EOF
        echo "LLBot WebUI 密码文件已创建"
        
        # 设置LLBot目录权限
        sudo chmod -R 755 "$SEALDICE_DIR"
        sudo chmod -R 777 "$SEALDICE_DIR/llbot/config"
    elif [ "$LOGIN_METHOD" == "builtin" ]; then
        # 内置登录模式配置 - 仅海豹容器
        sudo tee "$COMPOSE_FILE" > /dev/null <<EOF
services:
  sealdice:
    image: shiaworkshop/sealdice:$IMAGE_TAG
    container_name: sealdice-${ACCOUNT}
    ports:
      - "${SEALDICE_PORT}:3211"
    volumes:
      - "\${PWD}/data:/sealdice/data"
      - "\${PWD}/backups:/sealdice/backups"
    environment:
      - MODE=builtin

networks:
  sealdice:
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.$((100 + i)).0/24
EOF
        
        # 创建基础目录结构
        sudo mkdir -p "$SEALDICE_DIR/data" "$SEALDICE_DIR/backups"
        
        # 设置目录权限
        sudo chmod -R 755 "$SEALDICE_DIR"
        
        echo "内置登录模式配置完成（无外部适配器）"
    else
        # NapCat 模式配置
        sudo tee "$COMPOSE_FILE" > /dev/null <<EOF
services:
  sealdice:
    image: shiaworkshop/sealdice:$IMAGE_TAG
    container_name: sealdice-${ACCOUNT}
    ports:
      - "${SEALDICE_PORT}:3211"
    volumes:
      - "\${PWD}/data:/sealdice/data"
      - "\${PWD}/backups:/sealdice/backups"
      - "\${PWD}/napcat/config:/app/napcat/config"
    networks:
      - sealdice
    environment:
      - MODE=napcat

  napcat:
    image: mlikiowa/napcat-docker:latest
    container_name: napcat-${ACCOUNT}
    hostname: ShiaDiceFlats-${ACCOUNT}
    ports:
      - "${WEBUI_PORT}:6099"
    volumes:
      - "\${PWD}/napcat/config:/app/napcat/config"
      - "\${PWD}/napcat/QQ_DATA:/app/.config/QQ"
      - "\${PWD}/data:/sealdice/data"
      - "\${PWD}/backups:/sealdice/backups"
      - "\${PWD}/qrcode:/app/napcat/cache"
    environment:
      - MODE=sealdice
      - ACCOUNT=${ACCOUNT}
    networks:
      - sealdice
    mac_address: "${MAC_ADDRESS}"

networks:
  sealdice:
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.$((100 + i)).0/24
EOF
        
        # 创建NapCat目录结构
        sudo mkdir -p "$SEALDICE_DIR/data" "$SEALDICE_DIR/backups" "$SEALDICE_DIR/napcat/config" "$SEALDICE_DIR/napcat/QQ_DATA" "$SEALDICE_DIR/qrcode"
        
        # 为 NapCat 生成密码并创建 webui.json
        NAPCAT_PASSWORD=$(generate_password)
        NAPCAT_PASSWORDS+=("$NAPCAT_PASSWORD")
        
        sudo tee "$SEALDICE_DIR/napcat/config/webui.json" > /dev/null <<EOF
{
    "host": "0.0.0.0",
    "port": 6099,
    "token": "$NAPCAT_PASSWORD",
    "loginRate": 10,
    "autoLoginAccount": "",
    "disableWebUI": false,
    "disableNonLANAccess": false
}
EOF
        
        # 设置NapCat目录权限
        sudo chmod -R 755 "$SEALDICE_DIR"
        sudo chmod -R 777 "$SEALDICE_DIR/napcat/config"
        
    fi
    
    # 设置共享目录权限
    sudo chmod -R 755 "$SEALDICE_DIR/data" "$SEALDICE_DIR/backups"
    
    # 根据登录方式输出不同的提示信息
    if [ "$LOGIN_METHOD" == "llbot" ]; then
        echo "第 $((i+1)) 个海豹配置完成，端口: SealDice($SEALDICE_PORT), LLBot($WEBUI_PORT)"
    else
        echo "第 $((i+1)) 个海豹配置完成，端口: SealDice($SEALDICE_PORT), NapCat($WEBUI_PORT)"
    fi
    sleep 1
done

echo "所有海豹实例配置完成"
sleep 1

# 重启 MCSManager daemon 以加载新配置
echo "重启 MCSManager daemon..."
sudo systemctl restart mcsm-daemon.service
echo "MCSManager daemon 已重启"
sleep 1

# 检测内网IP
get_internal_ip() {
    # 尝试多种方法获取内网IP
    internal_ip=$(ip route get 1 | grep -Eo 'src ([0-9\.]{7,15})' | awk '{print $2}' 2>/dev/null)
    if [ -z "$internal_ip" ]; then
        internal_ip=$(hostname -I | awk '{print $1}' 2>/dev/null)
    fi
    if [ -z "$internal_ip" ]; then
        internal_ip=$(ip addr show | grep -E 'inet (192\.168|10\.|172\.16)' | head -1 | awk '{print $2}' | cut -d'/' -f1)
    fi
    echo "$internal_ip"
}

# 检测公网IP
get_external_ip() {
    # 使用多个不同提供商的API检测公网IP
    if ! external_ip=$(curl -s --connect-timeout 3 https://ipinfo.io/ip 2>/dev/null); then
        external_ip=$(curl -s --connect-timeout 3 https://ifconfig.me 2>/dev/null)
    fi
    
    # 验证IP格式
    if ! echo "$external_ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
        external_ip="无法自动获取公网IP"
    fi
    echo "$external_ip"
}

# 获取IP地址
echo "获取网络配置信息..."
sleep 1
INTERNAL_IP=$(get_internal_ip)
EXTERNAL_IP=$(get_external_ip)

# 输出信息
echo ""
echo "============================================================"
echo "安装完成！以下是重要信息："
echo ""
echo "SealDice容器基础目录: $SEALDICE_BASE_DIR"
echo "使用的镜像标签: $IMAGE_TAG"
echo "部署的海豹实例数量: $SEALDICE_COUNT"
echo ""
echo "MCSManager面板访问地址:"
echo "  公网访问: http://${EXTERNAL_IP}:23333"
echo "  内网访问: http://${INTERNAL_IP}:23333"
echo ""
echo "各海豹实例访问地址:"
for i in "${!QQ_ACCOUNTS[@]}"; do
    ACCOUNT="${QQ_ACCOUNTS[$i]}"
    SEALDICE_PORT=$((32110 + i))
    WEBUI_PORT=$((22000 + i))
    echo "  海豹 $((i+1)) (QQ: $ACCOUNT):"
    echo "    SealDice WebUI: http://${EXTERNAL_IP}:$SEALDICE_PORT"
    
    if [ "$LOGIN_METHOD" == "llbot" ]; then
        echo "    LLBot WebUI: http://${EXTERNAL_IP}:$WEBUI_PORT"
        echo "    LLBot 密码: ${LLBOT_PASSWORDS[$i]}"
    else
        echo "    NapCat WebUI: http://${EXTERNAL_IP}:$WEBUI_PORT"
        echo "    NapCat 密码: ${NAPCAT_PASSWORDS[$i]}"
    fi
done
echo ""
echo "============================================================"
echo ""
echo "立即访问 MCSManager 面板，账号密码请在访问时自行设置"
echo "已创建所有海豹实例并开始拉取镜像，请登录面板页面查看"

if [ "$LOGIN_METHOD" == "builtin" ]; then
    echo "稍后请直接访问各海豹的 WebUI 地址，在账号设置中配置内置登录"
else
    echo "若终端的登录二维码被截断，请进入文件管理"
    if [ "$LOGIN_METHOD" == "napcat" ]; then
        echo "扫描 qrcode 文件夹的 qrcode.png 来登录"
        echo "或直接访问 NapCat WebUI 扫码登录"
    elif [ "$LOGIN_METHOD" == "llbot" ]; then
        echo "扫描 qrcode 文件夹的 login-qrcode.png 来登录"
        echo "或直接访问 LLBot WebUI 扫码登录"
    fi
fi
echo "请在每个骰子成功扫码登录后，前往海豹WebUI-综合设置-基础设置中设置 UI 界面密码"
echo ""
echo "============================================================"
echo "需要开放的端口:"
echo "  MCSManager: 23333, 24444"
for i in "${!QQ_ACCOUNTS[@]}"; do
    SEALDICE_PORT=$((32110 + i))
    WEBUI_PORT=$((22000 + i))
    if [ "$LOGIN_METHOD" == "llbot" ]; then
        echo "  海豹 $((i+1)): $SEALDICE_PORT(SEALDICE), $WEBUI_PORT (LLBot)"
    elif [ "$LOGIN_METHOD" == "builtin" ]; then
        echo "  海豹 $((i+1)): $SEALDICE_PORT(SEALDICE), 无适配器端口"
    else
        echo "  海豹 $((i+1)): $SEALDICE_PORT(SEALDICE), $WEBUI_PORT (NapCat)"
    fi
done
echo "注意: 云服务器必须在控制台安全组（防火墙）中开放上述端口"
echo "推荐直接在安全组（防火墙）中添加规则，允许TCP协议的 20000-40000 端口"
echo "============================================================"
echo "⚡要饭链接：https://afdian.com/a/dicezone"
echo "⭐项目地址：https://github.com/ShiaBox/sealdice-docker"
echo "============================================================"
