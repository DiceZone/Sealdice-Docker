#!/bin/bash
set -euo pipefail

# 日志函数
log_info() {
    echo "[INFO] $*"
}

log_warn() {
    echo "[WARN] $*"
}

log_error() {
    echo "[ERROR] $*"
}

# 检查是否启用了 napcat 模式
if [[ "${MODE:-}" != "napcat" ]]; then
    log_info "MODE 不是 napcat，跳过配置"
    exit 0
fi

log_info "开始配置 napcat 适配器"

# 1. 确定骰子QQ
DICE_QQ="${DICE_QQ:-}"
if [[ -z "$DICE_QQ" ]]; then
    log_info "环境变量 DICE_QQ 未设置，尝试从 napcat/config 目录查找"
    if [[ -d "napcat/config" ]]; then
        # 查找 onebot11_数字.json 文件，按修改时间排序，取最新的
        latest_file=$(find napcat/config -name "onebot11_*.json" -type f 2>/dev/null | xargs ls -t 2>/dev/null | head -n1)
        if [[ -n "$latest_file" ]]; then
            # 提取数字部分
            if [[ "$latest_file" =~ onebot11_([0-9]+)\.json ]]; then
                DICE_QQ="${BASH_REMATCH[1]}"
                log_info "从文件 $latest_file 提取到骰子QQ: $DICE_QQ"
            else
                log_warn "无法从文件名提取数字: $latest_file"
            fi
        else
            log_warn "未找到 onebot11_*.json 文件"
        fi
    else
        log_warn "napcat/config 目录不存在"
    fi
fi

# 如果仍未设置，使用默认值
if [[ -z "$DICE_QQ" ]]; then
    DICE_QQ="100001"
    log_info "使用默认骰子QQ: $DICE_QQ"
else
    log_info "使用环境变量提供的骰子QQ: $DICE_QQ"
fi

# 2. 骰主QQ（可选）
MASTER_QQ="${MASTER_QQ:-}"
if [[ -n "$MASTER_QQ" ]]; then
    log_info "使用环境变量提供的骰主QQ: $MASTER_QQ"
else
    log_info "未指定骰主QQ，保持空值"
fi

# 3. 处理 serve.yaml
SERVE_FILE="data/default/serve.yaml"
if [[ ! -f "$SERVE_FILE" ]]; then
    log_info "未找到 serve.yaml，创建新的配置文件"
    mkdir -p data/default
    # 创建新的 serve.yaml
    cat > "$SERVE_FILE" << EOF
imSession:
    endPoints:
        - baseInfo:
            id: $(uuidgen)
            nickname: ""
            state: 2
            userId: QQ:$DICE_QQ
            groupNum: 0
            cmdExecutedNum: 0
            cmdExecutedLastTime: 0
            onlineTotalTime: 0
            platform: QQ
            relWorkDir: x
            enable: true
            protocolType: onebot
            isPublic: false
          adapter:
            isReverse: false
            reverseAddr: ""
            connectUrl: ws://napcat:1234
            accessToken: ""
            useInPackGoCqhttp: false
            builtinMode: gocq
            inPackGoCqLastAutoLoginTime: 0
            inPackGoCqHttpLoginSucceeded: false
            inPackGoCqHttpLastRestricted: 0
            forcePrintLog: false
            inPackGoCqHttpProtocol: 0
            inPackGoCqHttpAppVersion: ""
            inPackGoCqHttpPassword: ""
            ignoreFriendRequest: false
            implementation: gocq
            useSignServer: false
            signServerConfig: null
            extraArgs: ""
            signServerVer: ""
            signServerName: ""
EOF
    log_info "已创建新的 serve.yaml 文件"
else
    log_info "找到现有 serve.yaml，修改配置文件"
    # 备份原文件
    cp "$SERVE_FILE" "$SERVE_FILE.backup"
    
    # 使用 yq 处理 YAML 文件
    # 首先，确保 yq 已安装
    if ! command -v yq &> /dev/null; then
        log_error "yq 命令未找到，无法处理 YAML 文件"
        exit 1
    fi
    
    # 检查是否存在 imSession.endPoints 数组
    if ! yq -e '.imSession.endPoints' "$SERVE_FILE" > /dev/null 2>&1; then
        log_warn "serve.yaml 中未找到 imSession.endPoints，创建新的结构"
        # 创建基本结构
        cat > "$SERVE_FILE" << EOF
imSession:
    endPoints: []
EOF
    fi
    
    # 查找是否已存在当前骰子QQ的配置
    endpoint_index=$(yq ".imSession.endPoints | to_entries | map(select(.value.baseInfo.userId == \"QQ:$DICE_QQ\")) | .[0].key" "$SERVE_FILE" 2>/dev/null || echo "")
    
    if [[ -n "$endpoint_index" && "$endpoint_index" != "null" ]]; then
        log_info "找到现有配置，更新索引 $endpoint_index"
        # 更新现有配置
        # 保留原有的 isPublic 状态
        original_is_public=$(yq ".imSession.endPoints[$endpoint_index].baseInfo.isPublic" "$SERVE_FILE" 2>/dev/null || echo "false")
        
        # 更新 baseInfo 和 adapter
        yq -i "
            .imSession.endPoints[$endpoint_index].baseInfo.platform = \"QQ\" |
            .imSession.endPoints[$endpoint_index].baseInfo.relWorkDir = \"x\" |
            .imSession.endPoints[$endpoint_index].baseInfo.enable = true |
            .imSession.endPoints[$endpoint_index].baseInfo.protocolType = \"onebot\" |
            .imSession.endPoints[$endpoint_index].baseInfo.isPublic = $original_is_public |
            .imSession.endPoints[$endpoint_index].adapter.isReverse = false |
            .imSession.endPoints[$endpoint_index].adapter.reverseAddr = \"\" |
            .imSession.endPoints[$endpoint_index].adapter.connectUrl = \"ws://napcat:1234\" |
            .imSession.endPoints[$endpoint_index].adapter.accessToken = \"\" |
            .imSession.endPoints[$endpoint_index].adapter.useInPackGoCqhttp = false |
            .imSession.endPoints[$endpoint_index].adapter.builtinMode = \"gocq\" |
            .imSession.endPoints[$endpoint_index].adapter.inPackGoCqLastAutoLoginTime = 0 |
            .imSession.endPoints[$endpoint_index].adapter.inPackGoCqHttpLoginSucceeded = false |
            .imSession.endPoints[$endpoint_index].adapter.inPackGoCqHttpLastRestricted = 0 |
            .imSession.endPoints[$endpoint_index].adapter.forcePrintLog = false |
            .imSession.endPoints[$endpoint_index].adapter.inPackGoCqHttpProtocol = 0 |
            .imSession.endPoints[$endpoint_index].adapter.inPackGoCqHttpAppVersion = \"\" |
            .imSession.endPoints[$endpoint_index].adapter.inPackGoCqHttpPassword = \"\" |
            .imSession.endPoints[$endpoint_index].adapter.ignoreFriendRequest = false |
            .imSession.endPoints[$endpoint_index].adapter.implementation = \"gocq\" |
            .imSession.endPoints[$endpoint_index].adapter.useSignServer = false |
            .imSession.endPoints[$endpoint_index].adapter.signServerConfig = null |
            .imSession.endPoints[$endpoint_index].adapter.extraArgs = \"\" |
            .imSession.endPoints[$endpoint_index].adapter.signServerVer = \"\" |
            .imSession.endPoints[$endpoint_index].adapter.signServerName = \"\"
        " "$SERVE_FILE"
        
        log_info "已更新现有配置，保留 isPublic 状态: $original_is_public"
    else
        log_info "未找到骰子QQ $DICE_QQ 的配置，创建新的端点"
        # 创建新的端点配置到临时文件
        NEW_ENDPOINT_FILE=$(mktemp)
        cat > "$NEW_ENDPOINT_FILE" << EOF
baseInfo:
  id: $(uuidgen)
  nickname: ""
  state: 2
  userId: QQ:$DICE_QQ
  groupNum: 0
  cmdExecutedNum: 0
  cmdExecutedLastTime: 0
  onlineTotalTime: 0
  platform: QQ
  relWorkDir: x
  enable: true
  protocolType: onebot
  isPublic: false
adapter:
  isReverse: false
  reverseAddr: ""
  connectUrl: ws://napcat:1234
  accessToken: ""
  useInPackGoCqhttp: false
  builtinMode: gocq
  inPackGoCqLastAutoLoginTime: 0
  inPackGoCqHttpLoginSucceeded: false
  inPackGoCqHttpLastRestricted: 0
  forcePrintLog: false
  inPackGoCqHttpProtocol: 0
  inPackGoCqHttpAppVersion: ""
  inPackGoCqHttpPassword: ""
  ignoreFriendRequest: false
  implementation: gocq
  useSignServer: false
  signServerConfig: null
  extraArgs: ""
  signServerVer: ""
  signServerName: ""
EOF
        # 使用 yq 将新端点添加到数组末尾
        yq -i '.imSession.endPoints += [load("'"$NEW_ENDPOINT_FILE"'")]' "$SERVE_FILE"
        rm -f "$NEW_ENDPOINT_FILE"
        log_info "已添加新的端点配置"
    fi
    
    # 删除其他QQ账号的配置（保留当前骰子QQ）
    # 获取所有不是当前骰子QQ的QQ端点索引
    indices_to_delete=$(yq ".imSession.endPoints | to_entries | map(select(.value.baseInfo.userId != \"QQ:$DICE_QQ\" and (.value.baseInfo.userId // \"\") | startswith(\"QQ:\"))) | map(.key) | .[]" "$SERVE_FILE" 2>/dev/null || echo "")
    
    if [[ -n "$indices_to_delete" ]]; then
        log_info "删除其他QQ账号配置"
        # 需要从后往前删除，避免索引变化
        for idx in $(echo "$indices_to_delete" | sort -rn); do
            yq -i "del(.imSession.endPoints[$idx])" "$SERVE_FILE"
        done
    fi
    
    log_info "serve.yaml 修改完成"
fi

# 4. 处理 dice.yaml
DICE_FILE="data/dice.yaml"
if [[ -f "$DICE_FILE" ]]; then
    log_info "找到 dice.yaml，修改端口为 3211"
    # 备份原文件
    cp "$DICE_FILE" "$DICE_FILE.backup"
    
    # 使用 yq 修改 serveAddress
    if yq -e '.serveAddress' "$DICE_FILE" > /dev/null 2>&1; then
        yq -i '.serveAddress = "0.0.0.0:3211"' "$DICE_FILE"
        log_info "已修改 serveAddress 为 0.0.0.0:3211"
    else
        log_warn "dice.yaml 中未找到 serveAddress 字段，添加新字段"
        yq -i '.serveAddress = "0.0.0.0:3211"' "$DICE_FILE"
    fi
else
    log_info "未找到 dice.yaml，跳过修改"
fi

log_info "napcat 配置完成"