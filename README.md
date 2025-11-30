# sealdice-docker
海豹骰非官方Docker镜像，补全运行库，允许使用内置Lagrange登录.

[Docker Hub](https://hub.docker.com/r/shiaworkshop/sealdice)

镜像会自动根据上游发布而构建，支持amd64/arm64

## 标签说明

本镜像的构建分为三种大类构成

- 最新发布版本(latest) -> 对应所有通道中最新的版本
- 正式发布版本(release) -> 对应有版本号的正式发布版本
- 抢先体验版本(pre-release) -> 对应预发布通道的版本

正式发布版本(release)标签会推送为： `latest` / `v1.x.x` / `stable`

抢先体验版本(pre-release)标签会推送为： `latest` / `10aa805`(commit hash) / `pre`

## 🚀 一键部署脚本使用说明

### 基础用法（推荐新手）
```bash
curl -L https://dice.zone/bash/sealdice_onekey.sh -o sealdice_onekey.sh && chmod +x sealdice_onekey.sh && bash sealdice_onekey.sh
```

### 进阶用法

#### 部署多个海豹（最多99个）
```bash
curl -L https://dice.zone/bash/sealdice_onekey.sh -o sealdice_onekey.sh && chmod +x sealdice_onekey.sh && bash sealdice_onekey.sh -n 3
```
部署3个海豹，然后按提示输入3个不同的QQ号。

#### 指定版本渠道
```bash
curl -L https://dice.zone/bash/sealdice_onekey.sh -o sealdice_onekey.sh && chmod +x sealdice_onekey.sh && bash sealdice_onekey.sh -c stable
```
使用stable版本渠道部署海豹。

#### 组合使用
```bash
curl -L https://dice.zone/bash/sealdice_onekey.sh -o sealdice_onekey.sh && chmod +x sealdice_onekey.sh && bash sealdice_onekey.sh -n 2 -c latest
```
- 部署2个海豹
- 使用latest版本渠道

### 📋 参数说明

- `-n` : 部署海豹数量（1-99，默认1个）
- `-c` : 版本渠道（latest/stable/pre，默认latest）


### 🔧 版本渠道说明

- `latest` : 最新版本（推荐）
- `stable` : 稳定版本
- `pre` : 预发布版本

### 📱 访问地址

脚本运行完成后会显示：
- **[MCSManager管理面板](https://github.com/MCSManager/MCSManager)** : 端口23333，用来管理海豹
- **[海豹](https://github.com/sealdice/sealdice-build)WebUI** : 端口32110开始，每个海豹端口不同
- **[NapCat](https://github.com/NapNeko/NapCat-Docker)管理** : 端口22000开始，每个海豹端口不同

### ⚠️ 注意事项

1. **需要开放端口**：在云服务器控制台开放显示的端口
2. **QQ号不能重复**：每个海豹必须使用不同的QQ号
3. **第一个自动启动**：只有第一个海豹会自动启动，其他需要手动启动
4. **等待镜像下载**：第一次运行需要下载镜像，请耐心等待

### 🛠️ 常见问题

**Q: 脚本运行失败？**
A: 检查网络连接，确保能访问GitHub和Docker Hub

**Q: 忘记了访问地址？**
A: 脚本最后会显示所有访问地址，注意保存，也可以查看compose文件

**Q: 如何启动其他海豹？**
A: 登录MCSManager面板，手动点击启动其他实例

---
💡 **提示**：新手建议直接运行 `curl -L https://dice.zone/bash/sealdice_onekey.sh -o sealdice_onekey.sh && chmod +x sealdice_onekey.sh && bash sealdice_onekey.sh`，按提示操作即可！
