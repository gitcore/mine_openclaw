#!/bin/bash

set -e

SERVER="pi@192.168.1.10"
REMOTE_DIR="~/openclaw"

echo "=========================================="
echo "开始部署 OpenCLAW 到 $SERVER"
echo "=========================================="

echo ""
echo "步骤 1: 检查远程服务器连接和 Docker 环境..."
ssh $SERVER "echo '✓ 连接成功' && whoami && docker --version && docker compose version"

echo ""
echo "步骤 2: 配置 Docker 权限..."
ssh $SERVER "sudo usermod -aG docker pi || echo '用户已在 docker 组中'"

echo ""
echo "步骤 3: 停止并删除旧容器..."
ssh $SERVER "docker stop openclaw 2>/dev/null || true && docker rm openclaw 2>/dev/null || true"

echo ""
echo "步骤 4: 在远程服务器创建部署目录..."
ssh $SERVER "mkdir -p $REMOTE_DIR"

echo ""
echo "步骤 5: 创建并设置 volumes 目录权限..."
ssh $SERVER "mkdir -p $REMOTE_DIR/volumes/node/.openclaw && mkdir -p $REMOTE_DIR/volumes/node/.openclaw-cache && sudo chown -R 1000:1000 $REMOTE_DIR/volumes"

echo ""
echo "步骤 6: 创建 docker-compose.yml 文件..."
ssh $SERVER "cat > $REMOTE_DIR/docker-compose.yml << 'EOF'
services:
  openclaw:
    image: 192.168.1.10:5000/openclaw:latest
    container_name: openclaw
    restart: unless-stopped
    ports:
      - '18789:18789'
    volumes:
      - ./volumes/node/.openclaw:/home/node/.openclaw
      - ./volumes/node/.openclaw-cache:/home/node/.openclaw-cache
    environment:
      - NODE_ENV=production
      - OPENCLAW_GATEWAY_BIND=0.0.0.0
EOF"

echo ""
echo "步骤 7: 启动 OpenCLAW 容器..."
ssh $SERVER "cd $REMOTE_DIR && docker compose up -d"

echo ""
echo "步骤 8: 等待容器启动..."
ssh $SERVER "sleep 10"

echo ""
echo "步骤 9: 检查容器状态..."
ssh $SERVER "docker ps | grep openclaw"

echo ""
echo "步骤 10: 执行 OpenCLAW onboarding..."
ssh $SERVER "cd $REMOTE_DIR && docker compose exec -T openclaw openclaw onboard --non-interactive --mode local --auth-choice volcengine-api-key --volcengine-api-key \"4cea450e-7cb9-47af-97b7-f3586b3c83ee\" || echo 'Onboarding 已完成'"

echo ""
echo "步骤 11: 配置允许的源列表..."
ssh $SERVER "cd $REMOTE_DIR && docker compose exec -T openclaw openclaw config set gateway.controlUi.allowedOrigins '[\"http://192.168.31.188:18789\",\"http://localhost:18789\",\"http://127.0.0.1:18789\"]' || echo '配置已设置'"

echo ""
echo "步骤 12: 配置允许不安全认证..."
ssh $SERVER "cd $REMOTE_DIR && docker compose exec -T openclaw openclaw config set gateway.controlUi.allowInsecureAuth true || echo '配置已设置'"

echo ""
echo "步骤 13: 配置禁用设备认证..."
ssh $SERVER "cd $REMOTE_DIR && docker compose exec -T openclaw openclaw config set gateway.controlUi.dangerouslyDisableDeviceAuth true || echo '配置已设置'"

echo ""
echo "步骤 14: 配置默认 AI 模型..."
ssh $SERVER "cd $REMOTE_DIR && docker compose exec -T openclaw openclaw config set agents.defaults.model.primary \"volcengine/deepseek-v3-2-251201\" || echo '配置已设置'"

echo ""
echo "步骤 15: 重启网关使配置生效..."
ssh $SERVER "cd $REMOTE_DIR && docker compose exec -T openclaw openclaw gateway restart || echo '网关已重启'"

echo ""
echo "步骤 16: 等待网关重启..."
ssh $SERVER "sleep 10"

echo ""
echo "步骤 17: 获取访问信息..."
ssh $SERVER "cd $REMOTE_DIR && docker compose exec -T openclaw openclaw dashboard --no-open"

echo ""
echo "=========================================="
echo "✓ OpenCLAW 部署完成！"
echo "=========================================="
echo ""
echo "访问地址: http://192.168.31.188:18789"
echo ""
echo "常用命令："
echo "  查看日志: ssh $SERVER 'cd $REMOTE_DIR && docker compose logs -f'"
echo "  查看状态: ssh $SERVER 'cd $REMOTE_DIR && docker compose exec openclaw openclaw gateway status'"
echo "  设备列表: ssh $SERVER 'cd $REMOTE_DIR && docker compose exec openclaw openclaw devices list'"
echo "  配置向导: ssh $SERVER 'cd $REMOTE_DIR && docker compose exec openclaw openclaw config'"
echo "  停止服务: ssh $SERVER 'cd $REMOTE_DIR && docker compose down'"
echo "  重启服务: ssh $SERVER 'cd $REMOTE_DIR && docker compose restart'"
echo ""
echo "配置文件位置: $REMOTE_DIR/volumes/node/.openclaw/openclaw.json"
echo ""
