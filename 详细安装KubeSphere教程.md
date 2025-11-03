# CentOS 9 在已有 Kubernetes 集群上安装 KubeSphere 详细教程

> **文档更新说明（2025-11-04）**：
> - ⭐ **新增**：KubeSphere版本选择详细说明（v3.4.1 vs v4.2.0）
> - ⭐ **新增**：官方安装方式对比（KubeKey vs kubectl）
> - ⭐ **新增**：为所有涉及镜像的步骤添加海外环境安装说明
> - ⭐ **新增**：环境选择指导，帮助用户根据网络环境选择合适的镜像源
> - ⭐ **新增**：NFS存储配置步骤明确标注各节点执行位置
> - 🔄 **更新**：GitHub下载方式（2025年），移除失效的镜像加速服务
> - 🔄 **更新**：明确说明本教程使用v3.4.1的原因和优势
> - 🔄 **更新**：澄清与KubeSphere官方v4.2.0文档的关系
> - 💡 **说明**：本教程专注于在已有K8s集群上安装，不同于官方全新安装方式
> - 优化文档结构，每个镜像配置点都提供国内和海外两种方案

## 目录
- [环境说明与方案选择](#环境说明与方案选择)
- [镜像源配置说明](#镜像源配置说明)
- [1. 环境说明](#1-环境说明)
  - [1.1 集群架构信息](#11-集群架构信息)
  - [1.2 KubeSphere 简介](#12-kubesphere-简介)
  - [1.3 关于KubeSphere版本选择（重要说明）](#13-关于kubesphere版本选择重要说明)
- [2. 前置条件检查](#2-前置条件检查)
  - [2.1 检查 Kubernetes 集群状态](#21-检查-kubernetes-集群状态)
  - [2.2 检查系统资源](#22-检查系统资源)
  - [2.3 检查存储类（StorageClass）](#23-检查存储类storageclass)
- [3. 准备工作](#3-准备工作)
  - [3.1 准备配置目录](#31-准备配置目录)
  - [3.2 创建 KubeSphere 部署文件](#32-创建-kubesphere-部署文件)
- [4. 安装 KubeSphere（最小化安装）](#4-安装-kubesphere最小化安装)
  - [4.1 创建 KubeSphere Installer 部署文件](#41-创建-kubesphere-installer-部署文件)
  - [4.2 修改集群配置文件](#42-修改集群配置文件)
  - [4.3 验证配置文件](#43-验证配置文件)
  - [4.4 执行安装](#44-执行安装)
  - [4.5 查看安装进度](#45-查看安装进度)
- [5. 访问 KubeSphere 控制台](#5-访问-kubesphere-控制台)
  - [5.1 获取访问地址](#51-获取访问地址)
  - [5.2 访问方式](#52-访问方式)
  - [5.3 首次登录](#53-首次登录)
  - [5.4 验证安装](#54-验证安装)
- [6. 启用可插拔组件（可选）](#6-启用可插拔组件可选)
  - [6.1 查看可用组件](#61-查看可用组件)
  - [6.2 常用组件说明](#62-常用组件说明)
  - [6.3 启用组件](#63-启用组件)
  - [6.4 查看组件安装进度](#64-查看组件安装进度)
  - [6.5 验证组件状态](#65-验证组件状态)
- [7. 常见问题处理](#7-常见问题处理)
- [8. 卸载 KubeSphere（可选）](#8-卸载-kubesphere可选)
- [9. 高级配置](#9-高级配置)
- [10. 常用操作和最佳实践](#10-常用操作和最佳实践)
- [11. 性能优化建议](#11-性能优化建议)
- [12. 参考资料](#12-参考资料)
- [13. 附录](#13-附录)
  - [13.1 完整的 KubeSphere Installer YAML](#131-完整的-kubesphere-installer-yaml)
  - [13.2 常用命令速查](#132-常用命令速查)
  - [13.3 配置 etcd 监控（可选）](#133-配置-etcd-监控可选)
- [14. 故障排查流程图](#14-故障排查流程图)

---

## 环境说明与方案选择

本文档支持**国内和海外**两种网络环境的部署。

### 国内环境（中国大陆）
- **特点**：官方镜像源（Docker Hub、Quay.io）访问慢或无法访问
- **解决方案**：使用阿里云镜像源加速
- **适用**：中国大陆的服务器

### 海外环境（国际/香港/台湾等）
- **特点**：可直接访问官方镜像源，速度快且稳定
- **解决方案**：直接使用 KubeSphere 官方镜像源
- **适用**：海外服务器、香港、台湾等地区

### 如何选择
在后续每个涉及镜像配置的步骤中，文档都会提供：
- **方案A：国内环境配置**（使用阿里云镜像）
- **方案B：海外环境配置**（使用官方镜像）

请根据您服务器的实际网络环境选择对应方案。

---

## 镜像源配置说明

### 方案A：国内环境镜像源（2025年最新可用）

**NFS Provisioner 镜像（已验证可用）**
- **主用镜像**: `registry.cn-hangzhou.aliyuncs.com/weiyigeek/nfs-subdir-external-provisioner:v4.0.2`
- **备用镜像1**: `registry.cn-beijing.aliyuncs.com/mydlq/nfs-subdir-external-provisioner:v4.0.0`
- **备用镜像2**: `dyrnq/nfs-subdir-external-provisioner:v4.0.2`

**KubeSphere 镜像（官方阿里云仓库）**
- **镜像仓库**: `registry.cn-beijing.aliyuncs.com/kubesphereio`
- **安装器镜像**: `registry.cn-beijing.aliyuncs.com/kubesphereio/ks-installer:v3.4.1`
- **说明**：这是 KubeSphere 官方维护的阿里云镜像仓库，长期稳定可用

### 方案B：海外环境镜像源

**NFS Provisioner 镜像（官方）**
- **镜像**: `registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2`
- **备用**: `k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2`

**KubeSphere 镜像（官方 Docker Hub）**
- **镜像仓库**: `kubesphere`（Docker Hub 官方仓库）
- **安装器镜像**: `kubesphere/ks-installer:v3.4.1`
- **说明**：KubeSphere 官方 Docker Hub 仓库，速度快且版本更新及时

### 使用建议
1. **国内环境**：优先使用主用镜像，失败则尝试备用镜像
2. **海外环境**：直接使用官方镜像即可
3. **本教程已在各步骤中提供两种方案的完整配置**

### 快速导航
- [开始安装 NFS 存储](#23-检查存储类storageclass)
- [开始安装 KubeSphere](#4-安装-kubesphere最小化安装)
- [故障排查指南](#7-常见问题处理)

---

## 1. 环境说明

### 1.1 集群架构信息

**节点配置：**
- **负载均衡器**：k8s-Load-Balancer-gz (172.16.3.1)
- **Master 节点**：k8s-master-gz (172.16.0.10)
- **Worker01 节点**：k8s-woker01-gz (172.16.1.10)
- **Worker02 节点**：k8s-woker02-gz (172.16.1.11)

**软件版本：**
- 操作系统：CentOS 9
- Kubernetes 版本：v1.28.0
- 网络插件：Flannel
- KubeSphere 版本：v3.4.1（本教程使用版本）

### 1.2 KubeSphere 简介

KubeSphere 是一个基于 Kubernetes 构建的**分布式操作系统**，提供了：
- 友好的 Web UI 控制台
- DevOps 工具链（CI/CD）
- 微服务治理（Service Mesh）
- 应用商店
- 多租户管理
- 监控告警
- 日志查询和收集
- 存储和网络管理

### 1.3 关于KubeSphere版本选择（重要说明）

**KubeSphere官方安装方式（2025年）：**
- **官方推荐工具**：KubeKey（https://docs.kubesphere.com.cn/v4.2.0/）
- **官方最新版本**：v4.2.0
- **安装方式**：全新安装Kubernetes + KubeSphere

**本教程的选择：**
- **使用版本**：KubeSphere v3.4.1（稳定版本）
- **安装方式**：kubectl方式，在已有Kubernetes集群上安装
- **适用场景**：已部署Kubernetes集群，不需要重新安装K8s

**为什么本教程使用v3.4.1而非v4.2.0？**

| 对比项 | v3.4.1（本教程） | v4.2.0（最新版） |
|--------|-----------------|-----------------|
| **成熟度** | ✅ 2023年发布，成熟稳定 | ⚠️ 2024年底发布，快速迭代中 |
| **安装方式** | ✅ kubectl方式明确 | ❌ 主要依赖KubeKey（需全新安装） |
| **已有集群** | ✅ 完美支持 | ⚠️ 支持不明确 |
| **文档完善** | ✅ 文档齐全，社区成熟 | ⚠️ 文档更新中 |
| **工具支持** | ✅ KubeKey v3.1.11支持 | ❌ KubeKey v3.1.11不支持 |
| **GitHub下载** | ✅ Release文件可用 | ❌ 经测试无法下载（返回404） |
| **生产推荐** | ✅ 推荐 | ⚠️ 待稳定后推荐 |

**版本选择建议：**
- ✅ **推荐v3.4.1**：已有K8s集群、生产环境、稳定性优先
- ⚠️ **可选v4.2.0**：全新部署、测试环境、愿意使用KubeKey重装K8s
- 📋 **未来升级**：v3.4.1可在未来升级到v4.x

**本教程优势：**
1. ✅ 不破坏现有Kubernetes集群
2. ✅ 使用kubectl原生方式，简单可控
3. ✅ 适合生产环境渐进式部署
4. ✅ 文档完善，遇到问题易解决
5. ✅ v3.4.1经过充分验证，稳定可靠

---

## 2. 前置条件检查

### 2.1 检查 Kubernetes 集群状态

在 master 节点执行以下命令：

```bash
# 检查节点状态（所有节点应为 Ready）
kubectl get nodes

# 检查所有 Pod 状态（所有 Pod 应为 Running）
kubectl get pods -A

# 检查 Kubernetes 版本（应为 1.19.x 及以上）
kubectl version
```

**预期输出：**
```
NAME             STATUS   ROLES           AGE   VERSION
k8s-master-gz    Ready    control-plane   17h   v1.28.0
k8s-woker01-gz   Ready    <none>          17h   v1.28.0
k8s-woker02-gz   Ready    <none>          17h   v1.28.0
```

### 2.2 检查系统资源

**KubeSphere 最小资源要求：**
- CPU：2 核（可用）
- 内存：4 GB（可用）
- 磁盘：40 GB（可用）

```bash
# 在所有节点检查资源
# 检查 CPU
lscpu | grep -E '^CPU\(s\):|^Model name:'

# 检查内存
free -h

# 检查磁盘空间
df -h

# 检查集群资源使用情况
kubectl top nodes
```

> **注意：** 如果要启用所有可插拔组件，建议资源配置：
> - CPU：8 核
> - 内存：16 GB
> - 磁盘：100 GB

### 2.3 检查存储类（StorageClass）

KubeSphere 组件需要持久化存储：

```bash
# 查看现有的 StorageClass
kubectl get sc

# 查看是否有默认的 StorageClass
kubectl get sc | grep "(default)"
```

**生产环境存储方案选择建议：**

根据实际生产环境经验，不同部署环境推荐的存储方案：

**云上环境（推荐指数：5/5）**
- **阿里云**：`alicloud-disk-essd`（高性能）或 `alicloud-disk-ssd`（标准性能）
- **AWS**：`gp3`（通用SSD）或 `io2`（高性能场景）
- **腾讯云**：`cbs-ssd` 或 `cbs-premium`
- **华为云**：`sas`（SAS盘）或 `ssd`（SSD盘）
- **优势**：开箱即用、自动备份、按需扩容、无需运维
- **成本**：约 0.35-1 元/GB/月（根据性能等级）

**自建环境 - 大规模（50+节点）**
- **推荐**：Ceph RBD（块存储）+ CephFS（文件存储）
- **配置**：至少3节点SSD存储集群、万兆网络、副本数3
- **工具**：使用 Rook-Ceph Operator 简化部署
- **优势**：高性能、高可用、久经考验
- **投入**：约15-20万元（一次性硬件成本）

**自建环境 - 中小规模（10-50节点）**
- **推荐**：Longhorn 分布式块存储
- **配置**：每节点挂载额外数据盘（500GB-2TB SSD）、副本数3
- **优势**：部署简单、Web UI管理、自动快照备份
- **投入**：约3-5万元（根据节点数和磁盘规格）

**自建环境 - 小规模（<10节点）**
- **推荐**：高可用NFS（双机热备 + Keepalived）
- **配置**：Primary + Backup NFS服务器、共享存储（SAN或RAID）
- **优势**：技术门槛低、支持ReadWriteMany
- **注意**：单点性能瓶颈，不适合IO密集型应用

**KubeSphere 组件存储需求**：
- **Prometheus**（监控）：20-50GB，需要高IOPS
- **Elasticsearch**（日志）：50-200GB，IO密集
- **Redis/MySQL**（元数据）：10-20GB，需要高可用
- **Jenkins**（DevOps）：10-30GB
- **MinIO**（对象存储）：20-100GB

**选择建议**：
- 云上部署：100%使用云厂商托管存储
- 自建大规模：Ceph（有专业运维团队）
- 自建中小规模：Longhorn（性价比最高）
- 测试/学习环境：单节点NFS（快速搭建）

---

**如果没有 StorageClass，需要先配置：**

#### 方案 1：使用 NFS 动态存储（推荐）

NFS 动态存储适用于大多数场景：
- **测试/开发环境**：快速部署，易于管理
- **中小规模生产环境**：配合高可用 NFS 服务器（如使用 NFS-Ganesha + Ceph）可用于生产
- **优点**：支持 ReadWriteMany（多节点读写）、动态创建 PV、易于扩容
- **注意**：大规模生产环境建议使用 Ceph RBD、GlusterFS 或云存储

**步骤 1：安装 NFS 服务器**

**执行节点：Master 节点（或专门的存储服务器）**

本示例在 master 节点（`k8s-master-gz`，IP: `172.16.0.10`）上安装 NFS 服务器。您也可以选择专门的存储服务器。

```bash
# 安装 NFS 服务器
dnf install -y nfs-utils

# 创建共享目录
mkdir -p /nfs/data
chmod -R 777 /nfs/data

# 配置 NFS 导出
cat > /etc/exports <<EOF
/nfs/data *(rw,sync,no_root_squash,no_subtree_check)
EOF

# 启动 NFS 服务
systemctl enable nfs-server --now
systemctl status nfs-server

# 导出共享目录
exportfs -arv

# 查看导出的共享
showmount -e localhost
```

**验证 NFS 服务器安装：**

**执行节点：Master 节点（NFS 服务器所在节点）**

```bash
# 1. 检查 NFS 服务状态
systemctl status nfs-server

# 2. 验证共享目录已导出
showmount -e localhost
# 预期输出：
# Export list for localhost:
# /nfs/data *

# 3. 检查共享目录权限
ls -ld /nfs/data
# 预期输出：drwxrwxrwx

# 4. 测试写入权限
touch /nfs/data/test.txt && rm -f /nfs/data/test.txt && echo "NFS 目录写入权限正常" || echo "NFS 目录写入权限异常"
```

**步骤 2：安装 NFS 客户端**

**执行节点：所有 Worker 节点（如果 Master 不是 NFS 服务器，也需要在 Master 节点执行）**

在本示例中，需要在以下节点执行：
- `k8s-woker01-gz` (172.16.1.10)
- `k8s-woker02-gz` (172.16.1.11)

```bash
# 在每个 worker 节点分别执行
dnf install -y nfs-utils

# 测试挂载（验证与 NFS 服务器的连接）
mkdir -p /mnt/test
mount -t nfs 172.16.0.10:/nfs/data /mnt/test
umount /mnt/test
```

**验证 NFS 客户端安装：**

**执行节点：每个 Worker 节点**

```bash
# 在每个 worker 节点分别执行以下验证

# 1. 检查 NFS 客户端工具是否安装
which mount.nfs
# 预期输出：/usr/sbin/mount.nfs

# 2. 测试是否能查看 NFS 服务器的共享
showmount -e 172.16.0.10
# 预期输出应显示 /nfs/data

# 3. 测试挂载和读写
mkdir -p /mnt/test
mount -t nfs 172.16.0.10:/nfs/data /mnt/test
echo "test" > /mnt/test/test-$(hostname).txt
cat /mnt/test/test-$(hostname).txt
rm -f /mnt/test/test-$(hostname).txt
umount /mnt/test
rmdir /mnt/test
echo "NFS 客户端测试成功"
```

**步骤 3：安装 NFS Provisioner**

**执行节点：Master 节点（有 kubectl 权限的节点）**

使用 kubectl 部署 NFS Provisioner，它会自动在 Kubernetes 集群中创建存储类。

```bash
# 创建 NFS Provisioner 命名空间
kubectl create namespace nfs-provisioner

# 使用 Helm 安装（如果没有 Helm，参见下方安装 Helm）
# 添加 Helm 仓库
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

# 更新 Helm 仓库
helm repo update

# 安装 NFS Provisioner
helm install nfs-subdir-external-provisioner \
  nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace nfs-provisioner \
  --set nfs.server=172.16.0.10 \
  --set nfs.path=/nfs/data \
  --set storageClass.defaultClass=true
```

**如果没有 Helm，先安装 Helm：**

**方法1：使用官方安装脚本（推荐）**

```bash
# 下载 Helm 安装脚本
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o get_helm.sh

# 添加执行权限
chmod +x get_helm.sh

# 执行安装脚本
./get_helm.sh

# 验证安装
helm version
```

**方法2：手动下载二进制文件（适用于无法访问GitHub的环境）**

```bash
# 下载 Helm 二进制包
curl -fsSL https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz -o helm.tar.gz

# 解压
tar -zxvf helm.tar.gz

# 移动到系统路径
mv linux-amd64/helm /usr/local/bin/helm

# 添加执行权限
chmod +x /usr/local/bin/helm

# 清理下载文件
rm -rf linux-amd64 helm.tar.gz

# 验证安装
helm version
```

**或者使用 YAML 方式部署 NFS Provisioner（根据环境选择镜像）：**

**执行节点：Master 节点（有 kubectl 权限的节点）**

**方案A：国内环境配置**

```bash
# 创建 NFS Provisioner 部署文件（使用阿里云镜像）
cat > nfs-provisioner-deploy.yaml <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
  namespace: kube-system
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  namespace: kube-system
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  namespace: kube-system
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: kube-system
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  namespace: kube-system
  labels:
    app: nfs-client-provisioner
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: registry.cn-hangzhou.aliyuncs.com/weiyigeek/nfs-subdir-external-provisioner:v4.0.2
          # 国内备用镜像1: registry.cn-beijing.aliyuncs.com/mydlq/nfs-subdir-external-provisioner:v4.0.0
          # 国内备用镜像2: dyrnq/nfs-subdir-external-provisioner:v4.0.2
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: k8s-sigs.io/nfs-subdir-external-provisioner
            - name: NFS_SERVER
              value: 172.16.0.10
            - name: NFS_PATH
              value: /nfs/data
      volumes:
        - name: nfs-client-root
          nfs:
            server: 172.16.0.10
            path: /nfs/data
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-client
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner
parameters:
  archiveOnDelete: "false"
EOF

# 应用配置
kubectl apply -f nfs-provisioner-deploy.yaml
```

---

**方案B：海外环境配置**

```bash
# 创建 NFS Provisioner 部署文件（使用官方镜像）
cat > nfs-provisioner-deploy.yaml <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
  namespace: kube-system
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  namespace: kube-system
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  namespace: kube-system
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: kube-system
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  namespace: kube-system
  labels:
    app: nfs-client-provisioner
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
          # 海外备用镜像: k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: k8s-sigs.io/nfs-subdir-external-provisioner
            - name: NFS_SERVER
              value: 172.16.0.10
            - name: NFS_PATH
              value: /nfs/data
      volumes:
        - name: nfs-client-root
          nfs:
            server: 172.16.0.10
            path: /nfs/data
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-client
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner
parameters:
  archiveOnDelete: "false"
EOF

# 应用配置
kubectl apply -f nfs-provisioner-deploy.yaml
```

---

**说明**：
- 国内环境使用阿里云镜像，避免拉取失败
- 海外环境使用官方镜像，速度更快且版本更新
- 两种配置除镜像地址外完全相同

```bash
# 验证部署
kubectl get pods -n kube-system | grep nfs-client-provisioner
kubectl get sc
```

**验证 NFS Provisioner 部署：**

**执行节点：Master 节点（有 kubectl 权限的节点）**

```bash
# 1. 检查 Pod 状态（必须是 Running）
kubectl get pods -n kube-system | grep nfs-client-provisioner
# 预期输出：nfs-client-provisioner-xxx   1/1     Running   0          1m

# 2. 查看 Pod 日志，确认无错误
kubectl logs -n kube-system $(kubectl get pod -n kube-system -l app=nfs-client-provisioner -o jsonpath='{.items[0].metadata.name}')
# 应该看到类似：
# Provisioner started...
# 无明显 ERROR 信息

# 3. 检查 StorageClass 是否创建成功
kubectl get sc
# 预期输出应包含：
# NAME                   PROVISIONER                            RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
# nfs-client (default)   k8s-sigs.io/nfs-subdir-external-...   Delete          Immediate              false                  1m

# 4. 检查 StorageClass 是否为默认
kubectl get sc nfs-client -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}'
# 预期输出：true

# 5. 【重要】测试动态存储是否工作
cat > test-pvc.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client
  resources:
    requests:
      storage: 1Gi
EOF

kubectl apply -f test-pvc.yaml

# 等待几秒后检查 PVC 状态
sleep 5
kubectl get pvc test-pvc
# 预期输出：
# NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# test-pvc   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   1Gi        RWX            nfs-client     5s

# 检查 PV 是否自动创建
kubectl get pv | grep test-pvc

# 检查 NFS 服务器上是否创建了目录（在 NFS 服务器节点执行）
# 切换到 NFS 服务器节点（本例中是 master 节点）
ls -la /nfs/data/
# 应该看到类似：default-test-pvc-pvc-xxxxxxxx 的目录

# 清理测试 PVC（在 master 节点执行）
kubectl delete -f test-pvc.yaml
rm -f test-pvc.yaml

echo "NFS 动态存储测试成功！"
```

**💡 步骤总结：**
- **步骤 1（NFS 服务器安装）**：在 Master 节点执行
- **步骤 2（NFS 客户端安装）**：在所有 Worker 节点执行
- **步骤 3（NFS Provisioner 部署）**：在 Master 节点执行
- **验证步骤**：主要在 Master 节点执行 kubectl 命令，部分验证需要在各自的节点执行

**如果验证失败，请检查：**
- Pod 日志中的错误信息（参见 [7.2 镜像拉取失败](#72-镜像拉取失败imagepullbackoff)）
- NFS 服务器是否正常运行
- 网络连接是否正常
- 镜像是否成功拉取（参见 [镜像源配置说明](#镜像源配置说明)）

#### 方案 2：使用本地存储（仅用于测试）

本地存储仅适用于测试或学习环境：
- **适用场景**：单节点测试、快速验证功能
- **限制**：
  - 不支持动态创建 PV（需要手动创建 PV）
  - 不支持 ReadWriteMany（多节点读写）
  - Pod 只能调度到有 PV 的节点
  - 数据无法迁移和备份
- **不推荐生产环境使用**

**执行节点：Master 节点（有 kubectl 权限的节点）**

```bash
cat > local-storage.yaml <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF

kubectl apply -f local-storage.yaml
```

---

## 3. 准备工作

### 3.1 准备配置目录

**在 master 节点创建配置目录：**

```bash
# 创建 KubeSphere 配置目录
mkdir -p ~/kubesphere
cd ~/kubesphere
```

**环境确认**：
- **国内环境**：后续步骤将使用阿里云镜像源（`registry.cn-beijing.aliyuncs.com/kubesphereio`）
- **海外环境**：后续步骤将使用官方镜像源（`kubesphere` Docker Hub）

请根据您的实际网络环境，在后续步骤中选择对应的配置方案。

### 3.2 创建 KubeSphere 部署文件


**方法 1：使用本教程提供的完整 YAML**

本教程在以下章节提供了完整的 YAML 文件内容，已配置好国内镜像源。

**直接跳转到以下章节，按照步骤创建文件即可：**
- 完整的 `kubesphere-installer.yaml` → [第 13.1 节附录](#131-完整的-kubesphere-installer-yaml)
- 完整的 `cluster-configuration.yaml` → [第 4.2 节](#42-修改集群配置文件)

**方法 2：从 GitHub 官方下载（需要验证和修改）**

**⚠️ 版本说明（2025年实测更新）：**

**本教程使用v3.4.1的原因：**
1. **KubeSphere v4.2.0现状（经实际测试）**：
   - ❌ KubeKey v3.1.11不支持v4.2.0（报错：`Unsupported KubeSphere version`）
   - ❌ GitHub Release文件无法下载（返回`Not Found`，只有9字节）
   - ⚠️ 主要通过KubeKey全新安装，不适合已有K8s集群
   - ⚠️ 文档和工具链还在快速迭代中

2. **KubeSphere v3.4.1优势（经验证）**：
   - ✅ 成熟稳定，生产环境广泛使用
   - ✅ kubectl方式明确支持已有集群
   - ✅ 文档完善，社区支持充分
   - ✅ GitHub Release文件可正常下载
   - ✅ 与Kubernetes v1.28.0兼容性好

**官方文档参考：**
- **v4.2.0官方文档**：https://docs.kubesphere.com.cn/v4.2.0/ （使用KubeKey全新安装）
- **v3.4官方文档**：https://www.kubesphere.io/zh/docs/v3.4/ （支持kubectl方式）
- **本教程定位**：在已有K8s集群上安装v3.4.1（kubectl方式）

**升级路径：**
- 本教程安装v3.4.1后，待v4.x成熟，可按官方文档升级

```bash
# ⚠️ 注意：从 GitHub 下载的文件需要验证和修改

# 方法 2A：直接从 GitHub 官方下载（需要能访问 GitHub）
wget https://github.com/kubesphere/ks-installer/releases/download/v3.4.1/kubesphere-installer.yaml
wget https://github.com/kubesphere/ks-installer/releases/download/v3.4.1/cluster-configuration.yaml

# 方法 2B：使用 GitHub API 下载（更稳定）
curl -L -o kubesphere-installer.yaml \
  https://github.com/kubesphere/ks-installer/releases/download/v3.4.1/kubesphere-installer.yaml
curl -L -o cluster-configuration.yaml \
  https://github.com/kubesphere/ks-installer/releases/download/v3.4.1/cluster-configuration.yaml

# 方法 2C：使用 Git 克隆仓库（推荐，可获取最新文件）
git clone --depth 1 --branch v3.4.1 https://github.com/kubesphere/ks-installer.git
cd ks-installer/deploy
# 文件位于 kubesphere-installer.yaml 和 cluster-configuration.yaml

# ⚠️ 重要：下载后必须进行以下验证和修改
# 1. 验证是否包含 ClusterConfiguration CRD 定义
grep "CustomResourceDefinition" kubesphere-installer.yaml
# 如果没有输出，说明缺少 CRD，必须使用方法1

# 2. 根据网络环境修改镜像地址
# 国内环境：将镜像改为阿里云镜像源（参考附录 13.1）
# 海外环境：保持官方镜像即可

# 3. 检查版本是否匹配
grep "v3.4.1" kubesphere-installer.yaml cluster-configuration.yaml
```

**⚠️ GitHub 镜像加速服务说明（2025年更新）：**
- 由于政策变化，许多 GitHub 镜像加速服务（如 ghproxy.com、ghps.cc）已停止服务或不稳定
- **不再推荐**使用第三方镜像站，建议：
  - **国内用户**：使用本教程提供的完整 YAML（方法1）
  - **海外用户**：直接从 GitHub 官方下载即可
  - **企业用户**：自建 GitHub 镜像或使用代理服务

**验证下载的文件（如果成功下载）：**

```bash
# 检查文件是否下载成功
ls -lh kubesphere-installer.yaml cluster-configuration.yaml

# 查看文件内容是否完整
head -n 10 kubesphere-installer.yaml
head -n 10 cluster-configuration.yaml

# 如果文件不完整或下载失败，请使用方法1
```

---

## 4. 安装 KubeSphere（最小化安装）

### 4.1 创建 KubeSphere Installer 部署文件

**直接创建 kubesphere-installer.yaml 文件（已配置国内镜像）：**

由于 GitHub 下载链接经常失效，直接使用以下命令创建文件，内容已配置好国内镜像源。

完整的 YAML 内容见本教程 [第 13.1 节附录](#131-完整的-kubesphere-installer-yaml国内镜像版)，这里使用简化方式创建：

```bash
# 进入工作目录
cd ~/kubesphere

# 方式1：直接复制附录 13.1 节的完整 YAML 内容创建文件（推荐）
# 请向下滚动到第 13.1 节，复制完整的 kubesphere-installer.yaml 内容

# 方式2：如果已经下载了文件，修改镜像地址为国内镜像
# 备份原文件
cp kubesphere-installer.yaml kubesphere-installer.yaml.bak

# 修改镜像地址
sed -i 's|kubesphere/ks-installer:v3.4.1|registry.cn-beijing.aliyuncs.com/kubesphereio/ks-installer:v3.4.1|g' kubesphere-installer.yaml
```

**快速验证文件是否正确：**

```bash
# 检查文件是否存在
ls -lh kubesphere-installer.yaml

# 验证镜像地址是否为国内镜像
grep "image:" kubesphere-installer.yaml | grep kubesphereio
# 应该输出：image: registry.cn-beijing.aliyuncs.com/kubesphereio/ks-installer:v3.4.1

# 验证 YAML 语法
kubectl apply -f kubesphere-installer.yaml --dry-run=client
```

### 4.2 修改集群配置文件

**编辑 cluster-configuration.yaml：**

```bash
vim cluster-configuration.yaml
```

**关键配置项说明：**

```yaml
apiVersion: installer.kubesphere.io/v1alpha1
kind: ClusterConfiguration
metadata:
  name: ks-installer
  namespace: kubesphere-system
  labels:
    version: v3.4.1
spec:
  persistence:
    storageClass: ""  # 如果有默认 StorageClass，保持为空；否则填写创建的 SC 名称，如 "nfs-client"
  authentication:
    jwtSecret: ""  # 保持为空，系统会自动生成
  local_registry: ""  # 留空即可
  namespace_override: ""
  # 镜像仓库配置（使用 KubeSphere 官方阿里云镜像）
  imageRegistry: registry.cn-beijing.aliyuncs.com/kubesphereio
  
  # 最小化安装：禁用所有可插拔组件
  alerting:
    enabled: false
  auditing:
    enabled: false
  devops:
    enabled: false
  events:
    enabled: false
  logging:
    enabled: false
  metrics_server:
    enabled: true  # 建议启用，用于资源监控
  monitoring:
    storageClass: ""  # 使用默认 StorageClass
    node_exporter:
      port: 9100
    # Prometheus 存储设置（可选）
    # prometheusMemoryRequest: 400Mi
    # prometheusVolumeSize: 20Gi
  multicluster:
    clusterRole: none  # 单集群模式（详见下方说明）
  network:
    networkpolicy:
      enabled: false
    ippool:
      type: none
    topology:
      type: none
  openpitrix:
    store:
      enabled: false
  servicemesh:
    enabled: false
  kubeedge:
    enabled: false
  gatekeeper:
    enabled: false
```

**什么是单集群模式（Single Cluster Mode）？**

KubeSphere 支持两种部署模式：

| 模式 | 配置值 | 说明 | 适用场景 |
|------|--------|------|----------|
| **单集群模式** | `clusterRole: none` | 只管理当前这一个 Kubernetes 集群 | • 测试环境<br>• 小型项目<br>• 单一集群场景<br>• **推荐初次安装使用** |
| **多集群模式 - Host** | `clusterRole: host` | 作为主集群，管理多个 Member 集群 | • 生产环境<br>• 需要统一管理多个集群<br>• 跨区域部署 |
| **多集群模式 - Member** | `clusterRole: member` | 作为成员集群，被 Host 集群管理 | • 被 Host 集群纳管<br>• 工作负载集群 |

**单集群模式特点：**
- 配置简单，易于安装和维护
- 资源消耗较少
- 适合大多数场景
- 可以随时升级为多集群模式的 Host 或 Member

**多集群模式使用场景：**
- 需要在一个控制台统一管理多个 Kubernetes 集群
- 跨区域、跨云平台部署
- 需要实现集群间应用的高可用和容灾

**📝 本教程使用单集群模式（`clusterRole: none`），这是最常见和推荐的部署方式。**

**根据您的网络环境选择对应的配置：**

---

### 方案A：国内环境配置（使用阿里云镜像）

```bash
cat > cluster-configuration.yaml <<'EOF'
---
apiVersion: installer.kubesphere.io/v1alpha1
kind: ClusterConfiguration
metadata:
  name: ks-installer
  namespace: kubesphere-system
  labels:
    version: v3.4.1
spec:
  persistence:
    storageClass: ""
  authentication:
    jwtSecret: ""
  local_registry: ""
  namespace_override: ""
  # 镜像仓库配置（根据环境选择）
  # 国内环境使用阿里云镜像：registry.cn-beijing.aliyuncs.com/kubesphereio
  # 海外环境使用官方镜像：kubesphere （或留空使用默认）
  imageRegistry: registry.cn-beijing.aliyuncs.com/kubesphereio
  
  # etcd 监控配置
  # 方式1：禁用 etcd 监控（简单快速，适合不需要监控 etcd 的场景）
  etcd:
    monitoring: false  # 设置为 false 禁用 etcd 监控
    endpointIps: localhost
    port: 2379
    tlsEnable: true
  
  # 方式2：启用 etcd 监控（需要正确配置 etcd 证书路径，参见下方说明）
  # etcd:
  #   monitoring: true  # 设置为 true 启用 etcd 监控
  #   endpointIps: 172.16.0.10  # etcd 节点的 IP，多个节点用逗号分隔
  #   port: 2379
  #   tlsEnable: true
  #   # etcd 证书配置（Kubernetes 集群中 etcd 证书的实际路径）
  #   # kubeadm 部署的默认路径：/etc/kubernetes/pki/etcd/
  #   tlsCaFile: /etc/kubernetes/pki/etcd/ca.crt
  #   tlsCertFile: /etc/kubernetes/pki/etcd/healthcheck-client.crt
  #   tlsKeyFile: /etc/kubernetes/pki/etcd/healthcheck-client.key
  
  # etcd 监控配置说明：
  # 1. 如果不需要监控 etcd 性能指标，设置 monitoring: false（推荐新手）
  # 2. 如果需要完整的集群监控（包括 etcd），设置 monitoring: true 并配置正确的证书路径
  # 3. 详细配置方法请参考本文档附录：[13.3 配置 etcd 监控](#133-配置-etcd-监控可选)
  
  common:
    core:
      console:
        enableMultiLogin: true
        port: 30880
        type: NodePort
    # Redis 配置
    redis:
      enabled: false
      enableHA: false
      volumeSize: 2Gi
    # OpenLDAP 配置
    openldap:
      enabled: false
      volumeSize: 2Gi
    # MinIO 配置
    minio:
      volumeSize: 20Gi
    # 监控配置
    monitoring:
      endpoint: http://prometheus-operated.kubesphere-monitoring-system.svc:9090
      GPUMonitoring:
        enabled: false
    gpu:
      kinds:
      - resourceName: "nvidia.com/gpu"
        resourceType: "GPU"
        default: true
    es:
      enabled: false
      logMaxAge: 7
      elkPrefix: logstash
      basicAuth:
        enabled: false
        username: ""
        password: ""
      externalElasticsearchHost: ""
      externalElasticsearchPort: ""
  
  # 最小化安装配置
  alerting:
    enabled: false
  auditing:
    enabled: false
  devops:
    enabled: false
  events:
    enabled: false
  logging:
    enabled: false
  metrics_server:
    enabled: true
  monitoring:
    storageClass: ""
    node_exporter:
      port: 9100
      resources: {}
    kube_rbac_proxy:
      resources: {}
    kube_state_metrics:
      resources: {}
    prometheus:
      replicas: 1
      volumeSize: 20Gi
      resources: {}
    alertmanager:
      replicas: 1
      resources: {}
    notification_manager:
      resources: {}
      replicas: 2
      image:
        ks_am_operator_repo: kubesphereio/alertmanager-operator
        ks_am_operator_tag: v0.2.3
        ks_notification_manager_repo: kubesphereio/notification-manager
        ks_notification_manager_tag: v2.3.0
        ks_notification_tenant_sidecar_repo: kubesphereio/notification-tenant-sidecar
        ks_notification_tenant_sidecar_tag: v3.2.0
    gpu:
      nvidia_dcgm_exporter:
        enabled: false
        resources: {}
  multicluster:
    clusterRole: none
  network:
    networkpolicy:
      enabled: false
    ippool:
      type: none
    topology:
      type: none
  openpitrix:
    store:
      enabled: false
  servicemesh:
    enabled: false
    istio:
      components:
        ingressGateways:
        - name: istio-ingressgateway
          enabled: false
        cni:
          enabled: false
  edgeruntime:
    enabled: false
    kubeedge:
      enabled: false
      cloudCore:
        cloudHub:
          advertiseAddress:
            - ""
        service:
          cloudhubNodePort: "30000"
          cloudhubQuicNodePort: "30001"
          cloudhubHttpsNodePort: "30002"
          cloudstreamNodePort: "30003"
          tunnelNodePort: "30004"
        resources: {}
      iptables-manager:
        enabled: true
        resources: {}
      edgeService:
        resources: {}
  gatekeeper:
    enabled: false
    controller_manager:
      resources: {}
    audit:
      resources: {}
  terminal:
    timeout: 600
EOF
```

---

### 方案B：海外环境配置（使用官方镜像）

```bash
cat > cluster-configuration.yaml <<'EOF'
---
apiVersion: installer.kubesphere.io/v1alpha1
kind: ClusterConfiguration
metadata:
  name: ks-installer
  namespace: kubesphere-system
  labels:
    version: v3.4.1
spec:
  persistence:
    storageClass: ""
  authentication:
    jwtSecret: ""
  local_registry: ""
  namespace_override: ""
  # 海外环境使用官方镜像仓库（留空或填写 kubesphere）
  imageRegistry: ""  # 留空使用默认官方镜像，或填写：kubesphere
  
  # etcd 监控配置
  etcd:
    monitoring: false
    endpointIps: localhost
    port: 2379
    tlsEnable: true
  
  common:
    core:
      console:
        enableMultiLogin: true
        port: 30880
        type: NodePort
    redis:
      enabled: false
      enableHA: false
      volumeSize: 2Gi
    openldap:
      enabled: false
      volumeSize: 2Gi
    minio:
      volumeSize: 20Gi
    monitoring:
      endpoint: http://prometheus-operated.kubesphere-monitoring-system.svc:9090
      GPUMonitoring:
        enabled: false
    gpu:
      kinds:
      - resourceName: "nvidia.com/gpu"
        resourceType: "GPU"
        default: true
    es:
      enabled: false
      logMaxAge: 7
      elkPrefix: logstash
      basicAuth:
        enabled: false
        username: ""
        password: ""
      externalElasticsearchHost: ""
      externalElasticsearchPort: ""
  
  # 最小化安装配置
  alerting:
    enabled: false
  auditing:
    enabled: false
  devops:
    enabled: false
  events:
    enabled: false
  logging:
    enabled: false
  metrics_server:
    enabled: true
  monitoring:
    storageClass: ""
    node_exporter:
      port: 9100
      resources: {}
    kube_rbac_proxy:
      resources: {}
    kube_state_metrics:
      resources: {}
    prometheus:
      replicas: 1
      volumeSize: 20Gi
      resources: {}
    alertmanager:
      replicas: 1
      resources: {}
    notification_manager:
      resources: {}
      replicas: 2
      image:
        ks_am_operator_repo: kubesphereio/alertmanager-operator
        ks_am_operator_tag: v0.2.3
        ks_notification_manager_repo: kubesphereio/notification-manager
        ks_notification_manager_tag: v2.3.0
        ks_notification_tenant_sidecar_repo: kubesphereio/notification-tenant-sidecar
        ks_notification_tenant_sidecar_tag: v3.2.0
    gpu:
      nvidia_dcgm_exporter:
        enabled: false
        resources: {}
  multicluster:
    clusterRole: none
  network:
    networkpolicy:
      enabled: false
    ippool:
      type: none
    topology:
      type: none
  openpitrix:
    store:
      enabled: false
  servicemesh:
    enabled: false
    istio:
      components:
        ingressGateways:
        - name: istio-ingressgateway
          enabled: false
        cni:
          enabled: false
  edgeruntime:
    enabled: false
    kubeedge:
      enabled: false
      cloudCore:
        cloudHub:
          advertiseAddress:
            - ""
        service:
          cloudhubNodePort: "30000"
          cloudhubQuicNodePort: "30001"
          cloudhubHttpsNodePort: "30002"
          cloudstreamNodePort: "30003"
          tunnelNodePort: "30004"
        resources: {}
      iptables-manager:
        enabled: true
        resources: {}
      edgeService:
        resources: {}
  gatekeeper:
    enabled: false
    controller_manager:
      resources: {}
    audit:
      resources: {}
  terminal:
    timeout: 600
EOF
```

---

**配置说明**：
- **国内环境（方案A）**：`imageRegistry` 配置为 `registry.cn-beijing.aliyuncs.com/kubesphereio`
- **海外环境（方案B）**：`imageRegistry` 留空或配置为 `kubesphere`，使用Docker Hub官方镜像
- 两种配置除镜像仓库外完全相同
- 海外环境镜像拉取速度更快，版本更新及时

### 4.3 验证配置文件

在执行安装前，先验证配置文件是否正确：

```bash
# 1. 验证 kubesphere-installer.yaml 语法
kubectl apply -f kubesphere-installer.yaml --dry-run=client
# 如果没有错误，会显示：namespace/kubesphere-system configured (dry run)

# 2. 验证 cluster-configuration.yaml 语法
kubectl apply -f cluster-configuration.yaml --dry-run=client
# 如果没有错误，会显示：clusterconfiguration.installer.kubesphere.io/ks-installer configured (dry run)

# 3. 检查镜像地址是否正确（根据环境验证）
grep "image:" kubesphere-installer.yaml
# 国内环境应该包含：registry.cn-beijing.aliyuncs.com/kubesphereio/ks-installer:v3.4.1
# 海外环境应该包含：kubesphere/ks-installer:v3.4.1

# 4. 检查 imageRegistry 配置（根据环境验证）
grep "imageRegistry:" cluster-configuration.yaml
# 国内环境应该包含：registry.cn-beijing.aliyuncs.com/kubesphereio
# 海外环境应该为空或包含：kubesphere

echo "配置文件验证通过"
```

### 4.4 执行安装

**⚠️ 重要：正确的安装方法**

KubeSphere 的安装需要同时应用 installer 和 configuration 两个文件。**installer 文件中已包含 CRD 定义**，因此可以一起应用。

**步骤 1：同时部署 Installer 和 Configuration**

```bash
# 清理可能存在的旧资源
kubectl delete -f cluster-configuration.yaml 2>/dev/null || true
kubectl delete -f kubesphere-installer.yaml 2>/dev/null || true
kubectl delete namespace kubesphere-system 2>/dev/null || true

# 等待清理完成
echo "等待旧资源清理..."
sleep 15

# 同时应用两个文件（推荐方法）
echo "开始部署 KubeSphere..."
kubectl apply -f kubesphere-installer.yaml
kubectl apply -f cluster-configuration.yaml

# 验证资源创建
kubectl get ns kubesphere-system
kubectl get cc -n kubesphere-system ks-installer
# 预期输出应显示 namespace 和 ClusterConfiguration 都已创建
```

**步骤 2：等待 Installer Pod 启动**

```bash
# 等待 Pod 创建
echo "等待 ks-installer Pod 启动..."
sleep 10

# 检查 Pod 状态
kubectl get pods -n kubesphere-system
# 预期输出：
# NAME                             READY   STATUS    RESTARTS   AGE
# ks-installer-xxxx-xxxx           0/1     ContainerCreating   0   10s

# 等待 Pod 变为 Running 状态（这可能需要 30-90 秒）
kubectl wait --for=condition=Ready pod -l app=ks-installer -n kubesphere-system --timeout=180s || {
  echo "⚠️ Pod 启动超时，检查状态："
  kubectl get pods -n kubesphere-system
  kubectl describe pod -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}') | tail -30
}

# 确认 Pod 正常运行
kubectl get pods -n kubesphere-system -l app=ks-installer
# 预期输出：
# NAME                             READY   STATUS    RESTARTS   AGE
# ks-installer-xxxx-xxxx           1/1     Running   0          2m
```

**步骤 3：验证 CRD 和配置**

```bash
# 验证 ClusterConfiguration CRD 已创建
kubectl get crd clusterconfigurations.installer.kubesphere.io
# 预期输出：
# NAME                                              CREATED AT
# clusterconfigurations.installer.kubesphere.io     2025-10-24T06:20:00Z

# 验证 ClusterConfiguration 资源已创建
kubectl get cc -n kubesphere-system ks-installer
# 预期输出：
# NAME           AGE
# ks-installer   1m

echo "✓ KubeSphere 安装已启动"
```

**步骤 4：查看安装启动日志**

```bash
# 查看 installer 日志，确认安装开始
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}') --tail=30

# 应该看到类似：
# INFO : shell-operator latest
# INFO : MAIN: run main loop
# INFO : Start reconciling ClusterConfiguration
# 没有 ERROR 信息表示正常
```

**如果遇到问题：**

如果 `ks-installer` Pod 一直处于 `CrashLoopBackOff` 或 `Error` 状态：

```bash
# 查看完整的错误日志
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}')

# 如果 Pod 已重启，查看上一次的日志
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}') --previous

# 常见错误 1：ClusterConfiguration CRD not found
# 原因：使用了旧版本的 installer.yaml 文件（不包含 CRD 定义）
# 解决：使用本教程附录 13.1 提供的完整 YAML 文件

# 常见错误 2：镜像拉取失败
# 原因：网络问题或镜像地址错误
# 解决：检查镜像地址，参考 [7.3 镜像拉取失败](#73-镜像拉取失败imagepullbackoff)

# 常见错误 3：YAML 文件不完整
# 解决：删除并重新创建，使用附录 13.1 的完整内容
kubectl delete -f kubesphere-installer.yaml
kubectl delete -f cluster-configuration.yaml
# 然后重新创建文件并应用
```

### 4.5 查看安装进度

```bash
# 查看安装日志（实时跟踪）
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l 'app in (ks-install, ks-installer)' -o jsonpath='{.items[0].metadata.name}') -f

# 查看所有 Pod 状态
kubectl get pods -n kubesphere-system

# 查看所有相关命名空间的 Pod
kubectl get pods -A | grep kubesphere
```

**安装过程大约需要 10-30 分钟，取决于网络速度和硬件性能。**

**实时监控安装进度：**

```bash
# 每隔 30 秒检查一次 Pod 状态
watch -n 30 'kubectl get pods -A | grep kubesphere'

# 或者持续查看关键命名空间
watch -n 10 'kubectl get pods -n kubesphere-system && echo "---" && kubectl get pods -n kubesphere-monitoring-system'
```

**验证各阶段安装状态：**

```bash
# 1. 检查核心组件（约 5-10 分钟后）
kubectl get pods -n kubesphere-system
# 应该看到多个 Pod 逐渐变为 Running 状态

# 2. 检查监控组件（约 10-15 分钟后）
kubectl get pods -n kubesphere-monitoring-system
# 应该看到 prometheus, node-exporter 等 Pod

# 3. 检查控制台组件（约 15-20 分钟后）
kubectl get svc -n kubesphere-system ks-console
# 应该看到 NodePort 服务

# 4. 检查所有 KubeSphere 相关的命名空间
kubectl get ns | grep kubesphere
# 应该至少看到：
# kubesphere-system
# kubesphere-monitoring-system
# kubesphere-controls-system
```

**安装成功的标志：**

当看到以下输出时，表示安装成功：

```
**************************************************
#####################################################
###              Welcome to KubeSphere!           ###
#####################################################

Console: http://172.16.0.10:30880
Account: admin
Password: P@88w0rd

NOTES：
  1. After you log into the console, please check the
     monitoring status of service components in
     "Cluster Management". If any service is not
     ready, please wait patiently until all components
     are up and running.
  2. Please change the default password after login.

#####################################################
https://kubesphere.io             2025-10-24 xx:xx:xx
#####################################################
```

**记录以下信息：**
- 控制台地址：`http://<节点IP>:30880`
- 默认用户名：`admin`
- 默认密码：`P@88w0rd`

**最终验证安装成功：**

```bash
# 1. 检查所有 KubeSphere Pod 是否都在运行
kubectl get pods -A | grep kubesphere | grep -v Running | grep -v Completed
# 如果没有输出，说明所有 Pod 都正常

# 2. 检查核心服务是否就绪
kubectl get deployment -n kubesphere-system
# 所有 READY 列应该显示类似 1/1, 2/2

# 3. 验证 API 服务是否可访问
kubectl get svc -n kubesphere-system ks-apiserver
# 应该显示 ClusterIP 服务

# 4. 验证控制台服务端口
CONSOLE_PORT=$(kubectl get svc -n kubesphere-system ks-console -o jsonpath='{.spec.ports[0].nodePort}')
echo "KubeSphere 控制台端口: $CONSOLE_PORT"
echo "访问地址: http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):$CONSOLE_PORT"

# 5. 测试端口是否可访问（在 master 节点执行）
curl -I http://localhost:$CONSOLE_PORT 2>/dev/null | head -n 1
# 预期输出：HTTP/1.1 200 OK 或其他 2xx/3xx 响应

echo "KubeSphere 安装完成！可以通过浏览器访问控制台了"
```

**如果安装失败或卡住：**
- 查看 [4.5 查看安装进度](#45-查看安装进度) 的详细日志
- 参考 [第 7 章 常见问题处理](#7-常见问题处理)
- 检查镜像是否成功拉取（参见 [7.2 镜像拉取失败](#72-镜像拉取失败imagepullbackoff)）
- 确认存储类是否正常工作（参见 [2.3 检查存储类](#23-检查存储类storageclass)）

---

## 5. 访问 KubeSphere 控制台

### 5.1 获取访问地址

```bash
# 查看 KubeSphere 控制台服务
kubectl get svc -n kubesphere-system ks-console

# 获取 NodePort
kubectl get svc -n kubesphere-system ks-console -o jsonpath='{.spec.ports[0].nodePort}'
```

### 5.2 访问方式

**方法 1：通过 NodePort 访问（推荐）**

可以通过任意节点 IP + NodePort 访问：
- `http://172.16.0.10:30880`（master 节点）
- `http://172.16.1.10:30880`（worker01 节点）
- `http://172.16.1.11:30880`（worker02 节点）

**方法 2：通过负载均衡器访问**

如果配置了负载均衡器，可以通过负载均衡器 IP 访问：
- `http://172.16.3.1:30880`

需要在负载均衡器上配置转发规则，将 30880 端口转发到后端节点。

**Nginx 负载均衡配置示例（在 k8s-Load-Balancer-gz 上）：**

```bash
# 安装 Nginx
dnf install -y nginx

# 配置 Nginx
cat > /etc/nginx/conf.d/kubesphere.conf <<'EOF'
upstream kubesphere_backend {
    server 172.16.0.10:30880 max_fails=3 fail_timeout=30s;
    server 172.16.1.10:30880 max_fails=3 fail_timeout=30s;
    server 172.16.1.11:30880 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name kubesphere.example.com;  # 修改为你的域名
    
    location / {
        proxy_pass http://kubesphere_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket 支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# 测试配置
nginx -t

# 启动 Nginx
systemctl enable nginx --now
systemctl status nginx
```

### 5.3 首次登录

1. 打开浏览器，访问 `http://<节点IP>:30880`
2. 输入默认账号密码：
   - 用户名：`admin`
   - 密码：`P@88w0rd`
3. **首次登录后，系统会强制要求修改密码**
4. 修改密码后，即可进入 KubeSphere 控制台

**验证登录成功：**

登录成功后，您应该能看到：
- KubeSphere 欢迎页面或控制台首页
- 左侧导航菜单
- 集群概览信息
- 资源使用情况统计

**如果无法访问，排查步骤：**

```bash
# 1. 确认 ks-console Pod 正常运行
kubectl get pods -n kubesphere-system | grep ks-console

# 2. 检查 ks-console 服务
kubectl get svc -n kubesphere-system ks-console

# 3. 从服务器内部测试端口
curl -I http://localhost:30880

# 4. 检查防火墙
firewall-cmd --list-ports | grep 30880
# 如果没有输出，添加端口：
# firewall-cmd --zone=public --add-port=30880/tcp --permanent
# firewall-cmd --reload

# 5. 检查节点安全组（云服务器）
# 确保入站规则允许 30880 端口
```

### 5.4 验证安装

登录后，检查以下内容：

1. **平台管理** → **集群管理** → **应用负载** → **工作负载**
   - 查看各个命名空间下的工作负载状态

2. **平台管理** → **集群管理** → **系统组件**
   - 确认所有系统组件状态正常

3. **平台管理** → **集群管理** → **节点管理**
   - 查看所有节点状态

```bash
# 命令行全面验证
echo "=== 1. 检查所有 KubeSphere 相关的 Pod ==="
kubectl get pods -A | grep kubesphere | grep -v Running | grep -v Completed
# 如果没有输出，说明所有 Pod 都正常

echo -e "\n=== 2. 检查核心系统组件 ==="
kubectl get pods -n kubesphere-system
# 所有 Pod 应该是 Running 状态

echo -e "\n=== 3. 检查监控组件 ==="
kubectl get pods -n kubesphere-monitoring-system
# prometheus, node-exporter, kube-state-metrics 应该都在运行

echo -e "\n=== 4. 检查控制系统组件 ==="
kubectl get pods -n kubesphere-controls-system

echo -e "\n=== 5. 检查所有 KubeSphere 服务 ==="
kubectl get svc -n kubesphere-system

echo -e "\n=== 6. 检查集群配置状态 ==="
kubectl get cc -n kubesphere-system ks-installer -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# 预期输出：True

echo -e "\n=== 7. 统计 KubeSphere 资源使用情况 ==="
echo "命名空间数量: $(kubectl get ns | grep kubesphere | wc -l)"
echo "Pod 总数: $(kubectl get pods -A | grep kubesphere | wc -l)"
echo "Running Pod 数: $(kubectl get pods -A | grep kubesphere | grep Running | wc -l)"
echo "Service 数量: $(kubectl get svc -A | grep kubesphere | wc -l)"

echo -e "\n安装验证完成！"
```

**验证检查清单：**

- [ ] 所有 Pod 状态为 Running 或 Completed
- [ ] ks-console 服务可以通过浏览器访问
- [ ] 可以使用 admin 账号成功登录
- [ ] 控制台能够显示集群信息
- [ ] 系统组件页面显示所有组件健康

**下一步操作：**
- 安装成功 → [启用可插拔组件](#6-启用可插拔组件可选)
- ❌ 遇到问题 → [常见问题处理](#7-常见问题处理)
-  了解更多 → [常用操作和最佳实践](#10-常用操作和最佳实践)

---

## 6. 启用可插拔组件（可选）

KubeSphere 采用可插拔架构，可以按需启用以下组件。

### 6.1 查看可用组件

```bash
# 查看当前集群配置
kubectl get cc -n kubesphere-system ks-installer -o yaml
```

### 6.2 常用组件说明

| 组件 | 说明 | 最小资源要求 |
|-----|------|------------|
| **metrics_server** | Kubernetes 指标服务器，提供资源使用情况 | 建议启用 |
| **monitoring** | 监控系统（Prometheus），提供集群、节点、Pod 监控 | CPU: 1核, 内存: 2Gi |
| **logging** | 日志系统（Elasticsearch），集中式日志收集和查询 | CPU: 2核, 内存: 4Gi, 存储: 20Gi |
| **events** | 事件系统，记录和查询 Kubernetes 事件 | CPU: 0.2核, 内存: 256Mi |
| **auditing** | 审计系统，记录用户操作审计日志 | CPU: 0.2核, 内存: 256Mi |
| **alerting** | 告警系统，支持多种告警通知渠道 | CPU: 0.2核, 内存: 256Mi |
| **devops** | DevOps 系统（Jenkins），提供 CI/CD 功能 | CPU: 2核, 内存: 4Gi, 存储: 10Gi |
| **servicemesh** | 服务网格（Istio），微服务治理 | CPU: 2核, 内存: 4Gi |
| **openpitrix** | 应用商店，应用生命周期管理 | CPU: 0.5核, 内存: 512Mi |

### 6.3 启用组件

**方法 1：通过 Web 控制台启用（推荐）**

1. 登录 KubeSphere 控制台
2. 进入 **平台管理** → **集群管理** → **定制资源定义 CRD**
3. 搜索 `ClusterConfiguration`，点击进入
4. 点击右侧的 `ks-installer`
5. 点击 **编辑 YAML**
6. 找到对应组件，将 `enabled: false` 改为 `enabled: true`
7. 点击 **确定** 保存

**方法 2：通过命令行启用**

```bash
# 编辑集群配置
kubectl edit cc ks-installer -n kubesphere-system
```

找到要启用的组件，修改配置：

**示例 1：启用监控、日志、告警**

```yaml
spec:
  monitoring:
    storageClass: ""
    node_exporter:
      port: 9100
    prometheusMemoryRequest: 400Mi
    prometheusVolumeSize: 20Gi
  logging:
    enabled: true
    logsidecar:
      enabled: true
      replicas: 2
      resources: {}
  alerting:
    enabled: true
  events:
    enabled: true
  auditing:
    enabled: true
```

**示例 2：启用 DevOps（Jenkins）**

```yaml
spec:
  devops:
    enabled: true
    jenkinsCpuReq: 0.5
    jenkinsCpuLim: 1
    jenkinsMemoryReq: 4Gi
    jenkinsMemoryLim: 4Gi
    jenkinsVolumeSize: 10Gi
```

**示例 3：启用服务网格（Istio）**

```yaml
spec:
  servicemesh:
    enabled: true
    istio:
      components:
        ingressGateways:
        - name: istio-ingressgateway
          enabled: true
        cni:
          enabled: false
```

**示例 4：启用应用商店**

```yaml
spec:
  openpitrix:
    store:
      enabled: true
```

### 6.4 查看组件安装进度

```bash
# 查看安装日志
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l 'app in (ks-install, ks-installer)' -o jsonpath='{.items[0].metadata.name}') -f

# 查看新增 Pod
kubectl get pods -A | grep kubesphere

# 查看特定命名空间
kubectl get pods -n kubesphere-logging-system     # 日志系统
kubectl get pods -n kubesphere-devops-system      # DevOps 系统
kubectl get pods -n istio-system                  # 服务网格
```

**组件安装进度验证：**

```bash
# 实时监控组件安装状态
watch -n 10 'kubectl get pods -A | grep -E "kubesphere-logging|kubesphere-devops|istio-system"'

# 检查特定组件是否启用成功
echo "=== 检查组件启用状态 ==="
kubectl get cc ks-installer -n kubesphere-system -o jsonpath='{.status.conditions[*].type}' | tr ' ' '\n'

# 检查已启用的组件列表
kubectl get cc ks-installer -n kubesphere-system -o yaml | grep "enabled: true" -B 1
```

### 6.5 验证组件状态

在 KubeSphere 控制台：
1. **平台管理** → **集群管理** → **系统组件**
2. 查看新启用的组件状态是否为 **健康**

**命令行验证各组件：**

```bash
# 验证日志组件（如果启用）
if kubectl get ns kubesphere-logging-system &>/dev/null; then
  echo "=== 日志组件验证 ==="
  kubectl get pods -n kubesphere-logging-system
  kubectl get svc -n kubesphere-logging-system
  echo "Elasticsearch 状态: $(kubectl get pods -n kubesphere-logging-system | grep elasticsearch | awk '{print $3}')"
fi

# 验证 DevOps 组件（如果启用）
if kubectl get ns kubesphere-devops-system &>/dev/null; then
  echo -e "\n=== DevOps 组件验证 ==="
  kubectl get pods -n kubesphere-devops-system
  echo "Jenkins 状态: $(kubectl get pods -n kubesphere-devops-system | grep jenkins | awk '{print $3}')"
fi

# 验证服务网格组件（如果启用）
if kubectl get ns istio-system &>/dev/null; then
  echo -e "\n=== 服务网格组件验证 ==="
  kubectl get pods -n istio-system
  echo "Istio 控制平面状态: $(kubectl get pods -n istio-system | grep istiod | awk '{print $3}')"
fi

# 验证应用商店（如果启用）
echo -e "\n=== 应用商店验证 ==="
kubectl get cc ks-installer -n kubesphere-system -o jsonpath='{.spec.openpitrix.store.enabled}'
# 输出 true 表示已启用

# 总体组件健康检查
echo -e "\n=== 组件健康状态总览 ==="
kubectl get cc ks-installer -n kubesphere-system -o jsonpath='{.status.conditions[*].type}' | tr ' ' '\n' | while read comp; do
  status=$(kubectl get cc ks-installer -n kubesphere-system -o jsonpath="{.status.conditions[?(@.type=='$comp')].status}")
  echo "$comp: $status"
done

echo -e "\n组件验证完成"
```

**验证清单（根据启用的组件）：**

- [ ] 组件相关的 Pod 都在 Running 状态
- [ ] 组件服务可以正常访问
- [ ] Web 控制台能够显示组件功能
- [ ] 组件日志无明显错误

**相关链接：**
- 🔙 返回 [安装验证](#54-验证安装)
- 查看 [常用操作和最佳实践](#10-常用操作和最佳实践)
- ⚙️ 了解 [高级配置](#9-高级配置)

---

## 7. 常见问题处理

**本章内容导航：**
- [7.1 ks-installer Pod CrashLoopBackOff 或 ClusterConfiguration CRD not found](#71-ks-installer-pod-crashloopbackoff-或-clusterconfiguration-crd-not-found)（⭐ 最常见问题）
- [7.2 Pod 一直处于 Pending 状态](#72-pod-一直处于-pending-状态)
- [7.3 镜像拉取失败（ImagePullBackOff）](#73-镜像拉取失败imagepullbackoff)
- [7.4 安装过程卡住](#74-安装过程卡住)
- [7.5 控制台无法访问](#75-控制台无法访问)
- [7.6 忘记 admin 密码](#76-忘记-admin-密码)
- [7.7 组件启用失败](#77-组件启用失败)
- [7.8 监控数据不显示](#78-监控数据不显示)
- [7.9 日志组件安装失败（Elasticsearch）](#79-日志组件安装失败elasticsearch)
- [7.10 DevOps 组件安装失败（Jenkins）](#710-devops-组件安装失败jenkins)

---

### 7.1 ks-installer Pod CrashLoopBackOff 或 ClusterConfiguration CRD not found

**现象：**
- `ks-installer` Pod 一直处于 `CrashLoopBackOff` 或 `Error` 状态
- 应用 `cluster-configuration.yaml` 时提示：`error: resource mapping not found for name: "ks-installer" namespace: "kubesphere-system" from "cluster-configuration.yaml": no matches for kind "ClusterConfiguration" in version "installer.kubesphere.io/v1alpha1" ensure CRDs are installed first`
- Pod 日志显示：`ERROR : error getting GVR for kind 'ClusterConfiguration': kind ClusterConfiguration is not supported`，然后 `TASK_RUN Exit: program halts`

**根本原因：**
- **`kubesphere-installer.yaml` 文件缺少 `ClusterConfiguration` CRD 定义**
- installer Pod 启动后立即查找这个 CRD，找不到就退出，导致 CRD 永远无法注册
- 这是一个"鸡生蛋、蛋生鸡"的问题：installer 需要 CRD 才能运行，但 CRD 应该由 installer 文件提供

**解决方法 1：使用包含 CRD 的完整 installer 文件（推荐）**

```bash
# 步骤 1：清理现有资源
kubectl delete -f cluster-configuration.yaml 2>/dev/null || true
kubectl delete -f kubesphere-installer.yaml 2>/dev/null || true
kubectl delete namespace kubesphere-system 2>/dev/null || true

# 等待资源完全删除
echo "等待资源清理..."
sleep 15

# 步骤 2：备份旧文件
cd ~/kubesphere
mv kubesphere-installer.yaml kubesphere-installer.yaml.old 2>/dev/null || true

# 步骤 3：创建包含 CRD 的完整 installer 文件
# 使用本教程附录 13.1 提供的完整 YAML 内容
# 复制附录 13.1 的完整内容到 kubesphere-installer.yaml

# 或使用以下命令快速创建（需要复制附录内容）
cat > kubesphere-installer.yaml <<'EOF'
# 这里粘贴附录 13.1 的完整 YAML 内容（包含 CRD 定义）
EOF

# 步骤 4：验证新文件包含 CRD 定义
grep -i "CustomResourceDefinition" kubesphere-installer.yaml
# 应该看到输出，表示文件包含 CRD

# 步骤 5：同时应用两个文件
kubectl apply -f kubesphere-installer.yaml
kubectl apply -f cluster-configuration.yaml

# 步骤 6：等待 Pod 启动
sleep 10
kubectl wait --for=condition=Ready pod -l app=ks-installer -n kubesphere-system --timeout=180s

# 步骤 7：验证安装启动
kubectl get crd clusterconfigurations.installer.kubesphere.io
kubectl get cc -n kubesphere-system ks-installer
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}') --tail=20

echo "✓ KubeSphere 安装已启动"
```

**解决方法 2：手动创建 CRD（快速临时方案）**

如果您不想重新创建 installer 文件，可以先手动创建 CRD：

```bash
# 创建 CRD
cat <<EOF | kubectl apply -f -
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: clusterconfigurations.installer.kubesphere.io
spec:
  group: installer.kubesphere.io
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            x-kubernetes-preserve-unknown-fields: true
          status:
            type: object
            x-kubernetes-preserve-unknown-fields: true
    subresources:
      status: {}
  scope: Namespaced
  names:
    plural: clusterconfigurations
    singular: clusterconfiguration
    kind: ClusterConfiguration
    shortNames:
    - cc
EOF

# 验证 CRD 创建成功
kubectl get crd clusterconfigurations.installer.kubesphere.io

# 然后按照正常流程安装
kubectl apply -f kubesphere-installer.yaml
kubectl apply -f cluster-configuration.yaml
```

**预防措施：**
- **始终使用本教程附录 13.1 提供的完整 installer YAML 文件**
- 确保 installer 文件包含 CRD 定义（文件开头应该有 `CustomResourceDefinition`）
- 同时应用 installer 和 configuration 两个文件
- 不要使用从 GitHub 直接下载的文件（可能不完整或版本不匹配）

**相关链接：**
- [完整的 installer YAML（附录 13.1）](#131-完整的-kubesphere-installer-yaml)
- 📖 [正确的安装步骤（4.4 节）](#44-执行安装)

### 7.2 Pod 一直处于 Pending 状态

**原因：**
- 没有配置 StorageClass
- 资源不足

**解决方法：**

```bash
# 查看 Pod 详情
kubectl describe pod <pod-name> -n kubesphere-system

# 查看 PVC 状态
kubectl get pvc -A

# 如果是存储问题，配置 StorageClass（参见 [2.3 检查存储类](#23-检查存储类storageclass)）
# 如果是资源问题，扩容节点或调整资源限制（参见 [2.2 检查系统资源](#22-检查系统资源)）
```

### 7.3 镜像拉取失败（ImagePullBackOff）

**原因：**
- 网络问题无法访问国外镜像仓库
- 镜像地址配置错误

**解决方法：**

```bash
# 查看 Pod 详情，确认镜像地址
kubectl describe pod <pod-name> -n kubesphere-system

# 手动在所有节点拉取镜像
docker pull registry.cn-beijing.aliyuncs.com/kubesphereio/<image-name>:<tag>

# 或使用阿里云镜像加速
# 在所有节点配置 Docker 镜像加速
# 参考同目录下的"使用阿里源安装docker.md"文档
```

### 7.4 安装过程卡住

**解决方法：**

```bash
# 查看安装日志
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l 'app in (ks-install, ks-installer)' -o jsonpath='{.items[0].metadata.name}') -f

# 查看 ks-installer Pod 状态
kubectl get pods -n kubesphere-system

# 如果 Pod 异常，查看详情
kubectl describe pod -n kubesphere-system $(kubectl get pod -n kubesphere-system -l 'app in (ks-install, ks-installer)' -o jsonpath='{.items[0].metadata.name}')

# 重启 ks-installer
kubectl rollout restart deployment ks-installer -n kubesphere-system
```

### 7.5 控制台无法访问

**解决方法：**

```bash
# 检查 ks-console 服务
kubectl get svc -n kubesphere-system ks-console

# 检查 ks-console Pod
kubectl get pods -n kubesphere-system | grep ks-console

# 检查 Pod 日志
kubectl logs -n kubesphere-system <ks-console-pod-name>

# 检查防火墙规则
firewall-cmd --list-ports
firewall-cmd --zone=public --add-port=30880/tcp --permanent
firewall-cmd --reload

# 检查 NodePort 范围
kubectl get svc -n kubesphere-system ks-console -o yaml | grep nodePort
```

### 7.6 忘记 admin 密码

**解决方法：**

```bash
# 重置密码为 P@88w0rd（默认密码）
kubectl patch users admin -p '{"spec":{"password":"$2a$10$zgo.NF.3YkCnp1fo5cWYl.4d.TW7kcTQGqNF8ybHsXcTNRyYzR.Rm"}}' --type='merge'

# 或者使用以下命令重置
kubectl delete secret -n kubesphere-system kubesphere-secret-admin

# 然后重启 ks-apiserver
kubectl rollout restart deployment ks-apiserver -n kubesphere-system
```

### 7.7 组件启用失败

**解决方法：**

```bash
# 查看组件安装日志
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l 'app in (ks-install, ks-installer)' -o jsonpath='{.items[0].metadata.name}') -f

# 检查资源是否充足
kubectl top nodes
kubectl top pods -A

# 禁用组件，重新启用
kubectl edit cc ks-installer -n kubesphere-system
# 将对应组件改为 enabled: false，保存
# 等待卸载完成后，再改为 enabled: true
```

### 7.8 监控数据不显示

**解决方法：**

```bash
# 检查 Prometheus 状态
kubectl get pods -n kubesphere-monitoring-system

# 检查 metrics-server 状态
kubectl get pods -n kube-system | grep metrics-server

# 如果没有 metrics-server，安装它
# 方法1：直接从 GitHub 安装（推荐，海外用户）
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 方法2：下载后修改配置（国内用户推荐）
# 由于可能需要添加参数，建议先下载再应用
curl -L -o metrics-server-components.yaml \
  https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 编辑 metrics-server-components.yaml，在 Deployment 的 args 下添加：
# spec:
#   template:
#     spec:
#       containers:
#       - args:
#         - --kubelet-insecure-tls
#         - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname

vim metrics-server-components.yaml  # 添加上述参数

# 应用修改后的配置
kubectl apply -f metrics-server-components.yaml
```

### 7.9 日志组件安装失败（Elasticsearch）

Elasticsearch 对资源要求较高，如果节点资源不足可能导致安装失败。

**解决方法：**

```bash
# 检查日志组件 Pod
kubectl get pods -n kubesphere-logging-system

# 如果 Elasticsearch Pod 启动失败，调整资源限制
kubectl edit cc ks-installer -n kubesphere-system

# 修改日志组件配置
spec:
  logging:
    enabled: true
    logsidecar:
      enabled: true
      replicas: 2
    # 添加 Elasticsearch 配置
    elasticsearchMasterReplicas: 1  # 减少副本数
    elasticsearchDataReplicas: 1
    logMaxAge: 7
    elkPrefix: logstash
    # 如果使用外部 Elasticsearch
    externalElasticsearchHost: ""
    externalElasticsearchPort: ""
```

### 7.10 DevOps 组件安装失败（Jenkins）

**解决方法：**

```bash
# 检查 DevOps 组件
kubectl get pods -n kubesphere-devops-system

# 检查 Jenkins Pod 日志
kubectl logs -n kubesphere-devops-system <jenkins-pod-name>

# 调整 Jenkins 资源配置
kubectl edit cc ks-installer -n kubesphere-system

spec:
  devops:
    enabled: true
    jenkinsCpuReq: 0.5      # 最小 CPU 需求
    jenkinsCpuLim: 2        # CPU 限制
    jenkinsMemoryReq: 2Gi   # 最小内存需求
    jenkinsMemoryLim: 4Gi   # 内存限制
    jenkinsVolumeSize: 10Gi # 存储大小
```

---

## 8. 卸载 KubeSphere（可选）

如果需要完全卸载 KubeSphere：

### 8.1 删除 KubeSphere 资源

```bash
# 方法1：直接下载卸载脚本（推荐）
curl -L -o kubesphere-delete.sh \
  https://raw.githubusercontent.com/kubesphere/ks-installer/master/scripts/kubesphere-delete.sh

# 或使用 wget
wget https://raw.githubusercontent.com/kubesphere/ks-installer/master/scripts/kubesphere-delete.sh

# 添加执行权限
chmod +x kubesphere-delete.sh

# 执行卸载
./kubesphere-delete.sh

# 方法2：如果无法下载，可以手动删除资源（参见下方 8.2 节）
```

### 8.2 手动清理残留资源

```bash
# 删除 KubeSphere 命名空间
kubectl delete ns kubesphere-system
kubectl delete ns kubesphere-monitoring-system
kubectl delete ns kubesphere-logging-system
kubectl delete ns kubesphere-devops-system
kubectl delete ns kubesphere-controls-system

# 删除 ClusterRoles 和 ClusterRoleBindings
kubectl delete clusterroles $(kubectl get clusterroles | grep kubesphere | awk '{print $1}')
kubectl delete clusterrolebindings $(kubectl get clusterrolebindings | grep kubesphere | awk '{print $1}')

# 删除 CRDs
kubectl delete crd $(kubectl get crd | grep kubesphere | awk '{print $1}')

# 删除 PVC（注意：会删除数据）
kubectl delete pvc -n kubesphere-system --all
kubectl delete pvc -n kubesphere-monitoring-system --all
kubectl delete pvc -n kubesphere-logging-system --all
```

---

## 9. 高级配置

### 9.1 配置持久化存储大小

编辑 `cluster-configuration.yaml`，根据实际需求调整存储大小：

```yaml
spec:
  common:
    redis:
      volumeSize: 2Gi      # Redis 存储
    openldap:
      volumeSize: 2Gi      # OpenLDAP 存储
    minio:
      volumeSize: 20Gi     # MinIO 存储（日志、镜像等）
  monitoring:
    prometheus:
      volumeSize: 20Gi     # Prometheus 监控数据存储
  logging:
    elasticsearchDataVolumeSize: 20Gi   # Elasticsearch 日志存储
```

### 9.2 配置邮件服务器（用于告警通知）

登录 KubeSphere 控制台后：
1. **平台管理** → **平台设置** → **通知配置** → **邮件服务器**
2. 配置 SMTP 服务器信息

或通过命令行配置：

```bash
kubectl -n kubesphere-system create secret generic kube-smtp-secret \
  --from-literal=username=<smtp-username> \
  --from-literal=password=<smtp-password>

kubectl edit cm -n kubesphere-system kubesphere-config
```

### 9.3 配置 LDAP/AD 认证

登录 KubeSphere 控制台后：
1. **平台管理** → **平台设置** → **认证配置**
2. 选择 **LDAP**，配置 LDAP 服务器信息

### 9.4 多集群管理

如果需要管理多个 Kubernetes 集群，配置 Host 集群和 Member 集群：

**Host 集群配置：**
```yaml
spec:
  multicluster:
    clusterRole: host
```

**Member 集群配置：**
```yaml
spec:
  multicluster:
    clusterRole: member
```

---

## 10. 常用操作和最佳实践

### 10.1 创建企业空间（Workspace）

企业空间是多租户隔离的基础：

1. 登录 KubeSphere 控制台
2. **访问控制** → **企业空间** → **创建**
3. 输入企业空间名称，如 `demo-workspace`
4. 分配管理员

### 10.2 创建项目（Project/Namespace）

1. 进入企业空间
2. **项目管理** → **创建**
3. 输入项目名称，如 `demo-project`
4. 配置资源配额（可选）

### 10.3 部署应用

**方式 1：通过应用商店部署**
1. **应用商店** → 选择应用 → **部署**

**方式 2：通过 YAML 部署**
1. **项目** → **应用负载** → **工作负载** → **创建**
2. 选择 **编辑 YAML** → 粘贴 YAML 内容

**方式 3：通过应用模板部署**
1. **应用管理** → **应用模板** → **创建**
2. 上传 Helm Chart

### 10.4 配置 CI/CD 流水线（需启用 DevOps）

1. **DevOps 项目** → **创建 DevOps 项目**
2. **流水线** → **创建流水线**
3. 编辑 Jenkinsfile 或使用图形化编辑器

### 10.5 监控和告警

1. **集群管理** → **监控告警** → **自定义监控**
2. **告警策略** → **创建告警策略**
3. 配置告警规则和通知渠道

### 10.6 日志查询

1. **工具箱** → **日志查询**
2. 输入查询条件（支持 Lucene 语法）

---

## 11. 性能优化建议

### 11.1 资源规划

- **测试环境：** 3 节点，每节点 4C8G
- **生产环境：** 至少 3 Master + 3 Worker，每节点 8C16G

### 11.2 存储优化

- 使用 SSD 存储提升性能
- 监控数据建议独立存储
- 日志数据建议使用对象存储或独立集群

### 11.3 网络优化

- 使用 Calico 或 Cilium 网络插件（性能优于 Flannel）
- 启用 NodeLocal DNSCache
- 配置 CoreDNS 缓存

### 11.4 监控数据保留策略

```yaml
spec:
  monitoring:
    prometheus:
      retention: 7d  # 监控数据保留 7 天
  logging:
    logMaxAge: 7     # 日志数据保留 7 天
```

---

## 12. 参考资料

### 12.1 官方文档

- **KubeSphere 官网**：[https://kubesphere.io](https://kubesphere.io)
- **KubeSphere 中文文档**：[https://kubesphere.io/zh/docs/](https://kubesphere.io/zh/docs/)
- **GitHub 仓库**：[https://github.com/kubesphere/kubesphere](https://github.com/kubesphere/kubesphere)

### 12.2 社区支持

- **官方论坛**：[https://kubesphere.io/forum/](https://kubesphere.io/forum/)
- **Slack 频道**：[https://kubesphere.slack.com/](https://kubesphere.slack.com/)
- **微信公众号**：KubeSphere
- **GitHub Issues**：[提交问题](https://github.com/kubesphere/kubesphere/issues)

### 12.3 相关教程

- **Kubernetes 官方文档**：[https://kubernetes.io/zh/docs/](https://kubernetes.io/zh/docs/)
- **Helm 官方文档**：[https://helm.sh/zh/docs/](https://helm.sh/zh/docs/)
- **Prometheus 官方文档**：[https://prometheus.io/docs/](https://prometheus.io/docs/)
- **Docker 官方文档**：[https://docs.docker.com/](https://docs.docker.com/)

---

## 13. 附录

### 13.1 完整的 KubeSphere Installer YAML

**💡 使用说明：**
- 以下 YAML 内容可直接复制使用，无需从 GitHub 下载
- 提供国内和海外两种镜像版本
- **已包含 ClusterConfiguration CRD 定义（重要！）**
- 适用于在现有 Kubernetes 集群上安装 KubeSphere v3.4.1

**使用方法：**

```bash
# 方法1：复制对应环境的完整内容，创建文件（推荐）
cd ~/kubesphere
cat > kubesphere-installer.yaml <<'EOF'
# 这里粘贴下面对应环境的完整 YAML 内容
EOF

# 方法2：在编辑器中直接复制下面的内容
# 将内容保存为 kubesphere-installer.yaml 文件

# 方法3：使用 vim/nano 编辑器
vim kubesphere-installer.yaml
# 然后粘贴下面对应环境的 YAML 内容
```

**💡 快速跳转：**
- 返回 [4.1 创建 Installer 文件](#41-创建-kubesphere-installer-部署文件)
- 继续 [4.2 创建配置文件](#42-修改集群配置文件)

---

#### 方案A：国内环境 Installer YAML（使用阿里云镜像）

```yaml
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: clusterconfigurations.installer.kubesphere.io
spec:
  group: installer.kubesphere.io
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            x-kubernetes-preserve-unknown-fields: true
          status:
            type: object
            x-kubernetes-preserve-unknown-fields: true
    subresources:
      status: {}
  scope: Namespaced
  names:
    plural: clusterconfigurations
    singular: clusterconfiguration
    kind: ClusterConfiguration
    shortNames:
    - cc
---
apiVersion: v1
kind: Namespace
metadata:
  name: kubesphere-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ks-installer
  namespace: kubesphere-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ks-installer
rules:
- apiGroups:
  - ""
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - apps
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - extensions
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - batch
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - rbac.authorization.k8s.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - apiregistration.k8s.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - apiextensions.k8s.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - tenant.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - certificates.k8s.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - devops.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - monitoring.coreos.com
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - logging.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - jaegertracing.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - storage.k8s.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - admissionregistration.k8s.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - policy
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - autoscaling
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - networking.istio.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - config.istio.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - iam.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - notification.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - auditing.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - events.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - core.kubefed.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - installer.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - storage.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - security.istio.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - monitoring.kiali.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - kiali.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - networking.k8s.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - edgeruntime.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - types.kubefed.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - monitoring.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - application.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - policy.kubeedge.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - cluster.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ks-installer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ks-installer
subjects:
- kind: ServiceAccount
  name: ks-installer
  namespace: kubesphere-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ks-installer
  namespace: kubesphere-system
  labels:
    app: ks-installer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ks-installer
  template:
    metadata:
      labels:
        app: ks-installer
    spec:
      serviceAccountName: ks-installer
      containers:
      - name: installer
        image: registry.cn-beijing.aliyuncs.com/kubesphereio/ks-installer:v3.4.1
        # 国内环境：使用 KubeSphere 官方维护的阿里云镜像仓库
        imagePullPolicy: Always
        resources:
          limits:
            cpu: "1"
            memory: 1Gi
          requests:
            cpu: 20m
            memory: 100Mi
        volumeMounts:
        - mountPath: /etc/localtime
          name: host-time
          readOnly: true
      volumes:
      - hostPath:
          path: /etc/localtime
          type: ""
        name: host-time
```

---

#### 方案B：海外环境 Installer YAML（使用官方镜像）

```yaml
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: clusterconfigurations.installer.kubesphere.io
spec:
  group: installer.kubesphere.io
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            x-kubernetes-preserve-unknown-fields: true
          status:
            type: object
            x-kubernetes-preserve-unknown-fields: true
    subresources:
      status: {}
  scope: Namespaced
  names:
    plural: clusterconfigurations
    singular: clusterconfiguration
    kind: ClusterConfiguration
    shortNames:
    - cc
---
apiVersion: v1
kind: Namespace
metadata:
  name: kubesphere-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ks-installer
  namespace: kubesphere-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ks-installer
rules:
- apiGroups:
  - ""
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - apps
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - extensions
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - batch
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - rbac.authorization.k8s.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - apiregistration.k8s.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - apiextensions.k8s.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - tenant.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - certificates.k8s.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - devops.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - monitoring.coreos.com
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - logging.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - jaegertracing.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - storage.k8s.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - admissionregistration.k8s.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - policy
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - autoscaling
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - networking.istio.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - config.istio.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - iam.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - notification.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - auditing.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - events.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - core.kubefed.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - installer.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - storage.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - security.istio.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - monitoring.kiali.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - kiali.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - networking.k8s.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - edgeruntime.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - types.kubefed.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - monitoring.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - application.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - policy.kubeedge.io
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - cluster.kubesphere.io
  resources:
  - '*'
  verbs:
  - '*'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ks-installer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ks-installer
subjects:
- kind: ServiceAccount
  name: ks-installer
  namespace: kubesphere-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ks-installer
  namespace: kubesphere-system
  labels:
    app: ks-installer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ks-installer
  template:
    metadata:
      labels:
        app: ks-installer
    spec:
      serviceAccountName: ks-installer
      containers:
      - name: installer
        image: kubesphere/ks-installer:v3.4.1
        # 海外环境：使用 Docker Hub 官方镜像仓库
        imagePullPolicy: Always
        resources:
          limits:
            cpu: "1"
            memory: 1Gi
          requests:
            cpu: 20m
            memory: 100Mi
        volumeMounts:
        - mountPath: /etc/localtime
          name: host-time
          readOnly: true
      volumes:
      - hostPath:
          path: /etc/localtime
          type: ""
        name: host-time
```

---

**说明**：
- **国内环境（方案A）**：镜像地址为 `registry.cn-beijing.aliyuncs.com/kubesphereio/ks-installer:v3.4.1`
- **海外环境（方案B）**：镜像地址为 `kubesphere/ks-installer:v3.4.1`（Docker Hub官方）
- 两种配置除镜像地址外完全相同，CRD定义和权限配置完全一致

### 13.2 常用命令速查

```bash
# 查看 KubeSphere 版本
kubectl get deploy ks-installer -n kubesphere-system -o jsonpath='{.spec.template.spec.containers[0].image}'

# 查看安装日志
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l 'app in (ks-install, ks-installer)' -o jsonpath='{.items[0].metadata.name}') -f

# 查看集群配置
kubectl get cc -n kubesphere-system ks-installer -o yaml

# 编辑集群配置
kubectl edit cc ks-installer -n kubesphere-system

# 重启 ks-installer
kubectl rollout restart deployment ks-installer -n kubesphere-system

# 查看所有 KubeSphere 相关资源
kubectl get all -n kubesphere-system
kubectl get all -n kubesphere-monitoring-system
kubectl get all -n kubesphere-logging-system

# 查看 KubeSphere 控制台地址
kubectl get svc -n kubesphere-system ks-console

# 重置 admin 密码
kubectl patch users admin -p '{"spec":{"password":"$2a$10$zgo.NF.3YkCnp1fo5cWYl.4d.TW7kcTQGqNF8ybHsXcTNRyYzR.Rm"}}' --type='merge'
```

### 13.3 配置 etcd 监控（可选）

**为什么需要 etcd 监控？**

etcd 是 Kubernetes 集群的核心组件，存储了集群的所有状态数据。监控 etcd 可以帮助您：
- 及时发现性能问题（延迟、吞吐量）
- 监控存储容量使用情况
- 追踪数据库健康状态
- 预防集群故障

**⚠️ 重要提示：**
- **新手推荐**：先使用 `monitoring: false`（禁用 etcd 监控）完成安装
- **进阶用户**：安装成功后再启用 etcd 监控
- etcd 监控需要正确的证书配置，否则会导致监控组件安装失败

---

#### 步骤 1：获取 etcd 信息

在 **master 节点**执行以下命令：

```bash
# 1. 查看 etcd Pod
kubectl get pods -n kube-system | grep etcd
# 输出示例：
# etcd-k8s-master-gz   1/1     Running   0   1d

# 2. 获取 etcd 端点 IP（通常是 master 节点的 IP）
kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].status.hostIP}'
echo ""
# 输出示例：172.16.0.10

# 3. 查看 etcd 监听端口
kubectl get pods -n kube-system -l component=etcd -o jsonpath='{.items[0].spec.containers[0].command}' | grep -oP 'listen-client-urls=\K[^ ]*'
# 输出示例：https://172.16.0.10:2379,https://127.0.0.1:2379
```

#### 步骤 2：验证 etcd 证书路径

**对于 kubeadm 部署的集群（默认路径）：**

```bash
# 检查 etcd 证书文件是否存在
ls -la /etc/kubernetes/pki/etcd/

# 预期输出应包含以下文件：
# ca.crt                          # CA 证书
# ca.key                          # CA 私钥
# healthcheck-client.crt          # 健康检查客户端证书
# healthcheck-client.key          # 健康检查客户端私钥
# peer.crt                        # etcd 节点间通信证书
# peer.key                        # etcd 节点间通信私钥
# server.crt                      # etcd 服务器证书
# server.key                      # etcd 服务器私钥

# 测试使用这些证书连接 etcd
# 方法1：通过 kubectl exec 进入 etcd 容器执行（推荐，无需安装 etcdctl）
kubectl exec -n kube-system $(kubectl get pod -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}') -- \
  etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  endpoint health

# 方法2：在宿主机上安装 etcdctl 后执行
# dnf install -y etcd  # 安装 etcd 工具包
# ETCDCTL_API=3 etcdctl \
#   --endpoints=https://127.0.0.1:2379 \
#   --cacert=/etc/kubernetes/pki/etcd/ca.crt \
#   --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
#   --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
#   endpoint health

# 预期输出：
# https://127.0.0.1:2379 is healthy: successfully committed proposal: took = 2.345ms
```

#### 步骤 3：配置 ClusterConfiguration

**方法 1：通过 kubectl edit 修改（推荐）**

```bash
# 编辑集群配置
kubectl edit cc ks-installer -n kubesphere-system
```

找到 `etcd` 部分，修改为：

```yaml
etcd:
  monitoring: true  # 启用监控
  endpointIps: 172.16.0.10  # 改为您的 master 节点 IP
  port: 2379
  tlsEnable: true
  # 添加证书路径（kubeadm 默认路径）
  tlsCaFile: /etc/kubernetes/pki/etcd/ca.crt
  tlsCertFile: /etc/kubernetes/pki/etcd/healthcheck-client.crt
  tlsKeyFile: /etc/kubernetes/pki/etcd/healthcheck-client.key
```

**如果是多 master 节点（高可用集群）：**

```yaml
etcd:
  monitoring: true
  endpointIps: 172.16.0.10,172.16.0.11,172.16.0.12  # 多个节点用逗号分隔
  port: 2379
  tlsEnable: true
  tlsCaFile: /etc/kubernetes/pki/etcd/ca.crt
  tlsCertFile: /etc/kubernetes/pki/etcd/healthcheck-client.crt
  tlsKeyFile: /etc/kubernetes/pki/etcd/healthcheck-client.key
```

**方法 2：使用 kubectl patch 修改（快速方式）**

```bash
# 单 master 节点
kubectl patch cc ks-installer -n kubesphere-system --type merge -p '{
  "spec": {
    "etcd": {
      "monitoring": true,
      "endpointIps": "172.16.0.10",
      "port": 2379,
      "tlsEnable": true,
      "tlsCaFile": "/etc/kubernetes/pki/etcd/ca.crt",
      "tlsCertFile": "/etc/kubernetes/pki/etcd/healthcheck-client.crt",
      "tlsKeyFile": "/etc/kubernetes/pki/etcd/healthcheck-client.key"
    }
  }
}'

# 验证配置
kubectl get cc ks-installer -n kubesphere-system -o yaml | grep -A 8 "etcd:"
```

#### 步骤 4：重启 installer 应用更改

```bash
# 删除 ks-installer Pod，让它重新部署监控组件
kubectl delete pod -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}')

# 等待 Pod 重启
sleep 10

# 查看实时日志
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}') -f
```

#### 步骤 5：验证 etcd 监控

```bash
# 1. 等待监控组件部署完成（约 5-10 分钟）

# 2. 检查 etcd ServiceMonitor 是否创建
kubectl get servicemonitor -n kubesphere-monitoring-system | grep etcd

# 3. 检查 etcd endpoints 是否创建
kubectl get endpoints -n kubesphere-monitoring-system | grep etcd

# 4. 访问 Prometheus 查看 etcd 指标
# 打开浏览器访问：http://<节点IP>:30880
# 登录后进入"监控告警" -> "自定义监控"
# 查询 etcd 相关指标，例如：
# - etcd_server_has_leader （etcd 是否有 leader）
# - etcd_disk_wal_fsync_duration_seconds（磁盘同步延迟）
# - etcd_mvcc_db_total_size_in_bytes（数据库大小）
```

---

#### 故障排查

**问题 1：监控组件安装失败，日志显示 `'etcd' is undefined`**

**原因：** 没有配置 etcd 相关信息

**解决：** 按照上述步骤补全 etcd 配置，或者设置 `monitoring: false`

---

**问题 2：etcd endpoint 无法连接**

```bash
# 检查证书路径是否正确
kubectl describe servicemonitor -n kubesphere-monitoring-system etcd

# 检查 Prometheus 日志
kubectl logs -n kubesphere-monitoring-system prometheus-k8s-0 -c prometheus | grep etcd
```

**可能的原因和解决方案：**

1. **证书路径错误**
   ```bash
   # 重新确认证书路径
   kubectl get pod -n kube-system $(kubectl get pod -n kube-system -l component=etcd -o jsonpath='{.items[0].metadata.name}') -o yaml | grep -A 3 "ca-file"
   ```

2. **IP 地址错误**
   ```bash
   # 确认 etcd 实际监听的 IP
   kubectl get pod -n kube-system -l component=etcd -o jsonpath='{.items[0].spec.containers[0].command}' | grep advertise-client-urls
   ```

3. **端口不可达**
   ```bash
   # 在 master 节点测试端口连通性
   nc -zv 127.0.0.1 2379
   ```

---

**问题 3：使用外部 etcd 集群（非 kubeadm 部署）**

如果您的 etcd 不是通过 kubeadm 部署的，证书路径可能不同：

```bash
# 查找 etcd 配置文件
find /etc -name "etcd.conf*" 2>/dev/null

# 或查看 etcd 进程参数
ps aux | grep etcd | grep -oP '\-\-(cert|key|ca)-file=[^ ]*'

# 根据实际路径修改 ClusterConfiguration
```

---

#### 完整配置示例

**示例 1：单 master 节点（kubeadm 部署）**

```yaml
etcd:
  monitoring: true
  endpointIps: 172.16.0.10
  port: 2379
  tlsEnable: true
  tlsCaFile: /etc/kubernetes/pki/etcd/ca.crt
  tlsCertFile: /etc/kubernetes/pki/etcd/healthcheck-client.crt
  tlsKeyFile: /etc/kubernetes/pki/etcd/healthcheck-client.key
```

**示例 2：多 master 节点高可用集群**

```yaml
etcd:
  monitoring: true
  endpointIps: 172.16.0.10,172.16.0.11,172.16.0.12
  port: 2379
  tlsEnable: true
  tlsCaFile: /etc/kubernetes/pki/etcd/ca.crt
  tlsCertFile: /etc/kubernetes/pki/etcd/healthcheck-client.crt
  tlsKeyFile: /etc/kubernetes/pki/etcd/healthcheck-client.key
```

**示例 3：禁用 TLS 的 etcd（不推荐生产环境）**

```yaml
etcd:
  monitoring: true
  endpointIps: 172.16.0.10
  port: 2379
  tlsEnable: false
```

---

#### 相关链接

- 返回 [集群配置文件说明](#42-修改集群配置文件)
- 查看 [监控组件故障排查](#78-监控数据不显示)
- 了解更多 [etcd 官方文档](https://etcd.io/docs/)

---

## 14. 故障排查流程图

```
安装失败？
├── Pod Pending
│   ├── 检查 StorageClass
│   └── 检查节点资源
├── ImagePullBackOff
│   ├── 检查镜像地址
│   ├── 配置镜像加速
│   └── 手动拉取镜像
├── CrashLoopBackOff
│   ├── 查看 Pod 日志
│   ├── 查看 Events
│   └── 检查配置文件
└── 安装卡住
    ├── 查看 ks-installer 日志
    ├── 检查网络连接
    └── 重启 ks-installer
```

---

**安装完成！**

现在您可以通过浏览器访问 KubeSphere 控制台，开始使用强大的容器平台管理功能了！

---

## 快速链接

### 常用章节
- [返回目录](#目录)
- [环境说明与方案选择](#环境说明与方案选择)
- [镜像源配置说明](#镜像源配置说明)
- [常用操作和最佳实践](#10-常用操作和最佳实践)
- [常见问题处理](#7-常见问题处理)
- [高级配置](#9-高级配置)

### 官方资源
- [KubeSphere 官方文档](https://kubesphere.io/zh/docs/)
- [官方论坛](https://kubesphere.io/forum/)
- [提交 Issue](https://github.com/kubesphere/kubesphere/issues)

---

如有问题，请参考 [官方文档](https://kubesphere.io/zh/docs/) 或 [社区支持](#122-社区支持)。

