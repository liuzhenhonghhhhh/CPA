#!/bin/bash
set -e

INSTALL_DIR="/opt/cli-proxy-api"
SERVICE_NAME="cli-proxy-api"
BINARY_NAME="CLIProxyAPI-linux-amd64"

echo "=== CLIProxyAPI 一键部署脚本 ==="

# 检查 root
if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 用户运行: sudo bash install.sh"
  exit 1
fi

# 创建目录
echo "[1/5] 创建目录..."
mkdir -p "$INSTALL_DIR"/{auths,logs}

# 复制文件
echo "[2/5] 复制文件..."
cp "$BINARY_NAME" "$INSTALL_DIR/CLIProxyAPI"
chmod +x "$INSTALL_DIR/CLIProxyAPI"

if [ ! -f "$INSTALL_DIR/config.yaml" ]; then
  cp config.example.yaml "$INSTALL_DIR/config.yaml"
  echo "  已生成 config.yaml，请稍后编辑配置"
else
  echo "  config.yaml 已存在，跳过覆盖"
fi

# 创建 systemd 服务
echo "[3/5] 配置 systemd 服务..."
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=CLIProxyAPI
After=network.target

[Service]
Type=simple
User=root
Environment=HOME=/root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/CLIProxyAPI
Restart=on-failure
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
echo "[4/5] 启动服务..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

# 检查状态
echo "[5/5] 检查状态..."
sleep 2
if systemctl is-active --quiet "$SERVICE_NAME"; then
  echo ""
  echo "=== 部署成功 ==="
  echo "  服务状态: 运行中"
  echo "  监听端口: 8317"
  echo "  配置文件: $INSTALL_DIR/config.yaml"
  echo "  认证目录: $INSTALL_DIR/auths"
  echo "  日志目录: $INSTALL_DIR/logs"
  echo ""
  echo "常用命令:"
  echo "  编辑配置: nano $INSTALL_DIR/config.yaml"
  echo "  重启服务: systemctl restart $SERVICE_NAME"
  echo "  查看日志: journalctl -u $SERVICE_NAME -f"
  echo "  停止服务: systemctl stop $SERVICE_NAME"
else
  echo ""
  echo "=== 服务启动失败 ==="
  echo "查看日志: journalctl -u $SERVICE_NAME --no-pager -n 20"
  exit 1
fi
