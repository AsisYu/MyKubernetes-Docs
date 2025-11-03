# 使用阿里源安装Kubernetes集群完整指南

> **文档更新说明（2025-11-03）**：
> - ⭐ **新增**：为所有涉及镜像源的步骤添加海外环境安装说明
> - ⭐ **新增**：国内环境和海外环境的方案对比和选择指导
> - 优化了文档结构，每个需要配置镜像源的地方都提供两种方案
> - 涵盖：Containerd安装、pause镜像配置、Kubernetes源、kubeadm init、Flannel部署
> - 海外用户现在可以直接使用官方源，无需阿里云加速

> **文档更新说明（2025-10-23）**：
> - 🔴 **重大修正**：修复了高可用集群负载均衡器方案的严重错误
> - 🔴 **明确指出**：Keepalived + VIP 方案只适用于同一网段，跨网段必须使用独立LB服务器
> - 将独立负载均衡器方案调整为首选方案（方案A）
> - 优化了集群架构选择流程，明确区分单Master和高可用两种部署模式
> - 修复了高可用集群部署顺序问题（负载均衡器配置现在在初始化之前）
> - 增强了hosts配置说明，根据不同架构提供对应配置
> - 整合了高可用集群部署文档，流程更清晰
> - ⭐ **重要修正**：明确说明 Keepalived 和 HAProxy 的区别和配合使用
> - ⭐ **新增**：详细的负载均衡器验证步骤，避免"VIP可ping但6443端口拒绝连接"的常见错误
> - ⭐ **新增**：7.8节详细的负载均衡器问题排查和解决方案

---

## **环境说明与方案选择**

本文档支持国内和海外两种网络环境的部署：

### **国内环境（中国大陆）**
- **特点**：官方源（registry.k8s.io、quay.io等）访问慢或无法访问
- **解决方案**：全程使用阿里云镜像源加速
- **适用范围**：
  - Docker/Containerd安装源
  - Kubernetes pause镜像
  - Kubernetes组件下载源
  - kubeadm初始化镜像仓库
  - Flannel网络插件镜像

### **海外环境（国际/香港/台湾等）**
- **特点**：可直接访问官方源，速度快且稳定
- **解决方案**：使用官方镜像源
- **优势**：
  - 版本更新及时
  - 无需额外配置镜像加速
  - 与官方文档保持一致

### **如何选择**

在后续每个需要配置镜像源的步骤中，文档都会提供：
- **方案A：国内环境配置**（使用阿里源）
- **方案B：海外环境配置**（使用官方源）

请根据您服务器的实际网络环境选择对应方案。

---

以下是在CentOS 9节点（master+2 worker）上安装kubelet、kubeadm、kubectl的详细流程，包含环境准备、依赖安装、组件部署和全面验证等步骤。

---

## 🔴 部署前必读：网络拓扑决策

**在开始部署之前，您必须明确您的网络拓扑！**

| 您的环境 | 必须使用的方案 | 跳转链接 |
|---------|--------------|---------|
| **Master和Worker在不同网段** | 独立负载均衡器服务器（方案A） | [跳转到方案A](#方案a独立负载均衡器服务器强烈推荐适用任何网络拓扑-) |
| **所有节点在同一网段** | 方案A 或 方案B 都可以 | [跳转到负载均衡器选择](#选择负载均衡方案) |
| **单Master测试环境** | 不需要负载均衡器 | [跳转到单Master部署](#4a单master集群部署简单模式) |

⚠️ **常见致命错误**：
- 跨网段环境使用了 Keepalived + VIP 方案 → Worker无法加入集群
- 原因：VIP基于ARP协议，只能在同一二层网络生效，跨网段无法访问
- 解决：必须使用独立的负载均衡器服务器（方案A）

---

**关键提示**：
- 如果您要部署**测试/学习环境**，建议选择 [4A：单Master集群部署](#4a单master集群部署简单模式)
- 如果您要部署**生产环境**，强烈建议选择 [4B：高可用集群部署](#4b高可用集群部署生产模式)


## **目录**
- [前提说明](#前提说明)
- [第一步：所有节点的基础环境准备](#第一步所有节点的基础环境准备必做)
  - [1.1 关闭防火墙](#11-关闭防火墙k8s需要直接访问节点端口)
  - [1.2 关闭SELinux](#12-关闭selinux避免权限拦截)
  - [1.3 关闭Swap](#13-关闭swapk8s要求禁用swap)
  - [1.4 配置主机名与Hosts解析](#14-配置主机名与hosts解析确保节点间互通)
  - [1.5 时间同步](#15-时间同步避免节点时间不一致导致证书问题)
  - [1.6 加载k8s所需内核模块](#16-加载k8s所需内核模块)
  - [1.7 配置内核参数](#17-配置内核参数优化网络转发)
  - [1.8 验证基础环境配置](#18-验证基础环境配置)
- [第二步：所有节点安装容器运行时](#第二步所有节点安装容器运行时containerd)
  - [2.1 安装Containerd](#21-安装containerd使用阿里源)
  - [2.2 配置Containerd](#22-配置containerd适配k8s要求)
  - [2.3 验证Containerd安装](#23-验证containerd安装)
- [第三步：所有节点安装kube组件](#第三步所有节点安装kubeletkubeadmkubectl阿里源)
  - [3.1 添加阿里k8s源](#31-添加阿里k8s源)
  - [3.2 安装kube组件](#32-安装kube组件)
  - [3.3 验证kube组件安装](#33-验证kube组件安装)
- [第四步：选择集群架构并初始化Master](#第四步选择集群架构并初始化master)
  - [4A：单Master集群部署（简单模式）](#4a单master集群部署简单模式)
    - [4A.1 初始化集群](#4a1-初始化集群关键步骤)
    - [4A.2 配置kubectl权限](#4a2-配置kubectl权限master节点)
    - [4A.2.1 获取Worker节点加入命令](#4a21-获取worker节点加入命令重要)
    - [4A.3 安装网络插件](#4a3-安装网络插件flannelmaster节点)
    - [4A.4 验证Master节点初始化完成](#4a4-验证master节点初始化完成)
    - [4A.5 单Master集群部署完成检查](#4a5-单master集群部署完成检查)
  - [4B：高可用集群部署（生产模式）](#4b高可用集群部署生产模式)
    - [4B.1 第一步：配置负载均衡器](#4b1-第一步配置负载均衡器)
      - [方案A：独立负载均衡器服务器（强烈推荐，适用任何网络拓扑）](#方案a独立负载均衡器服务器强烈推荐适用任何网络拓扑)
      - [方案B：Keepalived + HAProxy（仅限同一网段）](#方案bkeepalived--haproxy仅限同一网段)
      - [验证负载均衡器配置（必须验证）](#验证负载均衡器配置必须验证)
    - [4B.2 第二步：初始化第一个Master节点](#4b2-第二步初始化第一个master节点)
    - [4B.3 第三步：配置kubectl](#4b3-第三步配置kubectl)
    - [4B.4 第四步：安装网络插件（Flannel）](#4b4-第四步安装网络插件flannel)
    - [4B.5 第五步：添加其他Master节点（可选）](#4b5-第五步添加其他master节点可选)
    - [4B.6 验证高可用集群](#4b6-验证高可用集群)
    - [4B.7 高可用集群部署完成检查](#4b7-高可用集群部署完成检查)
- [第五步：Worker节点加入集群](#第五步worker节点加入集群仅在worker执行)
  - [5.0 前置条件检查](#50-前置条件检查非常重要)
  - [5.1 获取并执行join命令](#51-获取并执行join命令)
  - [5.2 Worker节点加入完成检查](#52-worker节点加入完成检查)
- [第五步补充：添加额外Master节点（高可用集群）](#第五步补充添加额外master节点高可用集群)
  - [5A.1 高可用架构说明（请参考4B部分）](#5a1-高可用架构说明请参考4b部分)
  - [5A.1.1 流量走向说明](#5a11-流量走向说明)
  - [5A.2 前提条件](#5a2-前提条件)
  - [5A.3 获取Master加入命令](#5a3-获取master加入命令)
  - [5A.4 在新Master节点执行加入](#5a4-在新master节点执行加入)
  - [5A.5 验证多Master集群](#5a5-验证多master集群)
  - [5A.6 常见问题](#5a6-常见问题)
  - [5A.7 高可用集群最佳实践](#5a7-高可用集群最佳实践)
- [第六步：全面验证集群状态](#第六步全面验证集群状态master节点执行)
  - [6.1 节点状态验证](#61-节点状态验证)
  - [6.2 系统组件验证](#62-系统组件验证)
  - [6.3 网络功能验证](#63-网络功能验证)
  - [6.4 DNS功能验证](#64-dns功能验证)
  - [6.5 查看集群整体信息](#65-查看集群整体信息)
  - [6.6 验证成功输出示例](#66-验证成功输出示例)
  - [6.7 集群部署完成确认](#67-集群部署完成确认)
- [第七步：常见问题排查与解决](#第七步常见问题排查与解决)
  - [7.1 kubelet启动失败](#71-kubelet启动失败)
  - [7.2 镜像拉取失败](#72-镜像拉取失败)
  - [7.3 节点状态NotReady](#73-节点状态notready)
  - [7.4 worker节点无法加入集群](#74-worker节点无法加入集群)
  - [7.5 Token过期无法加入worker节点](#75-token过期无法加入worker节点)
  - [7.6 coredns一直处于Pending状态](#76-coredns一直处于pending状态)
  - [7.7 通用问题排查命令](#77-通用问题排查命令)
  - [7.8 高可用集群负载均衡器问题](#78-高可用集群负载均衡器问题)
  - [7.9 验证环境一致性检查清单](#79-验证环境一致性检查清单)
- [总结](#总结)

---

## **前提说明**
- 节点信息：
  - 负载均衡器（高可用需要）：主机名 k8s-Load-Balancer-gz，IP 172.16.3.1
  - master节点：主机名k8s-master-gz，IP 172.16.0.10
  - worker01节点：主机名`k8s-woker01-gz`（注意：用户提供的主机名含拼写`woker`，建议确认是否为`worker`，以下按原名称执行），IP`172.16.1.10`
  - worker02节点：主机名`k8s-woker02-gz`，IP`172.16.1.11`
- 所有操作需在**root权限**下执行（或`sudo`）
- 全程使用阿里镜像源加速（解决国内网络问题）
- 注意各个服务器之间的安全组规则


### **第一步：所有节点的基础环境准备（必做）**
以下操作需在 **master、worker01、worker02 三个节点同时执行**。


#### 1.1 关闭防火墙（k8s需要直接访问节点端口）
```bash
# 停止并禁用firewalld
systemctl stop firewalld
systemctl disable firewalld
```


#### 1.2 关闭SELinux（避免权限拦截）
```bash
# 临时关闭
setenforce 0
# 永久关闭（重启生效）
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config
```


#### 1.3 关闭Swap（k8s要求禁用swap）
```bash
# 临时关闭
swapoff -a
# 永久关闭（注释swap挂载行）
sed -i '/swap/s/^/#/' /etc/fstab
```


#### 1.4 配置主机名与Hosts解析（确保节点间互通）

**步骤1：设置主机名**
```bash
# 分别在四个个节点设置主机名（按节点执行）
# master节点：
hostnamectl set-hostname k8s-master-gz
# worker01节点：
hostnamectl set-hostname k8s-woker01-gz
# worker02节点：
hostnamectl set-hostname k8s-woker02-gz
# Load Balancer负载均衡器节点（如需要）：
hostnamectl set-hostname k8s-woker02-gz
```

**步骤2：配置hosts映射**

⚠️ **重要**：请根据您的集群类型选择对应的配置

**选项A：单Master集群配置（测试/学习环境）**
```bash
# 所有节点执行（仅配置实际节点IP）
cat >> /etc/hosts << EOF
172.16.0.10  k8s-master-gz
172.16.1.10  k8s-woker01-gz
172.16.1.11  k8s-woker02-gz
EOF
```

**选项B：高可用集群配置（生产环境）**
```bash
# 所有节点执行（包含VIP地址）
# ⚠️ 注意：VIP需要在初始化前通过负载均衡器配置，详见第四步
cat >> /etc/hosts << EOF
172.16.3.1 k8s-Load-Balancer-gz
172.16.0.10  k8s-master-gz
172.16.0.11  k8s-master02-gz
172.16.0.12  k8s-master03-gz
172.16.1.10  k8s-woker01-gz
172.16.1.11  k8s-woker02-gz
EOF
```

> 💡 **说明**：
> - 单Master集群只需配置实际节点IP即可
> - 高可用集群需要配置VIP（172.16.3.1），但VIP必须在初始化Master前通过Keepalived或HAProxy配置好
> - 如果您还不确定选择哪种模式，建议先看第四步的架构选择说明


#### 1.5 时间同步（避免节点时间不一致导致证书问题）
```bash
# 安装chrony时间同步工具
dnf install -y chrony
# 启动并设置开机自启
systemctl start chronyd
systemctl enable chronyd
# 同步时间（国内阿里云时间服务器）
chronyc sources
```


#### 1.6 加载k8s所需内核模块
```bash
# 创建模块配置文件
cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF

# 加载模块
modprobe overlay
modprobe br_netfilter

# 验证模块是否加载成功（返回内容即为成功）
lsmod | grep overlay
lsmod | grep br_netfilter
```


#### 1.7 配置内核参数（优化网络转发）
```bash
# 创建内核参数配置文件
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# 生效配置
sysctl --system
```


#### 1.8 验证基础环境配置
```bash
# 检查防火墙状态（应显示inactive/dead）
systemctl status firewalld

# 检查SELinux状态（应显示Disabled或Permissive）
getenforce

# 检查swap状态（Swap行应全为0）
free -m

# 检查主机名（应显示当前节点设置的主机名）
hostname

# 检查hosts解析（应能ping通其他节点）
ping -c 2 k8s-master-gz
ping -c 2 k8s-woker01-gz
ping -c 2 k8s-woker02-gz

# 检查内核模块（应有返回结果）
lsmod | grep overlay
lsmod | grep br_netfilter

# 检查内核参数（所有值应为1）
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
sysctl net.ipv4.ip_forward
```
> **验证成功标准**：防火墙关闭、SELinux关闭、swap为0、节点互通、内核参数正确加载。


### **第二步：所有节点安装容器运行时（Containerd）**
k8s从1.24起不再支持Docker（需通过containerd），这里直接安装containerd并配置镜像源。


#### 2.1 安装Containerd

**方案选择：根据您的网络环境选择对应方案**

---

**方案A：国内环境（使用阿里源，推荐）**

适用于：中国大陆服务器，解决Docker官方源访问慢的问题

```bash
# 添加Docker阿里源（containerd包含在Docker源中）
cat > /etc/yum.repos.d/docker-ce.repo << EOF
[docker-ce-stable]
name=Docker CE Stable - \$basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/\$releasever/\$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg
EOF

# 安装containerd
dnf install -y containerd.io
```

---

**方案B：海外环境（使用Docker官方源）**

适用于：海外服务器、香港、台湾等地区，官方源速度快

```bash
# 添加Docker官方源
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# 或手动创建配置文件
cat > /etc/yum.repos.d/docker-ce.repo << EOF
[docker-ce-stable]
name=Docker CE Stable - \$basearch
baseurl=https://download.docker.com/linux/centos/\$releasever/\$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/centos/gpg
EOF

# 安装containerd
dnf install -y containerd.io
```

**说明**：
- 国内环境推荐使用阿里源，下载速度快（1-2分钟）
- 海外环境使用官方源，速度更快且更稳定
- 两种方案安装的containerd版本和功能完全相同


#### 2.2 配置Containerd（适配k8s要求）

**第一步：生成默认配置文件（所有环境相同）**

```bash
# 生成默认配置文件
containerd config default > /etc/containerd/config.toml
```

---

**第二步：修改pause镜像源（根据环境选择）**

**选项A：国内环境（使用阿里云镜像，推荐）**

```bash
# 替换沙箱镜像为阿里源（默认registry.k8s.io在国内无法访问）
sed -i "s#sandbox_image = \".*\"#sandbox_image = \"registry.aliyuncs.com/google_containers/pause:3.9\"#g" /etc/containerd/config.toml

# 验证配置
grep "sandbox_image" /etc/containerd/config.toml
# 应该显示：sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9"
```

**选项B：海外环境（使用官方镜像源）**

```bash
# 海外环境可以直接访问官方镜像，无需修改或使用以下配置
# 选项1：保持默认配置（registry.k8s.io，推荐）
# 无需执行任何命令，跳过此步骤

# 选项2：或明确指定官方源
sed -i "s#sandbox_image = \".*\"#sandbox_image = \"registry.k8s.io/pause:3.9\"#g" /etc/containerd/config.toml

# 验证配置
grep "sandbox_image" /etc/containerd/config.toml
# 应该显示：sandbox_image = "registry.k8s.io/pause:3.9" 或保持原默认值
```

**说明**：
- 国内环境必须使用阿里云镜像，否则镜像拉取会超时
- 海外环境可直接使用官方源 `registry.k8s.io`，速度更快
- pause镜像是K8s的基础镜像，每个Pod都需要

---

**第三步：启用SystemdCgroup（所有环境必须执行）**

```bash
# 启用SystemdCgroup（k8s推荐配置）
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# 验证SystemdCgroup配置
grep "SystemdCgroup = true" /etc/containerd/config.toml
# 应该显示：SystemdCgroup = true
```

---

**第四步：重启服务并验证（所有环境相同）**

```bash
# 重启containerd并设置开机自启
systemctl restart containerd
systemctl enable containerd
systemctl status containerd
```

---

**⚠️ 重要提醒**：
- 必须验证配置修改成功后再继续！
- 如果 `grep` 没有显示正确的镜像地址，说明sed替换失败
- 这种情况需要手动编辑：`vim /etc/containerd/config.toml`
- **Master和所有Worker节点都必须执行此配置**
- **所有节点必须使用相同的镜像源配置**

> 💡 **说明**：pause镜像的拉取测试需要使用 `crictl` 命令，该命令在安装Kubernetes组件后才可用。镜像拉取验证将在 [2.3节](#23-验证containerd安装) 和 [3.3节](#33-验证kube组件安装) 之后进行。


#### 2.3 验证Containerd安装

**第一步：基础验证（所有环境）**

```bash
# 检查containerd服务状态（应显示active/running）
systemctl status containerd

# 检查containerd版本
containerd --version

# 验证SystemdCgroup配置（必须为true）
grep "SystemdCgroup = true" /etc/containerd/config.toml

# 测试containerd运行（应无报错）
ctr version
```

---

**第二步：镜像源配置验证（根据环境选择）**

**国内环境验证**：

```bash
# 验证阿里云镜像配置
grep "registry.aliyuncs.com" /etc/containerd/config.toml
# 应该显示：sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9"
```

**海外环境验证**：

```bash
# 验证官方镜像配置
grep "sandbox_image" /etc/containerd/config.toml
# 应该显示：sandbox_image = "registry.k8s.io/pause:3.9" 或默认值
```

---

> **当前阶段验证成功标准**：
> - containerd服务运行正常（active/running）
> - SystemdCgroup配置为true
> - 镜像源配置正确（国内用阿里源，海外用官方源）
> - `ctr version` 命令可用
>
> 💡 **关于镜像拉取测试**：
> - `crictl` 命令需要安装 `cri-tools` 包才能使用
> - `cri-tools` 将在第三步安装Kubernetes组件时自动安装
> - 镜像拉取测试请在完成 [第三步](#第三步所有节点安装kubeletkubeadmkubectl) 后进行
> - 届时可以在 [3.3节验证kube组件安装](#33-验证kube组件安装) 后执行镜像拉取测试


### **第三步：所有节点安装kubelet、kubeadm、kubectl**
根据网络环境选择合适的镜像源安装组件。


#### 3.1 添加Kubernetes源

**方案选择：根据您的网络环境选择对应方案**

---

**方案A：国内环境（使用阿里源，推荐）**

适用于：中国大陆服务器，避免官方源访问超时

```bash
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF
```

> 说明：阿里暂未提供`el9`版本的k8s源，此处使用`el7`源（CentOS 9兼容多数el7包，若安装失败可尝试替换为`el8`源）。

---

**方案B：海外环境（使用官方源）**

适用于：海外服务器、香港、台湾等地区，官方源速度快

```bash
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
```

或使用旧版官方源（兼容性更好）：

```bash
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF
```

**说明**：
- 国内环境强烈推荐使用阿里源，官方源可能无法访问或极慢
- 海外环境使用官方源，可获得最新版本和更好的稳定性
- 新版官方源（pkgs.k8s.io）是Kubernetes官方推荐的仓库


#### 3.2 安装kube组件
```bash
# 安装指定版本（推荐1.28.x稳定版，可替换为其他版本）
dnf install -y kubelet-1.28.0 kubeadm-1.28.0 kubectl-1.28.0 --disableexcludes=kubernetes

# 启动kubelet并设置开机自启（此时kubelet会报错，初始化后解决）
systemctl enable --now kubelet
```


#### 3.3 验证kube组件安装

**第一步：基础验证（所有环境）**

```bash
# 检查组件版本（应显示1.28.0）
kubelet --version
kubeadm version
kubectl version --client

# 检查kubelet服务状态（此时可能显示failed，这是正常的，集群初始化后会自动恢复）
systemctl status kubelet

# 验证kube源配置
dnf repolist | grep kubernetes

# 验证crictl命令已安装（用于后续镜像操作）
crictl --version
```

---

**第二步：镜像拉取测试（可选，验证containerd配置）**

现在 `crictl` 命令已可用，可以测试pause镜像拉取：

**国内环境测试**：

```bash
# 测试拉取阿里云pause镜像
crictl pull registry.aliyuncs.com/google_containers/pause:3.9

# 查看镜像
crictl images | grep pause

# 应该看到：registry.aliyuncs.com/google_containers/pause
```

**海外环境测试**：

```bash
# 测试拉取官方pause镜像
crictl pull registry.k8s.io/pause:3.9

# 查看镜像
crictl images | grep pause

# 应该看到：registry.k8s.io/pause
```

---

> **验证成功标准**：
> - 三个组件版本均为1.28.0
> - kubernetes源已启用
> - `crictl` 命令可用
> - 能够成功拉取pause镜像（证明containerd配置正确）
>
> ⚠️ **注意**：
> - 此时kubelet服务可能处于失败状态，这是正常现象
> - kubelet会在执行 `kubeadm init` 后自动恢复
> - 如果镜像拉取失败，请检查第二步的containerd配置


### **第四步：选择集群架构并初始化Master**

⚠️ **重要决策点**：在初始化Master之前，请先选择集群架构类型！

---

### **单Master集群（推荐用于测试/学习）**
- 部署简单，快速上手
- 资源占用少（1个Master节点）
- Master故障会导致集群管理功能不可用
- 适用场景：学习、开发、测试环境
- **[跳转到 4A：单Master部署](#4a单master集群部署简单模式)**

### **高可用集群（推荐用于生产）**
- Master节点高可用，自动故障切换
- 生产环境可靠性高
- 需要额外配置负载均衡器
- 至少需要3个Master节点（奇数个）
- 适用场景：生产环境、高可用要求的场景
- **[跳转到 4B：高可用集群部署](#4b高可用集群部署生产模式)**

---

## **4A：单Master集群部署（简单模式）**

### 4A.1 初始化集群（关键步骤）

在**Master节点**执行以下命令（根据环境选择对应配置）：

---

**方案A：国内环境（使用阿里镜像仓库）**

```bash
kubeadm init \
  --image-repository registry.aliyuncs.com/google_containers \  # 阿里镜像仓库（国内加速）
  --kubernetes-version v1.28.0 \  # 与安装的kube组件版本一致
  --pod-network-cidr=10.244.0.0/16 \  # Pod网络网段（适配flannel网络插件）
  --apiserver-advertise-address=172.16.0.10  # Master节点IP（修改为实际IP）
```

---

**方案B：海外环境（使用官方镜像仓库）**

```bash
kubeadm init \
  --image-repository registry.k8s.io \  # 官方镜像仓库
  --kubernetes-version v1.28.0 \  # 与安装的kube组件版本一致
  --pod-network-cidr=10.244.0.0/16 \  # Pod网络网段（适配flannel网络插件）
  --apiserver-advertise-address=172.16.0.10  # Master节点IP（修改为实际IP）
```

或省略镜像仓库参数（使用默认官方源）：

```bash
kubeadm init \
  --kubernetes-version v1.28.0 \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=172.16.0.10
```

**说明**：
- 国内环境必须指定 `--image-repository` 为阿里源，否则镜像拉取会失败
- 海外环境可以使用官方源 `registry.k8s.io` 或直接省略该参数
- 确保 `--apiserver-advertise-address` 修改为您Master节点的实际IP

**初始化成功后的输出示例**：
```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 172.16.0.10:6443 --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

> ⚠️ **重要**：请务必**复制保存**上面输出的 `kubeadm join` 命令，后续worker节点加入集群时需要使用！

**注意事项**：
- 若初始化成功，务必保存 `kubeadm join` 命令
- 若失败，可执行 `kubeadm reset` 清理后重新初始化
- token默认有效期为24小时，过期后需重新生成（见下文4A.2.1）


### 4A.2 配置kubectl权限（Master节点）
```bash
# 配置当前用户的kubectl权限
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# 验证master节点状态（此时节点为NotReady，因为未安装网络插件）
kubectl get nodes

# 检查kubectl配置是否生效
kubectl cluster-info

# 查看kubelet服务状态（此时应为active/running）
systemctl status kubelet
```
> **验证成功标准**：kubectl命令可正常执行、kubelet服务运行正常、可以看到master节点（状态NotReady正常）。


### 4A.2.1 获取Worker节点加入命令（重要！）

如果在初始化时**忘记保存**join命令，或者**token已过期**（默认24小时），可以通过以下方式重新获取：

**方法1：查看现有token（推荐）**
```bash
# 查看所有可用的token
kubeadm token list

# 输出示例：
# TOKEN                     TTL         EXPIRES                USAGES                   DESCRIPTION
# abcdef.0123456789abcdef   23h         2025-10-23T10:30:00Z   authentication,signing   The default bootstrap token
```

如果有可用token（TTL不为0），使用现有token生成完整join命令：
```bash
# 生成完整的join命令（使用现有token）
kubeadm token create --print-join-command --ttl=0

# 输出类似：
# kubeadm join 172.16.0.10:6443 --token abcdef.0123456789abcdef --discovery-token-ca-cert-hash sha256:1234...
```

**方法2：创建新token并生成join命令**
```bash
# 创建永不过期的token并输出完整join命令
kubeadm token create --print-join-command --ttl=0

# 如果想创建24小时有效期的token（默认）
kubeadm token create --print-join-command
```

**方法3：手动拼接join命令**
```bash
# 1. 创建新token
kubeadm token create

# 2. 获取CA证书的hash值
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
  openssl rsa -pubin -outform der 2>/dev/null | \
  openssl dgst -sha256 -hex | sed 's/^.* //'

# 3. 手动拼接命令：
# kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

**快速获取命令（推荐）**：
```bash
# 最简单的方式，直接生成完整命令
kubeadm token create --print-join-command
```

> 💡 **提示**：
> - 生成的join命令会在终端直接输出，复制后在worker节点执行即可
> - 使用 `--ttl=0` 可以创建永不过期的token
> - 默认token有效期为24小时，过期后worker节点无法加入
> - 可以创建多个token，每个都可以用于worker节点加入


### 4A.3 安装网络插件（Flannel，Master节点）

k8s集群需要网络插件实现Pod互通，这里使用Flannel。

---

**方案A：国内环境（使用阿里镜像加速）**

```bash
# 下载flannel配置文件
wget https://raw.githubusercontent.com/flannel-io/flannel/v0.22.0/Documentation/kube-flannel.yml

# 如果wget下载失败（GitHub访问受限），使用以下备用方法：
# curl -O https://raw.githubusercontent.com/flannel-io/flannel/v0.22.0/Documentation/kube-flannel.yml
# 或使用本地已有的kube-flannel.yml文件

# 替换镜像地址为阿里源（避免quay.io访问超时）
sed -i "s#quay.io/coreos/flannel#registry.cn-hangzhou.aliyuncs.com/kubernetes-minions/flannel#g" kube-flannel.yml

# 或使用阿里云镜像加速
# sed -i "s#quay.io/coreos/flannel#registry.aliyuncs.com/google_containers/flannel#g" kube-flannel.yml

# 部署flannel
kubectl apply -f kube-flannel.yml

# 验证网络插件状态（所有pod状态为Running即为成功）
kubectl get pods -n kube-flannel

# 查看所有系统组件pod状态
kubectl get pods -n kube-system

# 查看flannel日志（确认无错误）
kubectl logs -n kube-flannel -l app=flannel --tail=20
```

---

**方案B：海外环境（使用官方镜像）**

```bash
# 下载flannel配置文件
wget https://raw.githubusercontent.com/flannel-io/flannel/v0.22.0/Documentation/kube-flannel.yml

# 海外环境可直接部署，无需修改镜像地址
kubectl apply -f kube-flannel.yml

# 或直接在线部署（推荐）
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/v0.22.0/Documentation/kube-flannel.yml

# 验证网络插件状态
kubectl get pods -n kube-flannel

# 查看所有系统组件pod状态
kubectl get pods -n kube-system

# 查看flannel日志
kubectl logs -n kube-flannel -l app=flannel --tail=20
```

---

**说明**：
- 国内环境必须替换镜像为阿里源，quay.io在国内无法访问
- 海外环境可直接使用官方镜像，速度更快且版本更新
- 等待2-3分钟，再次执行`kubectl get nodes`，Master节点状态变为`Ready`

### 4A.4 验证Master节点初始化完成
```bash
# 检查节点状态（应显示Ready）
kubectl get nodes

# 检查所有系统组件（所有pod应为Running）
kubectl get pods -A

# 验证coredns是否正常运行
kubectl get pods -n kube-system | grep coredns

# 检查kube-system命名空间下所有组件
kubectl get all -n kube-system

# 查看节点详细信息
kubectl describe node k8s-master-gz
```
> **验证成功标准**：Master节点状态为Ready、所有系统pod运行正常、coredns正常启动。

---

### **4A.5 单Master集群部署完成检查**

**当前状态**：
- Master节点已初始化
- kubectl已配置
- 网络插件Flannel已安装
- Master节点状态为Ready

**下一步**：
1. **如果有Worker节点**：继续 [第五步：Worker节点加入集群](#第五步worker节点加入集群仅在worker执行)
2. **Worker加入完成后**：执行 [第六步：全面验证集群状态](#第六步全面验证集群状态master节点执行)
3. **仅测试单节点**：直接执行 [第六步：全面验证集群状态](#第六步全面验证集群状态master节点执行)

**快速验证命令**：
```bash
# 一键检查集群状态
kubectl get nodes && kubectl get pods -A

# 应该看到：
# - Master节点 Ready
# - 所有系统Pod Running
```

---

> **单Master集群Master部分部署完成！** 接下来请：
> - 有Worker节点：跳转到 [第五步：Worker节点加入集群](#第五步worker节点加入集群仅在worker执行)
> - 无Worker节点：跳转到 [第六步：全面验证集群状态](#第六步全面验证集群状态master节点执行) 进行最终验证

---

## **4B：高可用集群部署（生产模式）**

⚠️ **注意**：高可用集群部署必须严格按照以下顺序执行

### 高可用集群部署流程

```
第一步：配置负载均衡器
    ↓
第二步：验证负载均衡器可用
    ↓
第三步：初始化第一个Master
    ↓
第四步：安装网络插件
    ↓
第五步：添加其他Master节点（可选）
    ↓
第六步：添加Worker节点
```

**关键提醒**：
- 负载均衡器必须先配置并验证通过，否则集群无法正常工作
- 跨网段环境必须使用**方案A（独立LB服务器）**
- 同一网段环境可选择方案A或方案B
- 不要跳过负载均衡器验证步骤

---

### 4B.1 第一步：配置负载均衡器

**为什么要先配置负载均衡器？**
- 高可用集群需要负载均衡器作为统一入口
- 初始化时必须指定负载均衡器地址（`--control-plane-endpoint`）
- 如果负载均衡器不存在，集群将无法使用
- 所有节点（包括Master和Worker）都通过负载均衡器访问API Server

**架构示意图：**
```
kubectl/Worker → 负载均衡器(172.16.3.1:6443) → Master1(172.16.0.10:6443)
                                                  → Master2(172.16.0.11:6443)
                                                  → Master3(172.16.0.12:6443)
```

---

#### 选择负载均衡方案

🔴 **重要警告：必须先确定您的网络拓扑！**

| 网络场景 | 推荐方案 | 说明 |
|---------|---------|------|
| **Master和Worker在不同网段** | 方案A（独立LB服务器） | 适用任何网络拓扑 |
| **所有节点在同一网段** | 方案A或方案B | 两种方案都可以 |
| **云环境（阿里云/AWS等）** | 云服务商LB | 最简单可靠 |

**核心概念说明**：
- **独立负载均衡器**：使用专门的服务器运行HAProxy/Nginx，支持任何网络拓扑
- **VIP（虚拟IP）+ Keepalived**：只能用于同一网段，基于ARP协议，跨网段无法使用
- **Keepalived**：只提供VIP漂移，**不提供负载均衡功能**
- **HAProxy/Nginx**：提供负载均衡和健康检查功能

---

#### 方案A：独立负载均衡器服务器（强烈推荐，适用任何网络拓扑）

**适用场景**：
- Master和Worker在不同网段
- 跨数据中心部署
- 任何生产环境

**架构说明**：
```bash
# 使用一台独立服务器（或多台做高可用）运行HAProxy
# 负载均衡器IP：172.16.3.1（可以跨网段访问）
# Master节点：172.16.0.10, 172.16.0.11, 172.16.0.12
# Worker节点：可以在任何网段（10.0.0.x, 192.168.x.x等）
```

**选项1：使用HAProxy（推荐）**

```bash
# 在LB服务器（例如：172.16.3.1）执行
dnf install -y haproxy

# 配置HAProxy
cat > /etc/haproxy/haproxy.cfg << 'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

# Kubernetes API Server负载均衡
frontend kubernetes-frontend
    bind *:6443                      # 监听所有网卡的6443端口
    mode tcp
    option tcplog
    default_backend kubernetes-backend

backend kubernetes-backend
    mode tcp
    option tcp-check
    balance roundrobin
    # 将下面的IP改为您的Master节点实际IP
    server master1 172.16.0.10:6443 check fall 3 rise 2
    server master2 172.16.0.11:6443 check fall 3 rise 2
    server master3 172.16.0.12:6443 check fall 3 rise 2
    # 如果只有单Master，只配置一个server即可

# 可选：添加HAProxy统计页面
listen stats
    bind *:9000
    mode http
    stats enable
    stats uri /haproxy-stats
    stats auth admin:admin123
    stats refresh 30s
EOF

# 启动HAProxy
systemctl enable haproxy
systemctl restart haproxy
systemctl status haproxy

# 验证HAProxy配置
haproxy -c -f /etc/haproxy/haproxy.cfg

# 查看监听端口
ss -tuln | grep 6443
```

**验证负载均衡器**：

```bash
# 在LB服务器本地测试
nc -zv 127.0.0.1 6443
telnet 127.0.0.1 6443

# 从其他服务器测试LB（重要！）
# 在Master节点或其他能访问LB的机器上执行
nc -zv 172.16.3.1 6443
telnet 172.16.3.1 6443
# 应该能连接成功

# 查看HAProxy统计信息（可选）
# 浏览器访问：http://172.16.3.1:9000/haproxy-stats
# 用户名：admin 密码：admin123
```

---

**选项2：使用Nginx（备选方案）**

```bash
# 在LB服务器（例如：172.16.3.1）执行
dnf install -y nginx nginx-mod-stream

# 配置Nginx
# 注意：stream块需要在http块之外
cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# 加载动态模块
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

# Kubernetes API Server TCP负载均衡
stream {
    log_format basic '$remote_addr [$time_local] '
                     '$protocol $status $bytes_sent $bytes_received '
                     '$session_time';

    access_log /var/log/nginx/k8s-access.log basic;

    upstream kubernetes {
        # 将下面的IP改为您的Master节点实际IP
        server 172.16.0.10:6443 max_fails=3 fail_timeout=30s;
        server 172.16.0.11:6443 max_fails=3 fail_timeout=30s;
        server 172.16.0.12:6443 max_fails=3 fail_timeout=30s;
        # 如果只有单Master，只配置一个server即可
    }

    server {
        listen 6443;
        proxy_pass kubernetes;
        proxy_timeout 10m;
        proxy_connect_timeout 1s;
    }
}

# HTTP服务（可选：用于健康检查页面）
http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    server {
        listen 8080;
        server_name _;
        
        location /health {
            access_log off;
            return 200 "LB is healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

# 测试Nginx配置
nginx -t

# 启动Nginx
systemctl enable nginx
systemctl restart nginx
systemctl status nginx

# 查看监听端口
ss -tuln | grep 6443
ss -tuln | grep 8080
```

**验证Nginx负载均衡器**：

```bash
# 在LB服务器本地测试
nc -zv 127.0.0.1 6443
telnet 127.0.0.1 6443

# 测试健康检查接口
curl http://127.0.0.1:8080/health

# 从其他服务器测试LB（重要！）
nc -zv 172.16.3.1 6443
telnet 172.16.3.1 6443
curl http://172.16.3.1:8080/health
```

---

**多LB服务器高可用配置（可选）**：

如果需要LB本身也高可用，可以部署2台LB服务器 + Keepalived：

```bash
# LB1 (172.16.3.1) 和 LB2 (192.168.1.101)
# 两台都安装HAProxy或Nginx（配置相同）
# 然后在两台LB上配置Keepalived提供VIP（例如192.168.1.200）
# 此时集群endpoint使用：192.168.1.200:6443
```

---

#### 方案B：Keepalived + HAProxy（仅限同一网段）

**适用场景**：
- 所有节点（Master和Worker）在**同一个网段/同一个VLAN**
- **不适用**于跨网段、跨数据中心部署
- **不适用**于Master和Worker在不同网段

**为什么有网段限制？**

Keepalived使用VRRP协议 + ARP广播实现VIP漂移：
- VIP通过ARP广播告知网络设备MAC地址映射
- ARP广播只能在同一个二层网络（同一交换机/VLAN）内传播
- 跨网段的机器无法通过ARP获取VIP的MAC地址
- **结果：跨网段的Worker节点无法访问VIP，即使能ping通也无法连接6443端口**

**如果您的环境符合条件，可以按以下步骤配置：**

**第一步：在所有Master节点安装HAProxy**

```bash
dnf install -y haproxy

# 配置HAProxy（所有Master节点配置相同）
cat > /etc/haproxy/haproxy.cfg << 'EOF'
global
    log /dev/log local0
    chroot /var/lib/haproxy
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend kubernetes-frontend
    bind *:6443
    mode tcp
    option tcplog
    default_backend kubernetes-backend

backend kubernetes-backend
    mode tcp
    option tcp-check
    balance roundrobin
    server master1 172.16.0.10:6443 check fall 3 rise 2
    server master2 172.16.0.11:6443 check fall 3 rise 2
    server master3 172.16.0.12:6443 check fall 3 rise 2
EOF

systemctl enable haproxy
systemctl restart haproxy
systemctl status haproxy
```

**第二步：在所有Master节点安装Keepalived**

```bash
dnf install -y keepalived

# Master1配置
cat > /etc/keepalived/keepalived.conf << 'EOF'
global_defs {
    router_id k8s-master-1
}

vrrp_script check_haproxy {
    script "/etc/keepalived/check_haproxy.sh"
    interval 3
    weight -2
    fall 2
    rise 2
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0    # 修改为您的网卡名称
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass k8s_ha_pass
    }
    virtual_ipaddress {
        172.16.3.1/24    # VIP必须与Master在同一网段
    }
    track_script {
        check_haproxy
    }
}
EOF

# 创建健康检查脚本
cat > /etc/keepalived/check_haproxy.sh << 'EOF'
#!/bin/bash
if [ $(ps -C haproxy --no-header | wc -l) -eq 0 ]; then
    exit 1
else
    exit 0
fi
EOF

chmod +x /etc/keepalived/check_haproxy.sh

systemctl enable keepalived
systemctl start keepalived

# 验证VIP
ip addr show | grep 172.16.3.1
```

**Master2和Master3配置**（修改priority和router_id）：
```bash
# Master2：state BACKUP, priority 90, router_id k8s-master-2
# Master3：state BACKUP, priority 80, router_id k8s-master-3
```

---
#### 验证负载均衡器配置（必须验证）

⚠️ **关键步骤**：必须全部通过才能继续初始化Master！

**方案A：独立负载均衡器验证**

```bash
# === 在LB服务器上验证 ===

# 1. 验证HAProxy服务状态
systemctl status haproxy
# 应该显示：active (running)

# 2. 验证HAProxy配置
haproxy -c -f /etc/haproxy/haproxy.cfg
# 应该显示：Configuration file is valid

# 3. 验证端口监听
ss -tuln | grep 6443
# 应该显示：*:6443 或 0.0.0.0:6443

# 4. 本地测试
nc -zv 127.0.0.1 6443
# 应该显示：succeeded

# === 从Master节点验证（重要！）===

# 5. 测试LB可达性
ping -c 3 172.16.3.1
nc -zv 172.16.3.1 6443
telnet 172.16.3.1 6443
# 应该能连接成功

# === 从Worker节点验证（最重要！）===

# 6. 测试跨网段访问
ping -c 3 172.16.3.1
nc -zv 172.16.3.1 6443
# 如果成功，说明配置正确，可以继续
# 如果失败，检查网络路由和防火墙
```

**方案B：Keepalived + HAProxy验证**

```bash
# === 在Master节点验证 ===

# 1. 验证HAProxy和Keepalived服务
systemctl status haproxy
systemctl status keepalived

# 2. 验证VIP绑定
ip addr show | grep 172.16.3.1
# 应该在某个网卡看到VIP

# 3. 测试VIP端口
nc -zv 172.16.3.1 6443
telnet 172.16.3.1 6443

# 4. 从Worker节点测试（必须在同一网段！）
ping -c 2 172.16.3.1
nc -zv 172.16.3.1 6443
```

**快速验证脚本（方案A）**：

```bash
#!/bin/bash
LB_IP="172.16.3.1"  # 修改为您的LB服务器IP

echo "=== 负载均衡器验证 ==="
echo ""

echo "当前主机：$(hostname)"
echo "测试目标：$LB_IP:6443"
echo ""

echo "1. 网络连通性测试："
ping -c 2 -W 2 $LB_IP > /dev/null 2>&1 && echo "ICMP可达" || echo "ICMP不可达"

echo ""
echo "2. 端口连通性测试："
nc -zv -w 3 $LB_IP 6443 2>&1 | grep -q "succeeded" && echo "端口6443可访问" || echo "端口6443不可访问"

echo ""
echo "3. 详细测试："
timeout 3 telnet $LB_IP 6443 2>&1 | head -3

echo ""
echo "=== 验证完成 ==="
echo ""
echo "如果端口6443不可访问，请检查："
echo "  1. LB服务器的HAProxy是否运行"
echo "  2. 防火墙是否放行6443端口"
echo "  3. 网络路由是否正确"
```

⚠️ **如果端口6443测试失败，请不要继续初始化Master！**

**常见失败原因及解决方法**：

| 症状 | 原因 | 解决方法 |
|------|------|----------|
| LB可以ping通，6443拒绝连接 | HAProxy未启动或配置错误 | `systemctl status haproxy`，检查配置 |
| HAProxy启动失败 | 配置文件语法错误或端口被占用 | `haproxy -c -f /etc/haproxy/haproxy.cfg`，`ss -tuln \| grep 6443` |
| 从Worker无法访问LB | 防火墙阻止 | `firewall-cmd --add-port=6443/tcp --permanent && firewall-cmd --reload` |
| 跨网段无法访问 | 路由不通或使用了VIP方案 | 检查路由表，**确保使用方案A（独立LB）而不是VIP** |
| VIP可以ping但Worker无法访问 | **跨网段使用了Keepalived VIP** | **必须改用方案A（独立LB服务器）** |

---

### 4B.2 第二步：初始化第一个Master节点

**前置确认清单**：

- [ ] 负载均衡器已配置并运行
- [ ] 负载均衡器端口可以访问（`nc -zv <LB_IP> 6443` 成功）
- [ ] 从Master节点能访问LB的6443端口
- [ ] 从Worker节点能访问LB的6443端口（跨网段测试）

**根据您选择的方案，使用对应的endpoint：**

- **方案A（独立LB）**：使用LB服务器IP，例如 `172.16.3.1:6443`
- **方案B（Keepalived + VIP）**：使用VIP地址，例如 `172.16.3.1:6443`

**在第一个Master节点（172.16.0.10）执行（根据环境选择对应配置）：**

---

**方案A：国内环境（使用阿里镜像仓库）**

```bash
# 使用独立LB服务器或Keepalived + VIP
kubeadm init \
  --image-repository registry.aliyuncs.com/google_containers \  # 阿里镜像仓库（国内加速）
  --kubernetes-version v1.28.0 \
  --pod-network-cidr=10.244.0.0/16 \
  --control-plane-endpoint "172.16.3.1:6443" \  # 负载均衡器地址（重要！）
  --upload-certs \  # 自动上传证书，允许其他Master加入（重要！）
  --apiserver-advertise-address=172.16.0.10  # 当前Master的实际IP
```

---

**方案B：海外环境（使用官方镜像仓库）**

```bash
# 使用独立LB服务器或Keepalived + VIP
kubeadm init \
  --image-repository registry.k8s.io \  # 官方镜像仓库
  --kubernetes-version v1.28.0 \
  --pod-network-cidr=10.244.0.0/16 \
  --control-plane-endpoint "172.16.3.1:6443" \  # 负载均衡器地址（重要！）
  --upload-certs \  # 自动上传证书，允许其他Master加入（重要！）
  --apiserver-advertise-address=172.16.0.10  # 当前Master的实际IP
```

或省略镜像仓库参数（使用默认官方源）：

```bash
kubeadm init \
  --kubernetes-version v1.28.0 \
  --pod-network-cidr=10.244.0.0/16 \
  --control-plane-endpoint "172.16.3.1:6443" \
  --upload-certs \
  --apiserver-advertise-address=172.16.0.10
```

---

**说明**：
- 国内环境必须使用阿里镜像仓库，否则镜像拉取会失败
- 海外环境可以使用官方源或省略该参数
- `--control-plane-endpoint` 根据您选择的负载均衡器方案填写对应地址

**关键参数说明**：
- `--control-plane-endpoint`：**负载均衡器地址**，所有节点都通过这个地址访问API Server
  - 方案A：LB服务器的真实IP
  - 方案B：Keepalived的VIP地址
- `--upload-certs`：将证书上传到集群，允许其他Master节点加入（证书有效期2小时）
- `--apiserver-advertise-address`：当前Master节点的实际IP

**初始化成功后的输出示例**：

```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You can now join any number of control-plane nodes by running the following command on each as root:

  kubeadm join 172.16.3.1:6443 --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:1234...abcd \
        --control-plane --certificate-key abc123...def456

Then you can join any number of worker-node by running the following on each as root:

kubeadm join 172.16.3.1:6443 --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:1234567890abcdef...
```

> ⚠️ **重要**：请务必保存以下两个命令：
> 1. **Master加入命令**（包含 `--control-plane` 和 `--certificate-key`）
> 2. **Worker加入命令**（不包含 `--control-plane`）

---

### 4B.3 第三步：配置kubectl

```bash
# 在第一个Master节点配置kubectl
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# 验证集群状态（此时节点为NotReady，因为未安装网络插件）
kubectl get nodes

# 验证API Server是否通过负载均衡器访问
kubectl cluster-info
# 应该显示: Kubernetes control plane is running at https://<您的负载均衡器地址>:6443
# 例如：https://172.16.3.1:6443 或 https://172.16.3.1:6443
```

---

### 4B.4 第四步：安装网络插件（Flannel）

**方案选择：根据您的网络环境选择对应方案**

---

**方案A：国内环境（使用阿里镜像）**

```bash
# 下载flannel配置文件
wget https://raw.githubusercontent.com/flannel-io/flannel/v0.22.0/Documentation/kube-flannel.yml

# 如果wget下载失败，使用本地已有文件或curl
# curl -O https://raw.githubusercontent.com/flannel-io/flannel/v0.22.0/Documentation/kube-flannel.yml

# 替换镜像地址为阿里源（必须执行）
sed -i "s#quay.io/coreos/flannel#registry.cn-hangzhou.aliyuncs.com/kubernetes-minions/flannel#g" kube-flannel.yml

# 部署flannel
kubectl apply -f kube-flannel.yml

# 验证网络插件状态
kubectl get pods -n kube-flannel

# 等待2-3分钟，再次查看节点状态
kubectl get nodes
# Master节点应该变为Ready状态
```

---

**方案B：海外环境（使用官方镜像）**

```bash
# 直接在线部署（推荐）
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/v0.22.0/Documentation/kube-flannel.yml

# 或下载后部署
wget https://raw.githubusercontent.com/flannel-io/flannel/v0.22.0/Documentation/kube-flannel.yml
kubectl apply -f kube-flannel.yml

# 验证网络插件状态
kubectl get pods -n kube-flannel

# 等待2-3分钟，再次查看节点状态
kubectl get nodes
# Master节点应该变为Ready状态
```

---

**说明**：
- 国内环境必须替换镜像为阿里源
- 海外环境可直接使用官方镜像，速度更快

---

### 4B.5 第五步：添加其他Master节点（可选）

如果需要部署多Master高可用集群（推荐3个或5个Master），在**其他Master节点**执行：

#### 4B.5.1 获取Master加入命令

如果初始化时的输出已经保存，直接使用。如果丢失或证书过期（2小时），在**第一个Master**执行：

```bash
# 重新上传证书
kubeadm init phase upload-certs --upload-certs

# 输出类似：
# [upload-certs] Using certificate key:
# abc123def456...

# 创建token并生成join命令
kubeadm token create --print-join-command

# 手动拼接完整的Master加入命令：
# 注意：将下面的地址改为您实际的负载均衡器地址
kubeadm join <负载均衡器地址>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <certificate-key>

# 示例（方案A - 独立LB）：
# kubeadm join 172.16.3.1:6443 \
#   --token <token> --discovery-token-ca-cert-hash sha256:<hash> \
#   --control-plane --certificate-key <certificate-key>

# 示例（方案B - VIP）：
# kubeadm join 172.16.3.1:6443 \
#   --token <token> --discovery-token-ca-cert-hash sha256:<hash> \
#   --control-plane --certificate-key <certificate-key>
```

#### 4B.5.2 在新Master节点执行加入

在**Master2、Master3**等节点执行上面获取的完整命令：

```bash
# 使用实际获取的命令，注意替换为您的负载均衡器地址
kubeadm join <负载均衡器地址>:6443 \
  --token abcdef.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:1234...abcd \
  --control-plane \
  --certificate-key abc123...def456
```

**成功输出**：
```
This node has joined the cluster and a new control plane instance was created:
* Certificate signing request was sent to apiserver and approval was received.
* The Kubelet was informed of the new secure connection details.
* Control plane label and taint were applied to the new node.
* The Kubernetes control plane instances scaled up.
```

**配置新Master节点的kubectl：**
```bash
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# 验证
kubectl get nodes
```

---

### 4B.6 验证高可用集群

```bash
# 1. 查看所有Master节点
kubectl get nodes
# 应该看到多个control-plane节点

# 2. 查看关键组件分布
kubectl get pods -n kube-system -o wide | grep -E "apiserver|controller|scheduler|etcd"
# 每个Master上都应该有这些组件

# 3. 验证etcd集群
kubectl exec -it -n kube-system etcd-k8s-master-gz -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list

# 4. 测试高可用性（可选）
# 停止Master1的kubelet，集群应该仍然可用
ssh root@172.16.0.10 "systemctl stop kubelet"
kubectl get nodes  # 应该仍然能执行
ssh root@172.16.0.10 "systemctl start kubelet"  # 恢复
```

---

### **4B.7 高可用集群部署完成检查**

**当前状态**：
- 负载均衡器已配置并运行
- 第一个Master节点已初始化
- kubectl已配置
- 网络插件Flannel已安装
- （可选）其他Master节点已加入
- 所有Master节点状态为Ready

**高可用验证清单**：
```bash
# 1. 检查负载均衡器是否可达
nc -zv <负载均衡器IP> 6443  # 应该成功

# 2. 检查Master节点数量
kubectl get nodes --selector='node-role.kubernetes.io/control-plane'
# 应该看到1个或多个Master节点

# 3. 检查etcd集群（如果是多Master）
kubectl get pods -n kube-system -l component=etcd
# 应该看到多个etcd pod

# 4. 验证通过LB访问
kubectl cluster-info
# 应该显示：Kubernetes control plane is running at https://<负载均衡器地址>:6443
```

**下一步**：
1. **如果有Worker节点**：继续 [第五步：Worker节点加入集群](#第五步worker节点加入集群仅在worker执行)
2. **Worker加入完成后**：执行 [第六步：全面验证集群状态](#第六步全面验证集群状态master节点执行)
3. **仅测试高可用Master**：直接执行 [第六步：全面验证集群状态](#第六步全面验证集群状态master节点执行)

**快速验证命令**：
```bash
# 一键检查高可用集群状态
echo "=== 负载均衡器 ===" && nc -zv <LB_IP> 6443 && \
echo "=== Master节点 ===" && kubectl get nodes && \
echo "=== 系统组件 ===" && kubectl get pods -A

# 预期结果：
# - 负载均衡器6443端口可访问
# - 所有Master节点 Ready
# - 所有系统Pod Running
```

---

> **高可用集群Master部分部署完成！** 接下来请：
> - 有Worker节点：跳转到 [第五步：Worker节点加入集群](#第五步worker节点加入集群仅在worker执行)
> - 无Worker节点：跳转到 [第六步：全面验证集群状态](#第六步全面验证集群状态master节点执行) 进行最终验证

---

### **第五步：Worker节点加入集群（仅在worker执行）**

#### 5.0 前置条件检查（⚠️ 非常重要）

**在Worker节点加入集群之前，必须确保以下配置正确：**

**第一步：检查containerd配置（最关键）**

根据您的环境检查对应的镜像源配置：

**国内环境检查**：

```bash
# 在每个Worker节点上执行

# 1. 检查Sandbox镜像配置
echo "=== 检查Sandbox镜像配置 ==="
grep "sandbox_image" /etc/containerd/config.toml
# 国内环境必须显示：sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9"
# 如果显示的是 registry.k8s.io 或 k8s.gcr.io，必须修改！

echo ""
echo "=== 检查SystemdCgroup配置 ==="
grep "SystemdCgroup = true" /etc/containerd/config.toml
# 必须显示：SystemdCgroup = true

# 2. 如果配置不正确，立即修复（国内环境）
# sed -i "s#sandbox_image = \".*\"#sandbox_image = \"registry.aliyuncs.com/google_containers/pause:3.9\"#g" /etc/containerd/config.toml
# sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
# systemctl restart containerd
# systemctl restart kubelet

# 3. 验证服务状态
systemctl status containerd | head -3
systemctl status kubelet | head -3

# 4. 测试镜像拉取（国内环境）
crictl pull registry.aliyuncs.com/google_containers/pause:3.9
crictl images | grep pause
```

**海外环境检查**：

```bash
# 在每个Worker节点上执行

# 1. 检查Sandbox镜像配置
echo "=== 检查Sandbox镜像配置 ==="
grep "sandbox_image" /etc/containerd/config.toml
# 海外环境应显示：sandbox_image = "registry.k8s.io/pause:3.9" 或保持默认值

echo ""
echo "=== 检查SystemdCgroup配置 ==="
grep "SystemdCgroup = true" /etc/containerd/config.toml
# 必须显示：SystemdCgroup = true

# 2. 如果SystemdCgroup配置不正确，修复
# sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
# systemctl restart containerd
# systemctl restart kubelet

# 3. 验证服务状态
systemctl status containerd | head -3
systemctl status kubelet | head -3

# 4. 测试镜像拉取（海外环境）
crictl pull registry.k8s.io/pause:3.9
crictl images | grep pause
```

---

**⚠️ 重要提醒**：
- **所有Worker节点必须与Master节点使用相同的镜像源配置**
- 国内Master + 国内Worker：都使用阿里源
- 海外Master + 海外Worker：都使用官方源
- **不要混用**：Master用阿里源，Worker用官方源（会导致镜像不一致）

**⚠️ 常见错误警告（国内环境）**：
- 如果Worker节点的containerd配置错误（使用registry.k8s.io），会导致：
  - Pod无法创建（Failed to create pod sandbox）
  - 镜像拉取超时（i/o timeout）
  - 节点一直处于NotReady状态
- **症状**：`kubectl describe pod` 显示 `failed to pull image "registry.k8s.io/pause:3.8": dial tcp xxx:443: i/o timeout`
- **解决**：必须修改containerd配置使用阿里云镜像源

---

#### 5.1 获取并执行join命令

**步骤1：在Master节点获取join命令**

如果在初始化master时已经保存了join命令，直接使用。如果忘记保存或token已过期，在master节点执行：

```bash
# 在master节点执行，生成join命令
kubeadm token create --print-join-command

# 输出类似：
# kubeadm join 172.16.0.10:6443 --token abcdef.0123456789abcdef \
#     --discovery-token-ca-cert-hash sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

> 💡 **提示**：关于获取join命令的更多方法，请参考 [4.2.1 获取Worker节点加入命令](#421-获取worker节点加入命令重要)

**步骤2：在Worker节点执行前置检查（必须！）**

```bash
# 在Worker节点执行，确保containerd配置正确
grep "sandbox_image" /etc/containerd/config.toml
grep "SystemdCgroup = true" /etc/containerd/config.toml

# 如果配置不正确，参考上面的 5.0 前置条件检查进行修复
```

**步骤3：在Worker节点执行join命令**

将上一步获取的完整命令，在**worker01和worker02节点**分别执行：

```bash
# 在worker节点执行（示例，请替换为实际获取的命令）
kubeadm join 172.16.0.10:6443 \
  --token abcdef.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

**成功输出示例**：
```
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

> **加入成功标志**：看到 "This node has joined the cluster" 提示


#### 5.1 验证Worker节点加入成功
在worker节点执行join命令后，需要进行以下验证：

**在worker节点本地验证：**
  ```bash
# 检查kubelet服务状态（应为active/running）
systemctl status kubelet

# 查看kubelet日志（确认连接成功）
journalctl -xeu kubelet --no-pager | tail -30
```

**在master节点验证（更重要）：**
```bash
# 查看所有节点状态（应看到3个节点，状态均为Ready）
kubectl get nodes

# 查看节点详细信息
kubectl get nodes -o wide

# 检查新加入节点的详情
kubectl describe node k8s-woker01-gz
kubectl describe node k8s-woker02-gz

# 验证所有节点的pod网络（flannel应在所有节点运行）
kubectl get pods -n kube-flannel -o wide
```
> **验证成功标准**：worker节点kubelet运行正常、在master上可以看到所有节点状态为Ready、flannel在所有节点运行。

---

### **5.2 Worker节点加入完成检查**

**当前状态**：
- Master节点已部署
- Worker节点已加入集群
- 所有节点kubelet运行正常
- 所有节点状态为Ready

**快速验证命令**：
```bash
# 在Master节点执行，一键检查所有节点
kubectl get nodes -o wide && echo "" && kubectl get pods -n kube-flannel

# 预期结果：
# - 所有节点（Master + Worker）都显示 Ready
# - 每个节点上都有一个flannel pod Running
```

**下一步：执行最终验证**

⚠️ **重要**：Worker加入完成后，必须执行 [第六步：全面验证集群状态](#第六步全面验证集群状态master节点执行) 来确认整个集群正常工作！

> **Worker节点加入完成！** 
> 
> **下一步（必做）**：跳转到 [第六步：全面验证集群状态](#第六步全面验证集群状态master节点执行) 进行最终的全面验证，确保集群所有功能正常！


---

## **第五步补充：添加额外Master节点（高可用集群）**

> 🔴 **重要提示**：本节内容已完全整合到 [4B：高可用集群部署](#4b高可用集群部署生产模式)！
> 
> **如果您要部署高可用集群，请直接查看4B部分，那里有最新、最完整的流程说明。**
> 
> 本节保留仅用于：
> - 理论知识参考（流量走向、架构说明）
> - 兼容旧版文档链接
> 
> **部署操作请以4B部分为准！**

---

### **5A.1 高可用架构说明（理论参考）**

> 💡 **实际部署流程请查看**：[4B.1 配置负载均衡器](#4b1-第一步配置负载均衡器) → [4B.5 添加其他Master节点](#4b5-第五步添加其他master节点可选)

**为什么需要多Master节点？**
- 单Master节点存在单点故障风险
- Master节点宕机会导致集群管理功能不可用
- 生产环境强烈建议部署多Master高可用架构

**高可用架构要求**：
```
                      ┌─────────────────┐
                      │  Load Balancer  │  (HAProxy/Nginx/VIP)
                      └────────┬────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
    ┌─────▼─────┐        ┌─────▼─────┐      ┌─────▼─────┐
    │  Master1  │        │  Master2  │      │  Master3  │
    │172.16.0.10│◄──────►│172.16.0.11│◄────►│172.16.0.12│
    └───────────┘        └───────────┘      └───────────┘
         │                     │                   │
    ┌────┴──────────────┬──────┴──────┬───────────┴────┐
    │                   │             │                │
┌───▼────┐        ┌────▼────┐   ┌────▼────┐    ┌─────▼────┐
│Worker1 │        │Worker2  │   │Worker3  │    │ Worker4  │
└────────┘        └─────────┘   └─────────┘    └──────────┘
```

**组件说明**：
- **Load Balancer（负载均衡器）**：必需，分发API Server请求
- **多个Master节点**：通常3个或5个（奇数个，便于etcd集群选举）
- **Etcd集群**：自动在多个Master节点间形成高可用

---

### **5A.1.1 流量走向说明**

**核心原则**：在高可用架构中，**所有访问API Server的请求都必须经过负载均衡器**，而不是直接访问某个Master节点。

#### **谁需要访问API Server？**

1. **kubectl命令**（管理员/用户）
2. **kubelet**（所有Worker和Master节点）
3. **kube-proxy**（所有节点）
4. **应用程序Pod**（需要访问K8s API时）
5. **其他Master节点的组件**（controller-manager、scheduler等）

#### **流量路径对比**

**错误方式（单点故障）**：
```
kubectl/Worker节点 ──────► Master1 (172.16.0.10:6443)
                           ↓ 宕机后整个集群不可用
```

**正确方式（高可用）**：
```
kubectl/Worker节点 ──────► Load Balancer (172.16.3.1:6443)
                           ├──► Master1 (172.16.0.10:6443) ✓
                           ├──► Master2 (172.16.0.11:6443) ✓
                           └──► Master3 (172.16.0.12:6443) ✓
                           任何一个Master宕机，LB自动切换到其他Master
```

#### **具体示例**

**1. kubectl命令配置**

查看您的kubectl配置文件（`~/.kube/config`），server地址应该是**负载均衡器地址**：

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ...
    server: https://172.16.3.1:6443  # 负载均衡器地址，不是单个Master
  name: kubernetes
```

**错误配置**：
```yaml
server: https://172.16.0.10:6443  # 单个Master，失去高可用意义
```

**2. Worker节点kubelet配置**

Worker节点加入集群时，也应该指向负载均衡器：

```bash
# 正确的join命令（指向LB）
kubeadm join 172.16.3.1:6443 --token xxx --discovery-token-ca-cert-hash sha256:xxx

# 错误的join命令（指向单个Master）
kubeadm join 172.16.0.10:6443 --token xxx --discovery-token-ca-cert-hash sha256:xxx
```

**3. 应用程序访问K8s API**

应用程序内部访问API Server时：

```bash
# 通过Service访问（推荐）
curl https://kubernetes.default.svc.cluster.local:443

# 或通过负载均衡器（外部访问）
curl https://172.16.3.1:6443

# 不要直接访问单个Master
curl https://172.16.0.10:6443
```

#### **为什么必须通过负载均衡器？**

| 特性 | 通过负载均衡器 | 直接访问Master节点 |
|------|----------------|-------------------|
| **高可用** | Master宕机自动切换 | 单点故障 |
| **负载均衡** | 请求分散到多个Master | 单节点压力大 |
| **故障转移** | 自动（秒级） | 需要手动修改配置 |
| **维护便利** | 可以逐个升级Master | 升级期间集群不可用 |
| **生产可用** | 符合最佳实践 | 不推荐 |

#### **特殊情况：何时直接访问Master？**

仅在以下**紧急故障排查**场景可以直接访问单个Master：

```bash
# 场景1：负载均衡器故障，临时访问Master1
kubectl --server=https://172.16.0.10:6443 get nodes

# 场景2：调试特定Master节点的API Server
curl -k https://172.16.0.10:6443/healthz

# 场景3：检查单个Master的组件状态
ssh root@172.16.0.10
crictl ps
```

**⚠️ 注意**：这些操作仅用于临时排查，正常情况下**始终通过负载均衡器访问**。

#### **验证配置是否正确**

在任意节点执行以下命令，确认指向负载均衡器：

```bash
# 检查kubectl配置
kubectl config view | grep server
# 输出应该是：server: https://172.16.3.1:6443

# 检查kubelet配置（在worker节点）
grep "server:" /etc/kubernetes/kubelet.conf
# 输出应该是：server: https://172.16.3.1:6443

# 检查kube-proxy配置
kubectl get cm kube-proxy -n kube-system -o yaml | grep server
# 输出应该是：server: https://172.16.3.1:6443
```

#### **架构总结**

```
┌─────────────────────────────────────────────────────┐
│    所有客户端请求（kubectl/kubelet/应用）             │
└───────────────────────┬─────────────────────────────┘
                        │
                        ▼
            ┌───────────────────────┐
            │       负载均衡器       │  ◄─── 唯一入口
            └───────────┬───────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
   ┌─────────┐    ┌─────────┐    ┌─────────┐
   │ Master1 │    │ Master2 │    │ Master3 │
   │ API-6443│    │ API-6443│    │ API-6443│
   └─────────┘    └─────────┘    └─────────┘
```

> **记住**：
> - 用户/应用 → **负载均衡器** → Master集群 ✅
> - 用户/应用 → 直接访问Master → 失去高可用意义

---

### **5A.2 前提条件**

> 💡 **实际部署请查看**：[4B.2 初始化第一个Master节点](#4b2-第二步初始化第一个master节点)

**理论说明**：

在添加新Master节点之前，需要满足以下条件：

#### 1. 第一个Master必须使用特定参数初始化

如果您已经按照前面步骤初始化了**单Master集群**，要改为高可用集群需要：

**已有单Master集群改造（复杂）**：
- 需要重新初始化整个集群
- 或使用 `kubeadm alpha phase` 相关命令（不推荐）

**全新部署高可用集群（推荐）**：

在初始化第一个Master时，使用以下参数：

```bash
# 高可用集群初始化命令（与单Master不同）
kubeadm init \
  --image-repository registry.aliyuncs.com/google_containers \
  --kubernetes-version v1.28.0 \
  --pod-network-cidr=10.244.0.0/16 \
  --control-plane-endpoint "172.16.3.1:6443" \  # 负载均衡器地址（重要！）
  --upload-certs \  # 自动上传证书到集群（重要！）
  --apiserver-advertise-address=172.16.0.10  # 当前Master的IP
```

**关键参数说明**：
- `--control-plane-endpoint`：**负载均衡器的VIP或域名**（必需）
- `--upload-certs`：自动上传证书，允许其他Master加入（必需）

#### 2. 准备负载均衡器

您需要提前配置负载均衡器（选择以下任一方案）：

**方案A：使用HAProxy（推荐）**
```bash
# 在独立服务器或Master1上安装HAProxy
dnf install -y haproxy

# 配置HAProxy（/etc/haproxy/haproxy.cfg）
cat >> /etc/haproxy/haproxy.cfg << EOF

frontend kubernetes-frontend
    bind *:6443
    mode tcp
    option tcplog
    default_backend kubernetes-backend

backend kubernetes-backend
    mode tcp
    option tcp-check
    balance roundrobin
    server master1 172.16.0.10:6443 check fall 3 rise 2
    server master2 172.16.0.11:6443 check fall 3 rise 2
    server master3 172.16.0.12:6443 check fall 3 rise 2
EOF

# 启动HAProxy
systemctl restart haproxy
systemctl enable haproxy
```

**方案B：使用Nginx（替代方案）**
```bash
# 安装Nginx
dnf install -y nginx nginx-mod-stream

# 配置Nginx（/etc/nginx/nginx.conf）
# 在 http 块之外添加：
stream {
    upstream kubernetes {
        server 172.16.0.10:6443 max_fails=3 fail_timeout=30s;
        server 172.16.0.11:6443 max_fails=3 fail_timeout=30s;
        server 172.16.0.12:6443 max_fails=3 fail_timeout=30s;
    }
    server {
        listen 6443;
        proxy_pass kubernetes;
    }
}

# 启动Nginx
systemctl restart nginx
systemctl enable nginx
```

**方案C：使用Keepalived VIP（生产推荐）**
- 在多个Master节点上配置Keepalived
- 提供浮动VIP，自动故障转移
- 配置较复杂，适合生产环境

#### 3. 新Master节点准备

新的Master节点（如master2）必须完成：
- 第一步：基础环境准备（防火墙、SELinux、Swap等）
- 第二步：安装并配置Containerd
- 第三步：安装kubelet、kubeadm、kubectl
- 确保能访问负载均衡器和第一个Master节点

---

### **5A.3 获取Master加入命令**

> 💡 **实际操作步骤请查看**：[4B.5.1 获取Master加入命令](#4b51-获取master加入命令)

**理论说明**：

在**第一个Master节点**执行以下命令，获取新Master加入的命令：

#### 方法1：从初始化输出获取（推荐）

如果在初始化时使用了 `--upload-certs`，输出中会包含Master加入命令：

```
You can now join any number of control-plane nodes by running the following command on each as root:

  kubeadm join 172.16.3.1:6443 --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:1234...abcd \
        --control-plane --certificate-key abc123...def456
```

> 💡 **重要**：必须保存包含 `--control-plane` 和 `--certificate-key` 的完整命令！

#### 方法2：重新生成证书密钥（如果忘记保存）

```bash
# 1. 重新上传证书到集群（certificate-key有效期2小时）
kubeadm init phase upload-certs --upload-certs

# 输出类似：
# [upload-certs] Storing the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
# [upload-certs] Using certificate key:
# abc123def456abc123def456abc123def456abc123def456abc123def456abcd

# 2. 创建token
  kubeadm token create --print-join-command

# 输出类似：
# kubeadm join 172.16.3.1:6443 --token xyz789.abc123def456 \
#     --discovery-token-ca-cert-hash sha256:1234...abcd

# 3. 手动拼接完整的Master加入命令：
kubeadm join 172.16.3.1:6443 \
  --token xyz789.abc123def456 \
  --discovery-token-ca-cert-hash sha256:1234...abcd \
  --control-plane \
  --certificate-key abc123def456abc123def456abc123def456abc123def456abc123def456abcd
```

#### 方法3：一键生成完整命令（最简单）

```bash
# 创建token并上传证书，输出完整命令
kubeadm token create --print-join-command --certificate-key $(kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1)
```

**关键参数说明**：
- `--control-plane`：表示加入为Master节点（而非Worker）
- `--certificate-key`：用于解密集群证书（2小时有效期）
- 负载均衡器地址：`172.16.3.1:6443`（而非master1的IP）

---

### **5A.4 在新Master节点执行加入**

> 💡 **实际操作步骤请查看**：[4B.5.2 在新Master节点执行加入](#4b52-在新master节点执行加入)

**理论说明**：

在**新的Master节点（如master2、master3）**上执行以下步骤：

#### 步骤1：执行Master加入命令

```bash
# 在新Master节点执行（使用上一步获取的完整命令）
kubeadm join 172.16.3.1:6443 \
  --token abcdef.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef \
  --control-plane \
  --certificate-key abc123def456abc123def456abc123def456abc123def456abc123def456abcd
```

**成功输出示例**：
```
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[preflight] Running pre-flight checks before initializing the new control plane instance
[download-certs] Downloading the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "apiserver" certificate and key
[certs] Generating "apiserver-kubelet-client" certificate and key
...
[mark-control-plane] Marking the node master2 as control-plane by adding the labels: [node-role.kubernetes.io/control-plane node.kubernetes.io/exclude-from-external-load-balancers]
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Starting the kubelet

This node has joined the cluster and a new control plane instance was created:

* Certificate signing request was sent to apiserver and approval was received.
* The Kubelet was informed of the new secure connection details.
* Control plane label and taint were applied to the new node.
* The Kubernetes control plane instances scaled up.

To start administering your cluster from this node, you need to run the following as a regular user:

        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config

Run 'kubectl get nodes' to see this node join the cluster.
```

> **加入成功标志**：看到 "This node has joined the cluster and a new control plane instance was created"

#### 步骤2：配置kubectl（在新Master节点）

```bash
# 配置新Master节点的kubectl权限
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# 验证可以访问集群
kubectl get nodes
```

#### 步骤3：检查etcd集群状态（重要）

```bash
# 在任一Master节点执行，查看etcd成员
kubectl exec -it -n kube-system etcd-master1 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  member list

# 应该看到多个etcd成员
```

---

### **5A.5 验证多Master集群**

> 💡 **实际验证步骤请查看**：[4B.6 验证高可用集群](#4b6-验证高可用集群)

**理论说明**：

#### 5A.5.1 验证节点角色

在**任一Master节点**执行：

```bash
# 查看所有节点（应看到多个control-plane节点）
kubectl get nodes

# 预期输出：
# NAME       STATUS   ROLES           AGE   VERSION
# master1    Ready    control-plane   30m   v1.28.0
# master2    Ready    control-plane   5m    v1.28.0
# master3    Ready    control-plane   3m    v1.28.0
# worker1    Ready    <none>          10m   v1.28.0
# worker2    Ready    <none>          10m   v1.28.0

# 查看control-plane节点详情
kubectl get nodes --selector='node-role.kubernetes.io/control-plane'
```

#### 5A.5.2 验证Master组件分布

```bash
# 查看所有Master节点上的关键组件
kubectl get pods -n kube-system -o wide | grep -E "apiserver|controller|scheduler|etcd"

# 应该看到每个Master节点上都有：
# - kube-apiserver-masterX
# - kube-controller-manager-masterX
# - kube-scheduler-masterX
# - etcd-masterX
```

#### 5A.5.3 测试高可用性

```bash
# 1. 在Master2上查看集群状态
kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes

# 2. 测试API Server负载均衡（可选）
# 临时停止Master1的API Server
ssh root@172.16.0.10 "systemctl stop kubelet"

# 从其他节点访问集群（应仍然可用）
kubectl get nodes

# 恢复Master1
ssh root@172.16.0.10 "systemctl start kubelet"
```

#### 5A.5.4 验证etcd集群健康

```bash
# 查看etcd集群健康状态
kubectl exec -it -n kube-system etcd-master1 -- etcdctl \
  --endpoints=https://172.16.0.10:2379,https://172.16.0.11:2379,https://172.16.0.12:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health

# 预期输出：
# https://172.16.0.10:2379 is healthy: successfully committed proposal: took = 2.345ms
# https://172.16.0.11:2379 is healthy: successfully committed proposal: took = 2.567ms
# https://172.16.0.12:2379 is healthy: successfully committed proposal: took = 2.123ms
```

---

### **5A.6 常见问题**

> 💡 **最新的问题排查请查看**：[第七步：常见问题排查与解决](#第七步常见问题排查与解决)

**常见问题参考**：

#### 问题1：certificate-key过期

**症状**：加入时报错 "error execution phase control-plane-prepare/download-certs"

**解决**：
```bash
# 在Master1重新上传证书
kubeadm init phase upload-certs --upload-certs

# 使用新的certificate-key重新加入
```

#### 问题2：无法访问负载均衡器

**症状**：加入时报错 "connection refused" 或 "i/o timeout"

**排查**：
```bash
# 在新Master节点测试负载均衡器连通性
telnet 172.16.3.1 6443
curl -k https://172.16.3.1:6443/healthz
```

#### 问题3：etcd集群不健康

**症状**：Master节点NotReady，etcd pod启动失败

**排查**：
```bash
# 查看etcd日志
kubectl logs -n kube-system etcd-master2 --tail=50

# 检查etcd数据目录权限
ls -la /var/lib/etcd
```

---

### **5A.7 高可用集群最佳实践**

> 💡 **完整的高可用部署建议请查看**：[4B：高可用集群部署](#4b高可用集群部署生产模式)

**最佳实践参考**：

1. **Master节点数量**：推荐3个或5个（奇数），避免脑裂
2. **负载均衡器**：建议使用独立的LB或Keepalived VIP
3. **节点分布**：Master节点应分布在不同机架/可用区
4. **定期备份**：定期备份etcd数据
5. **监控告警**：监控Master节点和etcd集群健康状态

---

### 📌 **本节总结（第五步补充）**

> **重要提醒**：
> 
> 1. 🔴 **部署高可用集群请直接使用** → [4B：高可用集群部署](#4b高可用集群部署生产模式)
> 2. 📖 **本节（5A）仅作为理论参考**，实际操作请以4B部分为准
> 3. ✅ **4B部分包含**：
>    - 最新的部署流程
>    - 详细的验证步骤
>    - 完整的故障排查
>    - 部署完成确认清单
> 
> **如果您正在部署高可用集群，现在应该返回4B部分继续操作！**

**理论知识总结**：
- 高可用集群需要负载均衡器 + 多个Master节点
- 使用 `--control-plane` 参数将节点加入为Master
- 必须在初始化时使用 `--upload-certs` 和 `--control-plane-endpoint`
- 单Master集群改造为高可用需要重新部署

---

### **第六步：全面验证集群状态（master节点执行）**

> 🎯 **这是部署的最后一步！** 完成本步骤的所有验证后，您的Kubernetes集群就完全部署成功了！

**本步骤目的**：
- 全面检查集群各项功能是否正常
- 验证网络、DNS、存储等核心功能
- 确保集群可以正常部署应用

**适用场景**：
- 单Master集群部署完成后
- 高可用集群部署完成后
- Worker节点加入完成后

---

完成所有节点部署后，在**Master节点**执行以下全面的集群健康检查：

#### 6.1 节点状态验证
```bash
# 查看所有节点（状态均为Ready即为成功）
kubectl get nodes

# 查看节点详细信息（包括IP、容器运行时、内核版本等）
kubectl get nodes -o wide

# 检查节点资源使用情况
kubectl top nodes  # 需要先安装metrics-server，若报错可跳过
```


#### 6.2 系统组件验证
```bash
# 查看所有命名空间的pod（所有pod均为Running）
kubectl get pods -A

# 查看kube-system命名空间组件状态
kubectl get pods -n kube-system

# 检查关键组件状态
kubectl get componentstatuses  # 若显示Deprecated，可忽略

# 查看集群信息
kubectl cluster-info
```


#### 6.3 网络功能验证
```bash
# 查看flannel网络插件状态（应在所有节点运行）
kubectl get pods -n kube-flannel -o wide

# 创建测试pod验证网络连通性
kubectl run test-nginx --image=nginx:alpine --port=80
kubectl expose pod test-nginx --port=80 --target-port=80

# 等待pod运行
kubectl get pods -w  # 按Ctrl+C退出监控

# 查看pod IP
kubectl get pods -o wide

# 测试pod网络（用另一个pod测试连通性）
kubectl run test-curl --image=curlimages/curl --rm -it --restart=Never -- curl http://test-nginx

# 清理测试资源
kubectl delete pod test-nginx
kubectl delete svc test-nginx
```


#### 6.4 DNS功能验证
```bash
# 检查coredns状态
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 测试DNS解析
kubectl run test-dns --image=busybox:1.28 --rm -it --restart=Never -- nslookup kubernetes.default

# 若上一步成功，说明DNS正常工作
```


#### 6.5 查看集群整体信息
```bash
# 查看集群版本信息
kubectl version

# 查看API资源列表
kubectl api-resources

# 查看命名空间列表
kubectl get namespaces

# 查看所有节点详细信息
kubectl describe nodes

# 查看集群事件（排查问题时有用）
kubectl get events -A --sort-by='.lastTimestamp'
```


#### 6.6 验证成功输出示例
正常情况下，`kubectl get nodes` 和 `kubectl get pods -A` 应有以下类似输出：

```
# kubectl get nodes
NAME               STATUS   ROLES           AGE   VERSION
k8s-master-gz      Ready    control-plane   10m   v1.28.0
k8s-woker01-gz     Ready    <none>          5m    v1.28.0
k8s-woker02-gz     Ready    <none>          5m    v1.28.0

# kubectl get pods -A
NAMESPACE      NAME                                    READY   STATUS    RESTARTS   AGE
kube-flannel   kube-flannel-ds-xxxxx                   1/1     Running   0          8m
kube-flannel   kube-flannel-ds-yyyyy                   1/1     Running   0          5m
kube-flannel   kube-flannel-ds-zzzzz                   1/1     Running   0          5m
kube-system    coredns-xxxxxxxxxx-xxxxx                1/1     Running   0          10m
kube-system    coredns-xxxxxxxxxx-yyyyy                1/1     Running   0          10m
kube-system    etcd-k8s-master-gz                      1/1     Running   0          10m
kube-system    kube-apiserver-k8s-master-gz            1/1     Running   0          10m
kube-system    kube-controller-manager-k8s-master-gz   1/1     Running   0          10m
kube-system    kube-proxy-xxxxx                        1/1     Running   0          10m
kube-system    kube-proxy-yyyyy                        1/1     Running   0          5m
kube-system    kube-proxy-zzzzz                        1/1     Running   0          5m
kube-system    kube-scheduler-k8s-master-gz            1/1     Running   0          10m
```

---

### **6.7 集群部署完成确认**

**恭喜！如果上述所有验证都通过，说明您的Kubernetes集群已经完全部署成功！**

#### **部署成功的标志**：
- 所有节点状态为 `Ready`
- 所有系统pod状态为 `Running`
- DNS解析正常工作
- 跨节点pod网络互通
- 能够创建和访问测试Pod

#### **您现在拥有的集群配置**：
```bash
# 查看集群概览
kubectl get nodes
kubectl cluster-info
kubectl version

# 集群规模：
# - Master节点：1个（单Master）或 3+个（高可用）
# - Worker节点：根据您的部署
# - 网络插件：Flannel
# - 容器运行时：Containerd
# - Kubernetes版本：v1.28.0
```

#### **集群已具备的能力**：
- 部署容器化应用
- 服务发现和负载均衡
- 自动扩缩容
- 自动故障恢复
- 滚动更新和回滚
- 配置和密钥管理

#### **快速验证脚本**（保存为集群监控）：
```bash
# 创建快速健康检查脚本
cat > ~/cluster-health.sh << 'EOF'
#!/bin/bash
echo "=== Kubernetes集群健康检查 ==="
echo "时间: $(date)"
echo ""
echo "节点状态:"
kubectl get nodes
echo ""
echo "系统Pod状态:"
kubectl get pods -A | grep -v Running | grep -v Completed || echo "所有Pod都在运行"
echo ""
echo "集群信息:"
kubectl cluster-info | grep "Kubernetes"
EOF

chmod +x ~/cluster-health.sh

# 随时运行检查
~/cluster-health.sh
```

---

### **部署完成后的清单**

请确认以下所有项都已完成：

**基础环境**（所有节点）：
- [ ] 防火墙已关闭
- [ ] SELinux已关闭
- [ ] Swap已禁用
- [ ] 主机名和hosts已配置
- [ ] 内核模块和参数已设置

**容器运行时**（所有节点）：
- [ ] Containerd已安装并运行
- [ ] Containerd配置正确（阿里云pause镜像）
- [ ] SystemdCgroup已启用

**Kubernetes组件**（所有节点）：
- [ ] kubelet、kubeadm、kubectl已安装（v1.28.0）
- [ ] kubelet服务运行正常

**Master节点**：
- [ ] 集群已初始化成功
- [ ] kubectl已配置
- [ ] Flannel网络插件已部署
- [ ] 所有Master节点Ready（高可用集群）

**负载均衡器**（仅高可用集群）：
- [ ] HAProxy/Nginx已配置
- [ ] 负载均衡器6443端口可访问
- [ ] 所有节点通过LB访问API Server

**Worker节点**：
- [ ] 所有Worker节点已加入集群
- [ ] 所有Worker节点状态Ready
- [ ] Flannel在所有Worker上运行

**集群功能**：
- [ ] DNS解析正常
- [ ] Pod网络互通
- [ ] 能够创建和访问Pod
- [ ] Service功能正常

---

### **确认集群完全就绪**

运行以下最终确认命令：

```bash
# 一键确认脚本
cat << 'EOF'
======================================
    Kubernetes集群部署完成确认
======================================
EOF

echo ""
echo "1. 节点检查:"
NODES=$(kubectl get nodes --no-headers | wc -l)
READY=$(kubectl get nodes --no-headers | grep -w Ready | wc -l)
echo "   总节点数: $NODES | Ready节点: $READY"
if [ "$NODES" -eq "$READY" ]; then
    echo "   所有节点就绪"
else
    echo "   ❌ 存在异常节点"
fi

echo ""
echo "2. 系统组件检查:"
PODS=$(kubectl get pods -n kube-system --no-headers | wc -l)
RUNNING=$(kubectl get pods -n kube-system --no-headers | grep -w Running | wc -l)
echo "   系统Pod总数: $PODS | Running: $RUNNING"
if [ "$PODS" -eq "$RUNNING" ]; then
    echo "   所有系统组件正常"
else
    echo "   ❌ 存在异常组件"
fi

echo ""
echo "3. 网络插件检查:"
FLANNEL=$(kubectl get pods -n kube-flannel --no-headers | grep -w Running | wc -l)
if [ "$FLANNEL" -eq "$NODES" ]; then
    echo "   Flannel在所有节点运行"
else
    echo "   ❌ Flannel存在问题"
fi

echo ""
echo "======================================"
if [ "$NODES" -eq "$READY" ] && [ "$PODS" -eq "$RUNNING" ] && [ "$FLANNEL" -eq "$NODES" ]; then
    echo "🎉 集群部署成功！所有组件正常运行！"
else
    echo "⚠️  部分组件存在问题，请检查"
fi
echo "======================================"
```

**预期输出**：
```
======================================
    Kubernetes集群部署完成确认
======================================

1. 节点检查:
   总节点数: 3 | Ready节点: 3
   所有节点就绪

2. 系统组件检查:
   系统Pod总数: 10 | Running: 10
   所有系统组件正常

3. 网络插件检查:
   Flannel在所有节点运行

======================================
🎉 集群部署成功！所有组件正常运行！
======================================
```

---

> **Kubernetes集群部署完成！** 
> 
> 您现在可以开始部署应用了！建议继续查看 [下一步操作建议](#下一步操作建议) 来扩展集群功能。


### **第七步：常见问题排查与解决**

#### 7.1 kubelet启动失败
**症状**：`systemctl status kubelet` 显示failed状态（在kubeadm init之后依然失败）

**排查步骤**：
```bash
# 1. 检查swap是否关闭（应为0）
free -m

# 2. 检查containerd配置
grep "SystemdCgroup" /etc/containerd/config.toml  # 应为true

# 3. 查看kubelet详细日志
journalctl -xeu kubelet -n 50

# 4. 检查kubelet配置文件
ls -la /etc/kubernetes/kubelet.conf
cat /var/lib/kubelet/config.yaml
```

**解决方法**：
```bash
# 重新关闭swap
swapoff -a
sed -i '/swap/s/^/#/' /etc/fstab

# 修正containerd配置
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
systemctl restart containerd

# 重启kubelet
systemctl restart kubelet
```


#### 7.2 镜像拉取失败
**症状**：pod状态显示ImagePullBackOff或ErrImagePull

**排查步骤**：
```bash
# 查看pod详细信息
kubectl describe pod <pod-name> -n <namespace>

# 查看containerd镜像列表
crictl images

# 手动拉取镜像测试
crictl pull registry.aliyuncs.com/google_containers/pause:3.9
```

**解决方法**：
```bash
# 确认containerd配置使用了阿里镜像
grep "sandbox_image" /etc/containerd/config.toml

# 若未配置，手动修改
sed -i "s#sandbox_image = \"k8s.gcr.io/pause.*\"#sandbox_image = \"registry.aliyuncs.com/google_containers/pause:3.9\"#g" /etc/containerd/config.toml
systemctl restart containerd

# 重新部署失败的pod
kubectl delete pod <pod-name> -n <namespace>
```


#### 7.3 节点状态NotReady

**症状**：`kubectl get nodes` 显示节点状态为NotReady

---

**场景1：Worker节点pause镜像拉取失败（最常见）** ⚠️

**症状识别**：
```bash
# 在Master节点上检查flannel pod状态
kubectl get pods -n kube-flannel -o wide
# Worker节点的flannel pod显示：Init:0/2 或 PodInitializing

# 查看详细信息
kubectl describe pod <flannel-pod-name> -n kube-flannel
# Events中显示：Failed to create pod sandbox
# 错误信息：failed to pull image "registry.k8s.io/pause:3.8": i/o timeout
```

**根本原因**：Worker节点的containerd配置使用了无法访问的镜像源（registry.k8s.io）

**解决方法**：
```bash
# 在问题Worker节点上执行

# 1. 检查当前配置
grep "sandbox_image" /etc/containerd/config.toml
# 如果显示 registry.k8s.io 或 k8s.gcr.io，说明配置错误

# 2. 修复配置
sed -i "s#sandbox_image = \".*\"#sandbox_image = \"registry.aliyuncs.com/google_containers/pause:3.9\"#g" /etc/containerd/config.toml

# 3. 验证修改成功
grep "sandbox_image" /etc/containerd/config.toml
# 应显示：sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9"

# 4. 重启服务
systemctl restart containerd
systemctl restart kubelet

# 5. 手动拉取pause镜像（加速恢复）
crictl pull registry.aliyuncs.com/google_containers/pause:3.9

# 6. 等待1-2分钟，返回Master检查
# kubectl get nodes
# kubectl get pods -n kube-flannel -o wide
```

**预期结果**：
- 1-2分钟后，Worker节点变为Ready
- Flannel pod变为Running 1/1

---

**场景2：网络插件问题**

**排查步骤**：
```bash
# 查看节点详细信息
kubectl describe node <node-name>

# 检查网络插件状态
kubectl get pods -n kube-flannel

# 查看kubelet日志
journalctl -xeu kubelet -n 100

# 检查防火墙状态
systemctl status firewalld

# 检查内核模块
lsmod | grep br_netfilter
```

**解决方法**：
```bash
# 重新部署flannel网络插件
kubectl delete -f kube-flannel.yml
kubectl apply -f kube-flannel.yml

# 确保防火墙关闭
systemctl stop firewalld
systemctl disable firewalld

# 重启kubelet
systemctl restart kubelet
```


#### 7.4 worker节点无法加入集群
**症状**：执行kubeadm join时报错

**常见错误原因**：
1. **token过期**：token默认24小时有效期
2. **网络不通**：worker无法访问master的6443端口
3. **containerd配置问题**：pause镜像无法拉取
4. **防火墙未关闭**：阻止了节点间通信

**排查步骤**：
```bash
# 在worker节点检查与master的连通性
ping 172.16.0.10
telnet 172.16.0.10 6443

# 在master节点检查token是否过期
kubeadm token list
# 如果TTL显示<invalid>或列表为空，说明token已过期

# 在worker节点查看加入失败的详细日志
journalctl -xeu kubelet -n 100

# 在worker节点检查containerd的pause镜像配置
grep "sandbox_image" /etc/containerd/config.toml
```

**解决方法**：

**1. 在Master节点重新生成join命令**
```bash
# 生成新的join命令（推荐）
kubeadm token create --print-join-command

# 或者创建永不过期的token
kubeadm token create --print-join-command --ttl=0
```

**2. 在Worker节点重置并重新加入**
```bash
# 先重置worker节点（清理之前失败的状态）
kubeadm reset -f

# 确保containerd配置正确（修改pause镜像为阿里源）
sed -i 's#sandbox_image = "registry.k8s.io/pause.*"#sandbox_image = "registry.aliyuncs.com/google_containers/pause:3.9"#g' /etc/containerd/config.toml

# 重启containerd和kubelet
systemctl restart containerd
systemctl restart kubelet

# 使用新生成的join命令重新加入
kubeadm join 172.16.0.10:6443 --token <new-token> --discovery-token-ca-cert-hash sha256:<hash>
```

> 💡 **提示**：关于获取join命令的详细方法，请参考 [4.2.1 获取Worker节点加入命令](#421-获取worker节点加入命令重要)


#### 7.5 Token过期无法加入worker节点
**症状**：Worker节点执行join命令时报错 "token id xxx is expired" 或 "token not found"

**原因**：kubeadm生成的token默认有效期为24小时，超过时间后无法使用

**解决方法**：

在 **Master节点** 执行：
```bash
# 查看当前token状态
kubeadm token list

# 方法1：生成新的join命令（最简单）
kubeadm token create --print-join-command

# 方法2：生成永不过期的token
kubeadm token create --print-join-command --ttl=0

# 方法3：删除旧token并创建新token
kubeadm token delete <old-token-id>
kubeadm token create --print-join-command
```

然后在 **Worker节点** 使用新生成的join命令：
```bash
# 如果之前join失败，先重置
kubeadm reset -f

# 使用新的join命令
kubeadm join 172.16.0.10:6443 --token <new-token> --discovery-token-ca-cert-hash sha256:<hash>
```

> 💡 **最佳实践**：
> - 生产环境建议使用默认24小时有效期，定期更新token
> - 测试环境可以使用 `--ttl=0` 创建永不过期的token
> - 更多获取join命令的方法，请参考 [4.2.1 获取Worker节点加入命令](#421-获取worker节点加入命令重要)


#### 7.6 coredns一直处于Pending状态
**症状**：`kubectl get pods -n kube-system` 显示coredns为Pending

**排查步骤**：
```bash
# 查看coredns pod详情
kubectl describe pod -n kube-system -l k8s-app=kube-dns

# 检查网络插件是否安装
kubectl get pods -n kube-flannel

# 查看节点是否Ready
kubectl get nodes
```

**解决方法**：
```bash
# 确保先安装网络插件
kubectl apply -f kube-flannel.yml

# 等待flannel启动后，coredns会自动调度
kubectl get pods -n kube-system -w
```


#### 7.7 通用问题排查命令
```bash
# 查看所有pod状态和重启次数
kubectl get pods -A -o wide

# 查看最近的集群事件
kubectl get events -A --sort-by='.lastTimestamp' | tail -30

# 查看特定pod的日志
kubectl logs <pod-name> -n <namespace>

# 进入pod内部排查
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# 完全重置集群（慎用，会删除所有配置）
kubeadm reset -f
rm -rf /etc/kubernetes/
rm -rf /var/lib/kubelet/
rm -rf /var/lib/etcd/
rm -rf $HOME/.kube/
```


#### 7.8 高可用集群负载均衡器问题

> 此部分仅适用于部署了高可用集群（多Master）的用户

**症状**：kubectl命令超时、Worker节点无法加入、集群管理功能不可用

**常见错误**：
```
error execution phase preflight: couldn't validate the identity of the API Server: 
Get "https://172.16.3.1:6443/api/v1/namespaces/kube-public/configmaps/cluster-info?timeout=10s": 
dial tcp 172.16.3.1:6443: connect: connection refused
```

**常见原因（按发生频率排序）**：

1. 🔴 **跨网段环境错误使用了Keepalived + VIP方案（最致命错误）**
   - 现象：VIP可以ping通，但从不同网段的Worker无法访问6443端口
   - 原因：VIP基于ARP协议，只能在同一二层网络（同一交换机/VLAN）生效
   - 解决：**必须改用独立负载均衡器服务器（方案A）**

2. **只配置了Keepalived，没有HAProxy（常见错误）**
   - 现象：VIP可以ping通，但6443端口拒绝连接
   - 原因：Keepalived只提供VIP漂移，不提供负载均衡
   - 解决：必须配置HAProxy或Nginx来提供负载均衡

3. 负载均衡器服务未启动
4. 负载均衡器配置错误
5. 防火墙阻止6443端口
6. 后端Master节点全部不可用

**排查步骤**：

**步骤0：确认网络拓扑（最优先检查）**
```bash
# 在Master节点查看网段
ip addr show | grep "inet "
# 例如：172.16.0.10/24

# 在Worker节点查看网段
ip addr show | grep "inet "
# 例如：10.0.0.20/24

# 如果Master和Worker不在同一网段（例如一个172.16.x.x，一个10.0.x.x）
# 🔴 检查您是否使用了Keepalived + VIP方案
# 如果是，这就是问题根源！

# 查看负载均衡器类型
systemctl status keepalived 2>/dev/null && echo "使用了Keepalived（VIP方案）" || echo "未使用Keepalived"
systemctl status haproxy 2>/dev/null && echo "使用了HAProxy" || echo "未使用HAProxy"

# 如果Master和Worker在不同网段，且使用了Keepalived：
# 解决方案：必须改用独立负载均衡器服务器
# 参考文档中的"方案A：独立负载均衡器服务器"
```

**步骤1：诊断网络层面**
```bash
# 在Worker节点执行
echo "=== 网络层诊断 ==="
LB_ADDRESS="172.16.3.1"  # 改为您的负载均衡器地址

# 1. 测试负载均衡器 ICMP连通性
ping -c 3 $LB_ADDRESS
# 应该能ping通

# 2. 测试负载均衡器端口连通性（关键！）
telnet $LB_ADDRESS 6443
# 如果显示 "Connection refused"，说明端口没有服务监听

nc -zv $LB_ADDRESS 6443
# 如果显示 "Connection refused"，问题在于负载均衡器的6443端口

# 3. 对比测试Master实际IP
telnet 172.16.0.10 6443
# 如果能连接，说明Master API Server正常，问题在负载均衡器
# 如果不能连接，说明Master本身有问题
```

**步骤2：检查负载均衡器配置**
```bash
# 在Master节点执行
echo "=== 负载均衡器检查 ==="

# 1. 检查HAProxy服务状态
systemctl status haproxy
# 如果未运行或未安装，这就是问题所在

# 2. 检查Keepalived服务状态
systemctl status keepalived

# 3. 检查VIP绑定
ip addr show | grep 172.16.3.1
# 应该在某个网卡上看到VIP

# 4. 检查端口监听（最关键！）
ss -tuln | grep 6443
# 应该看到 *:6443 或 0.0.0.0:6443（HAProxy监听）
# 如果只看到 172.16.0.10:6443（API Server），说明缺少HAProxy

netstat -tuln | grep 6443
# 同上

lsof -i:6443
# 应该看到 haproxy 进程
```

**步骤3：查看配置文件**
```bash
# 检查HAProxy配置
cat /etc/haproxy/haproxy.cfg | grep -A 15 "frontend\|backend"

# 应该看到类似：
# frontend kubernetes-frontend
#     bind *:6443    # 监听所有接口的6443
# backend kubernetes-backend
#     server master1 172.16.0.10:6443 check

# 检查HAProxy是否在VIP上监听
haproxy -c -f /etc/haproxy/haproxy.cfg
```

---

**解决方法**：

**场景1：跨网段环境使用了Keepalived + VIP方案（最致命）** 🔴

**诊断确认**：
```bash
# 检查Master和Worker是否在不同网段
# Master: 172.16.0.10/24
# Worker: 10.0.0.20/24  （不同网段！）

# VIP可以ping通（从Master节点）
ping 172.16.3.1  # 成功

# 从Worker节点ping VIP也成功
ping 172.16.3.1  # 成功（但这是假象！）

# 但从Worker访问6443端口失败
nc -zv 172.16.3.1 6443  # Connection refused 或 No route to host

# 检查是否使用了Keepalived
systemctl status keepalived  # active (running)
```

**解决方案：必须改用独立负载均衡器服务器**
```bash
# 1. 停止并禁用Master节点上的Keepalived（因为跨网段不可用）
systemctl stop keepalived
systemctl disable keepalived

# 2. 部署独立的LB服务器（或使用云LB）
# 在独立的LB服务器（例如172.16.3.1）上安装HAProxy
# 参考文档"方案A：独立负载均衡器服务器"

# 3. 修改集群配置（已有集群需要修改）
# 编辑 /etc/kubernetes/manifests/kube-apiserver.yaml
# 或重新初始化集群使用新的endpoint

# 4. 建议：重新初始化集群
kubeadm reset -f
# 然后使用正确的--control-plane-endpoint初始化
kubeadm init --control-plane-endpoint "172.16.3.1:6443" ...
```

---

**场景2：只配置了Keepalived，缺少HAProxy（常见）**

**诊断确认**：
```bash
# VIP可以ping通
ping 172.16.3.1  # 成功

# 但6443端口拒绝连接
telnet 172.16.3.1 6443  # Connection refused

# HAProxy未安装或未运行
systemctl status haproxy  # Unit haproxy.service could not be found

# Keepalived在运行
systemctl status keepalived  # active (running)
```

**解决方案：安装并配置HAProxy**
```bash
# 1. 在Master节点安装HAProxy
dnf install -y haproxy

# 2. 配置HAProxy（注意bind地址）
cat > /etc/haproxy/haproxy.cfg << 'EOF'
global
    log /dev/log local0
    chroot /var/lib/haproxy
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend kubernetes-frontend
    bind *:6443           # 监听所有接口的6443端口
    mode tcp
    option tcplog
    default_backend kubernetes-backend

backend kubernetes-backend
    mode tcp
    option tcp-check
    balance roundrobin
    server master1 172.16.0.10:6443 check fall 3 rise 2
    # 如果有多个Master，添加其他节点
    # server master2 172.16.0.11:6443 check fall 3 rise 2
    # server master3 172.16.0.12:6443 check fall 3 rise 2
EOF

# 3. 检查配置语法
haproxy -c -f /etc/haproxy/haproxy.cfg

# 4. 启动HAProxy
systemctl enable haproxy
systemctl restart haproxy

# 5. 验证
systemctl status haproxy
ss -tuln | grep 6443
telnet 172.16.3.1 6443  # 应该能连接了

# 6. 在Worker节点重新测试
telnet 172.16.3.1 6443  # 应该成功
```

---

**场景2：HAProxy配置错误**

**常见错误：bind地址不正确**
```bash
# 错误配置示例（只监听Master IP）
bind 172.16.0.10:6443    # 只监听Master IP，VIP无法访问

# 正确配置（监听所有接口）
bind *:6443              # 监听所有接口，包括VIP
bind 0.0.0.0:6443        # 同上
```

**修复方法**：
```bash
# 编辑配置文件
vim /etc/haproxy/haproxy.cfg

# 确保frontend配置为：
frontend kubernetes-frontend
    bind *:6443    # 关键：使用 * 或 0.0.0.0

# 重启HAProxy
systemctl restart haproxy

# 验证
ss -tuln | grep 6443
# 应该看到：0.0.0.0:6443 或 *:6443
```

---

**场景3：HAProxy端口被占用**
```bash
# 检查6443端口占用情况
ss -tuln | grep 6443
lsof -i:6443

# 如果API Server已经占用6443，需要调整端口
# 方法1：让API Server监听其他端口（如6444）
# 在kubeadm init时使用：--apiserver-bind-port=6444

# 方法2：HAProxy使用其他VIP
# 修改VIP为其他可用IP
```

---

**场景4：临时绕过负载均衡器（紧急情况）**

如果负载均衡器问题复杂，需要紧急使集群可用：

```bash
# 方案1：改用单Master模式（推荐）
# 在Master节点执行：
sed -i 's#https://172.16.3.1:6443#https://172.16.0.10:6443#g' /etc/kubernetes/admin.conf
sed -i 's#https://172.16.3.1:6443#https://172.16.0.10:6443#g' /etc/kubernetes/kubelet.conf
sed -i 's#https://172.16.3.1:6443#https://172.16.0.10:6443#g' /etc/kubernetes/controller-manager.conf
sed -i 's#https://172.16.3.1:6443#https://172.16.0.10:6443#g' /etc/kubernetes/scheduler.conf
cp /etc/kubernetes/admin.conf $HOME/.kube/config
systemctl restart kubelet

# 生成新的Worker join命令
kubeadm token create --print-join-command

# 方案2：临时修改kubectl配置
kubectl config set-cluster kubernetes --server=https://172.16.0.10:6443

# 完成紧急操作后，恢复LB配置并修复问题
```

---

**场景5：Keepalived VIP漂移问题**
```bash
# 检查VIP在哪个节点
ip addr show | grep 172.16.3.1

# 查看Keepalived状态
systemctl status keepalived

# 查看Keepalived日志
journalctl -xeu keepalived -n 50

# 重启Keepalived
systemctl restart keepalived

# 检查健康检查脚本
/etc/keepalived/check_haproxy.sh
echo $?  # 应该返回0
```

**最佳实践**：
- 监控负载均衡器健康状态
- 配置负载均衡器自身的高可用（Keepalived）
- 定期测试故障切换
- 保留单Master节点直连方式作为应急备用


#### 7.9 验证环境一致性检查清单
在所有节点执行以下检查，确保环境一致：
```bash
# 检查各项配置
echo "=== 防火墙状态 ==="
systemctl status firewalld | grep Active

echo "=== SELinux状态 ==="
getenforce

echo "=== Swap状态 ==="
free -m | grep Swap

echo "=== Containerd状态 ==="
systemctl status containerd | grep Active

echo "=== Kubelet状态 ==="
systemctl status kubelet | grep Active

echo "=== 组件版本 ==="
kubelet --version
kubeadm version --short
kubectl version --client --short

echo "=== 内核参数 ==="
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
```

---

## **附录：一键验证脚本**

### A.1 集群健康检查脚本（在master节点执行）
将以下脚本保存为 `k8s-health-check.sh`，用于快速检查集群整体状态：

```bash
#!/bin/bash
# Kubernetes集群健康检查脚本
# 在master节点执行

echo "========================================"
echo "   Kubernetes 集群健康检查报告"
echo "========================================"
echo ""

# 1. 节点状态检查
echo "【1】节点状态检查"
echo "----------------------------------------"
kubectl get nodes -o wide
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
READY_COUNT=$(kubectl get nodes --no-headers | grep -w "Ready" | wc -l)
echo ""
echo "节点总数: $NODE_COUNT | Ready节点数: $READY_COUNT"
if [ "$NODE_COUNT" -eq "$READY_COUNT" ]; then
    echo "所有节点状态正常"
else
    echo "存在异常节点，请检查"
fi
echo ""

# 2. 系统组件检查
echo "【2】系统组件状态检查"
echo "----------------------------------------"
kubectl get pods -n kube-system
SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers | wc -l)
RUNNING_PODS=$(kubectl get pods -n kube-system --no-headers | grep -w "Running" | wc -l)
echo ""
echo "系统Pod总数: $SYSTEM_PODS | Running状态: $RUNNING_PODS"
if [ "$SYSTEM_PODS" -eq "$RUNNING_PODS" ]; then
    echo "所有系统组件运行正常"
else
    echo "存在异常系统组件，请检查"
fi
echo ""

# 3. 网络插件检查
echo "【3】网络插件状态检查"
echo "----------------------------------------"
kubectl get pods -n kube-flannel
FLANNEL_PODS=$(kubectl get pods -n kube-flannel --no-headers | wc -l)
FLANNEL_RUNNING=$(kubectl get pods -n kube-flannel --no-headers | grep -w "Running" | wc -l)
echo ""
echo "Flannel Pod总数: $FLANNEL_PODS | Running状态: $FLANNEL_RUNNING"
if [ "$FLANNEL_PODS" -eq "$FLANNEL_RUNNING" ] && [ "$FLANNEL_PODS" -eq "$NODE_COUNT" ]; then
    echo "网络插件在所有节点运行正常"
else
    echo "网络插件存在问题，请检查"
fi
echo ""

# 4. CoreDNS检查
echo "【4】CoreDNS状态检查"
echo "----------------------------------------"
kubectl get pods -n kube-system -l k8s-app=kube-dns
COREDNS_COUNT=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | grep -w "Running" | wc -l)
echo ""
if [ "$COREDNS_COUNT" -ge 2 ]; then
    echo "CoreDNS运行正常"
else
    echo "CoreDNS存在问题"
fi
echo ""

# 5. 集群信息
echo "【5】集群基本信息"
echo "----------------------------------------"
kubectl cluster-info
echo ""
kubectl version --short 2>/dev/null || kubectl version
echo ""

# 6. 资源使用情况（可选）
echo "【6】节点资源使用情况"
echo "----------------------------------------"
kubectl top nodes 2>/dev/null || echo "⚠️  未安装metrics-server，跳过资源检查"
echo ""

# 7. 最近事件
echo "【7】最近集群事件（最后10条）"
echo "----------------------------------------"
kubectl get events -A --sort-by='.lastTimestamp' | tail -10
echo ""

# 总结
echo "========================================"
echo "              检查完成"
echo "========================================"
echo ""
echo "快速验证命令："
echo "  kubectl get nodes              # 查看节点"
echo "  kubectl get pods -A            # 查看所有Pod"
echo "  kubectl get events -A          # 查看事件"
echo ""
```

**使用方法**：
```bash
# 赋予执行权限
chmod +x k8s-health-check.sh

# 执行检查
./k8s-health-check.sh
```


### A.2 节点环境检查脚本（所有节点执行）
将以下脚本保存为 `node-env-check.sh`，用于检查单个节点的基础环境：

```bash
#!/bin/bash
# Kubernetes节点环境检查脚本
# 在所有节点执行

echo "========================================"
echo "   K8s节点环境检查报告"
echo "========================================"
echo "主机名: $(hostname)"
echo "执行时间: $(date)"
echo ""

# 1. 防火墙检查
echo "【1】防火墙状态"
echo "----------------------------------------"
FIREWALL_STATUS=$(systemctl is-active firewalld)
if [ "$FIREWALL_STATUS" == "inactive" ]; then
    echo "防火墙已关闭"
else
    echo "防火墙仍在运行: $FIREWALL_STATUS"
fi
echo ""

# 2. SELinux检查
echo "【2】SELinux状态"
echo "----------------------------------------"
SELINUX_STATUS=$(getenforce)
if [ "$SELINUX_STATUS" == "Disabled" ] || [ "$SELINUX_STATUS" == "Permissive" ]; then
    echo "SELinux已关闭: $SELINUX_STATUS"
else
    echo "SELinux仍在运行: $SELINUX_STATUS"
fi
echo ""

# 3. Swap检查
echo "【3】Swap状态"
echo "----------------------------------------"
SWAP_SIZE=$(free -m | grep Swap | awk '{print $2}')
if [ "$SWAP_SIZE" -eq 0 ]; then
    echo "Swap已关闭"
else
    echo "Swap仍启用: ${SWAP_SIZE}MB"
fi
free -m | grep Swap
echo ""

# 4. 内核模块检查
echo "【4】内核模块检查"
echo "----------------------------------------"
OVERLAY=$(lsmod | grep overlay | wc -l)
NETFILTER=$(lsmod | grep br_netfilter | wc -l)
if [ "$OVERLAY" -gt 0 ] && [ "$NETFILTER" -gt 0 ]; then
    echo "必需内核模块已加载"
else
    echo "内核模块缺失"
fi
echo "overlay: $OVERLAY"
echo "br_netfilter: $NETFILTER"
echo ""

# 5. 内核参数检查
echo "【5】内核参数检查"
echo "----------------------------------------"
IP_FORWARD=$(sysctl -n net.ipv4.ip_forward)
IPTABLES=$(sysctl -n net.bridge.bridge-nf-call-iptables)
IP6TABLES=$(sysctl -n net.bridge.bridge-nf-call-ip6tables)
if [ "$IP_FORWARD" -eq 1 ] && [ "$IPTABLES" -eq 1 ] && [ "$IP6TABLES" -eq 1 ]; then
    echo "内核参数配置正确"
else
    echo "内核参数配置错误"
fi
echo "net.ipv4.ip_forward: $IP_FORWARD"
echo "net.bridge.bridge-nf-call-iptables: $IPTABLES"
echo "net.bridge.bridge-nf-call-ip6tables: $IP6TABLES"
echo ""

# 6. Containerd服务检查
echo "【6】Containerd服务状态"
echo "----------------------------------------"
CONTAINERD_STATUS=$(systemctl is-active containerd)
if [ "$CONTAINERD_STATUS" == "active" ]; then
    echo "Containerd运行正常"
    containerd --version
else
    echo "Containerd未运行: $CONTAINERD_STATUS"
fi
echo ""

# 7. Kubelet服务检查
echo "【7】Kubelet服务状态"
echo "----------------------------------------"
KUBELET_STATUS=$(systemctl is-active kubelet)
if [ "$KUBELET_STATUS" == "active" ]; then
    echo "Kubelet运行正常"
    kubelet --version
else
    echo "⚠️  Kubelet状态: $KUBELET_STATUS (初始化前为失败状态是正常的)"
fi
echo ""

# 8. 组件版本检查
echo "【8】K8s组件版本"
echo "----------------------------------------"
kubelet --version 2>/dev/null
kubeadm version --short 2>/dev/null || kubeadm version
kubectl version --client --short 2>/dev/null || kubectl version --client
echo ""

# 9. 网络连通性检查
echo "【9】节点间网络连通性"
echo "----------------------------------------"
echo "测试Master节点连通性:"
ping -c 2 172.16.0.10 > /dev/null 2>&1 && echo "Master节点可达" || echo "Master节点不可达"
ping -c 2 k8s-master-gz > /dev/null 2>&1 && echo "Master主机名解析正常" || echo "Master主机名解析失败"
echo ""

echo "========================================"
echo "              检查完成"
echo "========================================"
```

**使用方法**：
```bash
# 赋予执行权限
chmod +x node-env-check.sh

# 执行检查
./node-env-check.sh
```

---

## **总结**

完成以上所有步骤并通过验证后，您的Kubernetes集群（1 master + 2 worker）即部署完成。

### **快速验证清单**
- 所有节点防火墙、SELinux、Swap已关闭
- Containerd服务运行正常
- kubelet、kubeadm、kubectl版本一致
- Master节点初始化成功
- 网络插件（Flannel）正常运行
- Worker节点成功加入集群
- 所有节点状态为Ready
- 所有系统Pod状态为Running
- DNS解析正常工作

### **下一步操作建议**
1. **部署Dashboard**：安装Kubernetes Dashboard可视化界面
2. **配置存储**：根据需要配置NFS、Ceph等持久化存储
3. **安装Ingress**：部署Nginx Ingress Controller实现外部访问
4. **监控告警**：部署Prometheus + Grafana监控系统
5. **日志收集**：部署EFK（Elasticsearch + Fluentd + Kibana）日志系统

### **常用管理命令**
```bash
# 查看集群状态
kubectl get nodes
kubectl get pods -A
kubectl cluster-info

# 查看资源使用
kubectl top nodes
kubectl top pods -A

# 故障排查
kubectl describe node <node-name>
kubectl logs <pod-name> -n <namespace>
kubectl get events -A

# 节点维护
kubectl drain <node-name> --ignore-daemonsets  # 驱逐节点
kubectl cordon <node-name>                      # 标记节点不可调度
kubectl uncordon <node-name>                    # 恢复节点调度
```

🎉 **恭喜！现在可以开始部署您的应用了！**