# 使用 Ubuntu 24.04 基础镜像
FROM ubuntu:24.04

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 安装依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata \
    libicu74 \
    ca-certificates \
    wget \
    tar \
    jq \
 && rm -rf /var/lib/apt/lists/*

# 创建目录结构
RUN mkdir -p /sealdice /release-backup /sealdice/data /sealdice/backup

# 设置工作目录
WORKDIR /sealdice

# 声明卷
VOLUME ["/sealdice"]

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

# 生成入口脚本
RUN echo "#!/bin/sh" > /entrypoint.sh && \
    echo "cp -r /release-backup/* /sealdice/" >> /entrypoint.sh && \
    echo "cd /sealdice" >> /entrypoint.sh && \
    echo "./sealdice-core" >> /entrypoint.sh && \
    chmod +x /entrypoint.sh

# 暴露端口并启动
EXPOSE 3211
ENTRYPOINT [ "/entrypoint.sh" ]
