# 使用 Ubuntu 24.04 基础镜像
FROM ubuntu:24.04

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 安装依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata \
    libicu74 \
    libstdc++6 \
    ca-certificates \
    wget \
    tar \
    jq \
    uuid-runtime \
 && rm -rf /var/lib/apt/lists/*

# 创建目录结构
RUN mkdir -p /sealdice /release-backup /sealdice/data /sealdice/backup

# 设置工作目录
WORKDIR /sealdice

# 声明卷
VOLUME ["/sealdice/data", "/sealdice/backup"]

# 添加配置文件
ARG CONFIG_FILE
COPY $CONFIG_FILE /config.json

# 根据构建类型和架构选择下载链接
ARG BUILD_TYPE
ARG TARGETARCH

RUN set -eux; \
    # 确定架构
    case "$TARGETARCH" in \
        amd64) ARCH="amd64" ;; \
        arm64) ARCH="arm64" ;; \
        *) ARCH="amd64" ;; \
    esac; \
    \
    # 调试信息
    echo "构建类型: $BUILD_TYPE"; \
    echo "架构: $ARCH"; \
    \
    # 获取下载URL
    DOWNLOAD_URL=$(jq -r ".downloads.linux_$ARCH" /config.json); \
    \
    # 如果找不到小写格式，尝试首字母大写
    if [ "$DOWNLOAD_URL" = "null" ]; then \
        DOWNLOAD_URL=$(jq -r ".downloads.Linux_$ARCH" /config.json); \
    fi; \
    \
    echo "下载URL: $DOWNLOAD_URL"; \
    \
    # 下载并解压
    wget -q "$DOWNLOAD_URL" -O /tmp/sealdice.tar.gz; \
    tar -xzf /tmp/sealdice.tar.gz -C /release-backup ; \
    rm /tmp/sealdice.tar.gz; \
    chmod -R 755 /release-backup/*

# 安装 yq
ARG TARGETARCH
RUN wget "https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_${TARGETARCH}" -O /usr/local/bin/yq && chmod +x /usr/local/bin/yq

# 生成入口脚本
COPY configure-onebot.sh /configure-onebot.sh
RUN chmod +x /configure-onebot.sh
# 最后一行必须 exec。
#
# 不 exec 的话容器里的 PID 1 是这个 sh，sealdice-core 只是它的子进程。停止容器
# 时 Docker 把 SIGTERM 发给 PID 1，而 sh 在等前台子进程期间既不转发信号、也要等
# 子进程退出才处理它——于是宽限期白等，到点整个 cgroup 被 SIGKILL，骰子没有机会
# 落盘。实测：不加 exec 停止耗时 10 秒、退出码 137；加了 exec 是 0 秒、退出码 0。
RUN echo "#!/bin/sh" > /entrypoint.sh && \
    echo "set -e" >> /entrypoint.sh && \
    echo "cp -r /release-backup/* /sealdice/" >> /entrypoint.sh && \
    echo "cd /sealdice" >> /entrypoint.sh && \
    echo "if [ \"\$MODE\" = \"napcat\" ] || [ \"\$MODE\" = \"llbot\" ]; then" >> /entrypoint.sh && \
    echo "    cp /configure-onebot.sh ./configure-onebot.sh" >> /entrypoint.sh && \
    echo "    ./configure-onebot.sh || { echo \"configure-onebot.sh failed\"; exit 1; }" >> /entrypoint.sh && \
    echo "fi" >> /entrypoint.sh && \
    echo "exec ./sealdice-core" >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# 暴露端口并启动
EXPOSE 3211
ENTRYPOINT [ "/entrypoint.sh" ]
