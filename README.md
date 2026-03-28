# sealdice-docker
海豹骰非官方Docker镜像，补全运行库，支持内置Lagrange、Milky登录。

[Docker Hub](https://hub.docker.com/r/shiaworkshop/sealdice)

镜像自动根据上游发布构建，支持 amd64/arm64 架构。

## 镜像说明

镜像构建分为三类：

- **最新发布版本 (latest)** - 对应所有通道中的最新版本
- **正式发布版本 (release)** - 对应有版本号的正式发布版本
- **抢先体验版本 (pre-release)** - 对应预发布通道的版本

正式发布版本 (release) 标签为：`latest` / `v1.x.x` / `stable`

抢先体验版本 (pre-release) 标签为：`latest` / `10aa805` (commit hash) / `pre`


## 一键部署脚本使用说明

### 基础用法（推荐新手）
```bash
bash <(curl -sL seal.dice.zone)
```
- 下载脚本后执行，支持交互式引导
- 无需记忆参数，按提示操作即可

### 参数用法
```bash
bash <(curl -sL seal.dice.zone) -n 3 -c stable -m builtin
```
- 部署 3 个海豹
- 使用 stable（稳定版）版本渠道
- 使用内置登录方式（仅海豹核心，无外部适配器）

### 参数说明

- `-n`：部署海豹数量（1-99，默认 1 个）
- `-c`：版本渠道（latest/stable/pre，默认 latest）
- `-m`：登录方式（napcat/llbot，默认 napcat）

### 版本渠道说明

- `latest`：最新版本
- `stable`：稳定版本（推荐）
- `pre`：预发布版本

### 访问地址

脚本运行完成后会显示以下访问地址：
- **[MCSManager 管理面板](https://github.com/MCSManager/MCSManager)**：端口 23333，用于管理容器启停
- **[海豹](https://github.com/sealdice/sealdice-build) WebUI**：端口 32110 开始递增，每个海豹实例端口不同
- **[NapCat](https://github.com/NapNeko/NapCat-Docker) 或 [LLBot](https://github.com/LLOneBot/LuckyLilliaBot) 管理界面**：端口 22000 开始递增，每个海豹实例端口不同

### 使用方法

1. 脚本完成后会显示所有访问地址和端口，请妥善保存
2. 打开浏览器访问 MCSManager 面板，设置管理员账号密码
3. 进入面板后点击对应实例卡片，进入控制台查看运行状态
4. 在控制台查看字符形态二维码进行扫码登录
5. 若字符二维码显示不全，可进入文件管理的 `qrcode` 文件夹扫描图片二维码
6. 若显示登录成功但骰子无响应，点击实例的 `重启` 按钮
7. 为每个海豹实例重复上述登录步骤
8. **切勿在海豹 WebUI 内点击更新**，如需更新请通过 MCSManager 面板操作。点击 `关闭` 实例，然后点击 `更新`。
9. 如需调整配置，可编辑对应实例目录下的 `docker-compose.yml` 文件
