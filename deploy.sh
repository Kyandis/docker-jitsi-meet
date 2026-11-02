#!/usr/bin/env bash
# 一键部署 Jitsi Meet（内部会议用）
# 用法：
#   DOMAIN=meet.example.com EMAIL=me@example.com ./deploy.sh
#   DOMAIN=1.2.3.4 ./deploy.sh            # 无域名，纯 HTTP 模式
set -euo pipefail

DOMAIN="${DOMAIN:?必须设置 DOMAIN（域名或公网 IP）}"
EMAIL="${EMAIL:-admin@${DOMAIN}}"
CONFIG_DIR="${CONFIG_DIR:-/opt/jitsi/cfg}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-443}"

cd "$(dirname "$0")"

setvar() {
  local key="$1" val="$2"
  if grep -qE "^#?${key}=" .env; then
    sed -i "0,/^#\?${key}=.*/s|^#\?${key}=.*|${key}=${val}|" .env
  else
    printf '%s=%s\n' "${key}" "${val}" >>.env
  fi
}

# 1. 安装 docker
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
fi
docker compose version >/dev/null 2>&1 || apt-get install -y docker-compose-plugin

# 2. 公网 IP 还是域名
if [[ "$DOMAIN" =~ ^[0-9.]+$ ]]; then
  MODE=http
  PUBLIC="http://${DOMAIN}:${HTTP_PORT}"
  DISABLE_HTTPS_VAL=1
  LE_VAL='#ENABLE_LETSENCRYPT=1'
else
  MODE=https
  PUBLIC="https://${DOMAIN}"
  DISABLE_HTTPS_VAL=0
  LE_VAL='ENABLE_LETSENCRYPT=1'
fi

# 3. 生成 .env
cp -f .env.template .env
setvar CONFIG               "$CONFIG_DIR"
setvar PUBLIC_URL           "$PUBLIC"
setvar HTTP_PORT            "$HTTP_PORT"
setvar HTTPS_PORT           "$HTTPS_PORT"
setvar DISABLE_HTTPS        "$DISABLE_HTTPS_VAL"
setvar ENABLE_LETSENCRYPT   "$LE_VAL"
setvar LETSENCRYPT_DOMAIN   "$DOMAIN"
setvar LETSENCRYPT_EMAIL    "$EMAIL"
setvar JVB_ADVERTISE_IPS    "$DOMAIN"
setvar JVB_COLIBRI_PORT     8081
setvar TZ                   "${TZ:-Asia/Shanghai}"

# 4. 生成 Jitsi 内部密码
./gen-passwords.sh

# 5. 数据目录
mkdir -p "${CONFIG_DIR}"/{web,transcripts,prosody/config,prosody/prosody-plugins-custom,jicofo,jvb,jigasi,jibri}

# 6. 系统防火墙
if command -v ufw >/dev/null 2>&1; then
  ufw allow "${HTTP_PORT}"/tcp || true
  ufw allow "${HTTPS_PORT}"/tcp || true
  ufw allow 10000/udp || true
fi
if command -v firewall-cmd >/dev/null 2>&1; then
  firewall-cmd --permanent --add-port="${HTTP_PORT}"/tcp || true
  firewall-cmd --permanent --add-port="${HTTPS_PORT}"/tcp || true
  firewall-cmd --permanent --add-port=10000/udp || true
  firewall-cmd --reload || true
fi

# 7. 启动
docker compose up -d
sleep 15
docker compose ps

cat <<EOF

部署模式：${MODE}
访问地址：${PUBLIC}

云厂商安全组必须放行：${HTTP_PORT}/tcp  ${HTTPS_PORT}/tcp  10000/udp
验证：curl -I ${PUBLIC}
EOF
