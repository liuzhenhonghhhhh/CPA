# CLIProxyAPI 部署套件

魔改CPA，解放你的辣鸡VPS，codex专用！

## 项目简介

- **定制管理面板** — 配套后端自定义改动的 `management.html`（非官方原版）
- **不再全量内存加载token** — 每次只读取500个token文件，自动补量，401 403 429 会自动进行删除
- **一键部署脚本** — 适用于 Linux 服务器的 `install.sh`，自动配置 systemd 服务
- **批量认证上传工具** — `upload_tokens.py`，支持并发上传认证文件
- **桌面管理 UI** — `python-ui/`，基于 PySide6 的本地桌面管理客户端

## 功能特性

- 支持 Gemini CLI / Claude Code / OpenAI Codex / Qwen Code / iFlow 多通道 OAuth
- 多账户轮询负载均衡
- 流式/非流式响应
- 函数调用/工具支持
- 多模态输入（文本+图片）
- Amp CLI 和 IDE 扩展集成
- OpenAI 兼容上游提供商配置
- Web 管理面板 + 桌面管理 UI

## 目录结构

```
├── cmd/                    # Go 入口
│   └── server/main.go
├── internal/               # Go 核心逻辑
├── sdk/                    # 可嵌入的 Go SDK
├── deploy/                 # 部署文件
│   ├── install.sh          # 一键部署脚本
│   ├── config.example.yaml # 配置模板
│   └── static/             # 管理面板 HTML（需自行放入）
├── python-ui/              # PySide6 桌面管理客户端
│   ├── main.py
│   ├── api_client.py
│   ├── main_window.py
│   └── theme.py
├── upload_tokens.py        # 批量认证文件上传工具
├── config.example.yaml     # 配置模板
├── install.sh              # 根目录部署脚本
├── Dockerfile              # Docker 构建
├── docker-compose.yml      # Docker Compose 配置
└── examples/               # SDK 示例代码
```

## 快速开始

### 1. 编译

```bash
# 交叉编译 Linux amd64 二进制
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o deploy/CLIProxyAPI ./cmd/server
```

### 2. 配置

复制配置模板并编辑：

```bash
cp config.example.yaml config.yaml
nano config.yaml
```

关键配置项：

```yaml
# 服务端口
port: 8317

# 管理 API 密钥（首次启动后自动哈希）
remote-management:
  allow-remote: false          # 是否允许远程管理访问
  secret-key: "your-secret"   # 管理密钥，留空则禁用管理 API

# API 认证密钥
api-keys:
  - "your-api-key"
```

### 3. 部署到服务器

```bash
# 上传 deploy 目录到服务器
scp -r deploy/ root@your-server:/root/CLIProxyAPI/

# SSH 到服务器执行一键部署
ssh root@your-server
cd /root/CLIProxyAPI
sudo bash install.sh
```

部署脚本会自动完成：
- 复制二进制到 `/opt/cli-proxy-api/`
- 部署管理面板到 `/opt/cli-proxy-api/static/`
- 生成配置文件（如不存在）
- 创建 systemd 服务并启动

### 4. 常用运维命令

```bash
# 查看服务状态
systemctl status cli-proxy-api

# 查看实时日志
journalctl -u cli-proxy-api -f

# 重启服务
systemctl restart cli-proxy-api

# 编辑配置
nano /opt/cli-proxy-api/config.yaml

# 停止服务
systemctl stop cli-proxy-api
```

## Docker 部署

```bash
docker-compose up -d
```

默认挂载卷：
- `./config.yaml` → 容器配置文件
- `./auths/` → 认证文件目录
- `./logs/` → 日志目录

## 辅助工具

### 批量上传认证文件

```bash
# 基本用法
python upload_tokens.py --host 127.0.0.1 --key your-management-key --token-dir ./tokens

# 预览模式（不实际上传）
python upload_tokens.py --dry-run --token-dir ./tokens

# 自定义并发数
python upload_tokens.py --workers 20 --token-dir ./tokens
```

### 桌面管理 UI

```bash
cd python-ui
pip install -r requirements.txt
python main.py
```

首次启动会弹出连接对话框，填写服务器地址和管理密钥即可。

连接配置保存在 `python-ui/connection.json`（已被 `.gitignore` 忽略）。

## 配置说明

完整配置参考 `config.example.yaml`，支持以下提供商：

| 提供商 | 认证方式 | 配置字段 |
|--------|----------|----------|
| Gemini | API Key / OAuth | `gemini-api-key` |
| Claude | API Key / OAuth | `claude-api-key` |
| Codex (GPT) | API Key / OAuth | `codex-api-key` |
| Vertex AI | API Key | `vertex-api-key` |
| OpenAI 兼容 | API Key | `openai-compatibility` |
| Amp | OAuth | `ampcode` |

## 注意事项

- **管理面板**：本项目使用定制版 `management.html`，不兼容官方原版
- **安全**：`config.yaml` 和 `connection.json` 包含敏感信息，已在 `.gitignore` 中排除
- **密钥**：`secret-key` 在首次启动后会自动哈希存储，无需手动处理



## 许可证

本项目基于 MIT License，详见 [LICENSE](LICENSE) 文件。
