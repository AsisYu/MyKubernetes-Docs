## 方案一：安装 screen（推荐先启用 EPEL 仓库）

### 1. 安装并启用 EPEL 仓库

```bash
# CentOS 9 安装 EPEL
dnf install -y epel-release

# 如果上面的命令失败，使用国内阿里云镜像
dnf install -y https://mirrors.aliyun.com/epel/epel-release-latest-9.noarch.rpm
```

### 2. 更新缓存并安装 screen

```bash
# 清除并重建缓存
dnf clean all
dnf makecache

# 安装 screen
dnf install -y screen
```

### 3. 配置阿里云 EPEL 镜像（加速下载）

```bash
# 备份原配置
sed -e 's|^metalink=|#metalink=|g' \
    -e 's|^#baseurl=https\?://download.example/pub|baseurl=https://mirrors.aliyun.com|g' \
    -i.bak \
    /etc/yum.repos.d/epel*.repo

# 再次更新缓存
dnf makecache
```

## 方案二：使用 tmux（强烈推荐的替代品）

`tmux` 是一个比 `screen` 更现代、功能更强大的终端复用器，在 CentOS 9 的默认仓库中就有：

```bash
# 直接安装 tmux
dnf install -y tmux
```

### tmux 基本使用（对应 screen 的命令）

| 功能 | screen 命令 | tmux 命令 |
|------|------------|-----------|
| 新建会话 | `screen -S name` | `tmux new -s name` |
| 分离会话 | `Ctrl+a d` | `Ctrl+b d` |
| 列出会话 | `screen -ls` | `tmux ls` |
| 重新连接 | `screen -r name` | `tmux attach -t name` |
| 杀死会话 | `screen -X -S name quit` | `tmux kill-session -t name` |

### tmux 快速入门

```bash
# 创建新会话
tmux new -s mysession

# 在会话中工作...

# 分离会话（保持程序运行）
# 按 Ctrl+b，然后按 d

# 查看所有会话
tmux ls

# 重新连接到会话
tmux attach -t mysession
```

## 推荐方案

我**建议直接使用 tmux**，原因：
1. ✅ CentOS 9 默认仓库就有，无需额外配置
2. ✅ 功能更强大（分屏、会话管理更好）
3. ✅ 更活跃的维护和社区支持
4. ✅ 更好的性能
