# 部署与 fork 维护

本仓库是 [jitsi/docker-jitsi-meet](https://github.com/jitsi/docker-jitsi-meet) 的 fork，用于自建内部会议服务。
所有自有改动只放在 `deploy` 分支，`master` 保持与上游一致。

## 分支约定

| 分支 | 用途 | 是否追上游 |
|---|---|---|
| `master` | 上游镜像 | 是，只快进合并 |
| `deploy` | 自有部署脚本、模板、文档 | 否，定期 rebase 到上游 tag |

## 首次部署

服务器要求：Linux x86_64/arm64，2 核 4G 起，公网 IP。

```bash
git clone -b deploy https://github.com/Kyandis/docker-jitsi-meet.git
cd docker-jitsi-meet

# 有域名（推荐，自动签 Let's Encrypt 证书）
DOMAIN=meet.example.com EMAIL=you@example.com ./deploy.sh

# 只有 IP，无域名
DOMAIN=1.2.3.4 ./deploy.sh
```

脚本会装 Docker、生成 `.env`、生成内部密码、放行端口、启动容器。

## 安全组必须放行

| 端口 | 协议 | 用途 |
|---|---|---|
| 80 | TCP | 证书签发、HTTP 跳转 |
| 443 | TCP | 网页与信令 |
| 10000 | UDP | 音视频媒体流 |

`10000/udp` 没放行 = 进会议黑屏、只有声音没画面。这是最常见的故障。

## 建账号（内部会议必开）

`.env.template` 默认已开 `ENABLE_AUTH=1` + `ENABLE_GUESTS=1`，即主持人登录、参会者免注册。

```bash
docker compose exec prosody prosodyctl \
  --config /config/prosody.cfg.lua \
  register alice meet.jitsi '强密码'
```

## 同步上游

```bash
git fetch upstream --tags
git checkout master && git merge --ff-only upstream/master
git push origin master

# 把 deploy 分支挪到新 tag 上
git checkout deploy
git rebase stable-XXXX
git push -f origin deploy
```

升级服务器：

```bash
git pull
docker compose pull
docker compose up -d
```

## 运维

```bash
docker compose ps                 # 状态
docker compose logs -f jvb        # 媒体服务日志
docker compose logs -f prosody    # 信令日志
docker compose down               # 停止
```

## 目录

```
.
├── deploy.sh          # 一键部署
├── .env.template      # 配置模板（不含密码）
├── .gitignore         # 屏蔽 .env 与 cfg/
└── DEPLOY.md          # 本文档
```

`.env` 与 `cfg/` 永不入库。
