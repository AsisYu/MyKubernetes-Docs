# 自用Kubernetes 集群部署文档目录

## 文档说明

本目录包含完整的Kubernetes集群部署文档、配置文件和脚本工具，涵盖从Docker安装到KubeSphere部署的全流程。

---

## 一、基础环境部署

### 1.1 容器运行时安装

**[使用阿里源安装docker.md](./使用阿里源安装docker.md)**

- 适用系统：CentOS/RHEL/Fedora（RPM系）
- 内容概要：
  - 方案1：安装最新稳定版（使用阿里源）
  - 方案2：安装指定版本（版本匹配说明）
  - 方案3：使用Docker官方源安装
  - 启动验证及常见问题解决

### 1.2 系统工具

**[screen替代方案tmux.md](./screen替代方案tmux.md)**

- 内容：tmux终端复用工具使用指南
- 用途：长时间运行任务、会话管理

---

## 二、Kubernetes集群部署

### 2.1 核心组件安装

**[详细使用阿里源安装kubeadm、kubelet、kubectl.md](./详细使用阿里源安装kubeadm、kubelet、kubectl.md)**

- 文档规模：3447行完整教程
- 适用场景：
  - 单Master集群（测试/学习环境）
  - 高可用集群（生产环境，多Master）
- 主要章节：
  - 第一步：所有节点的基础环境准备
  - 第二步：安装容器运行时（Containerd）
  - 第三步：安装kube组件（kubelet、kubeadm、kubectl）
  - 第四步：集群架构选择及初始化
    - 4A：单Master集群部署
    - 4B：高可用集群部署（含负载均衡器配置）
  - 第五步：Worker节点加入集群
  - 第六步：全面验证集群状态
  - 第七步：常见问题排查与解决
- 特色内容：
  - 网络拓扑决策（跨网段/同网段方案选择）
  - 负载均衡器详细配置（HAProxy/Nginx/Keepalived）
  - 完整的验证脚本
  - 详细的故障排查指南

### 2.2 网络插件配置

**[kube-flannel.yml](./kube-flannel.yml)**

- 类型：Flannel网络插件部署配置文件
- 用途：实现Kubernetes集群Pod网络互通
- 使用方法：`kubectl apply -f kube-flannel.yml`

**[components.yaml](./components.yaml)**

- 类型：Kubernetes组件配置文件
- 说明：可能包含Dashboard或其他核心组件配置

### 2.3 CNI插件

**[cni-plugins-linux-amd64-v1.2.0.tgz](./cni-plugins-linux-amd64-v1.2.0.tgz)**

- 类型：CNI（Container Network Interface）插件二进制包
- 版本：v1.2.0
- 用途：容器网络接口实现

---

## 三、KubeSphere平台部署

### 3.1 安装教程

**[详细安装KubeSphere教程.md](./详细安装KubeSphere教程.md)**

- 内容：KubeSphere容器平台完整安装指南
- 说明：基于已有Kubernetes集群部署KubeSphere

### 3.2 修复脚本

**[fix-kubesphere-install.sh](./fix-kubesphere-install.sh)**

- 类型：Shell脚本
- 用途：修复KubeSphere安装过程中的常见问题

**[fix-kubesphere-all.sh](./fix-kubesphere-all.sh)**

- 类型：Shell脚本
- 用途：KubeSphere全面修复工具

---

## 四、集群维护脚本

### 4.1 初始化修复

**[fix-k8s-init.sh](./fix-k8s-init.sh)**

- 类型：Shell脚本
- 用途：修复Kubernetes集群初始化问题
- 适用场景：集群初始化失败后的修复

---

## 五、部署流程推荐

### 5.1 测试/学习环境（单Master）

```
1. 使用阿里源安装docker.md
   └─> 安装Docker或Containerd

2. 详细使用阿里源安装kubeadm、kubelet、kubectl.md
   ├─> 第一步：基础环境准备（所有节点）
   ├─> 第二步：安装Containerd（所有节点）
   ├─> 第三步：安装kube组件（所有节点）
   ├─> 第四步A：单Master集群部署
   ├─> 第五步：Worker节点加入
   └─> 第六步：验证集群状态

3. 详细安装KubeSphere教程.md（可选）
   └─> 部署KubeSphere管理平台
```

### 5.2 生产环境（高可用集群）

```
1. 使用阿里源安装docker.md
   └─> 安装Docker或Containerd

2. 详细使用阿里源安装kubeadm、kubelet、kubectl.md
   ├─> 第一步：基础环境准备（所有节点）
   ├─> 第二步：安装Containerd（所有节点）
   ├─> 第三步：安装kube组件（所有节点）
   ├─> 第四步B：高可用集群部署
   │   ├─> 4B.1：配置负载均衡器（优先）
   │   ├─> 4B.2：初始化第一个Master
   │   ├─> 4B.3：配置kubectl
   │   ├─> 4B.4：安装网络插件
   │   ├─> 4B.5：添加其他Master节点
   │   └─> 4B.6：验证高可用集群
   ├─> 第五步：Worker节点加入
   └─> 第六步：验证集群状态

3. 详细安装KubeSphere教程.md（可选）
   └─> 部署KubeSphere管理平台
```

---

## 六、关键注意事项

### 6.1 网络拓扑决策（重要）

在部署高可用集群前，必须明确网络拓扑：

- **跨网段环境**：必须使用独立负载均衡器服务器（方案A）
- **同一网段**：可选择独立LB（方案A）或Keepalived+HAProxy（方案B）
- **单Master测试**：不需要负载均衡器

详见：`详细使用阿里源安装kubeadm、kubelet、kubectl.md` 第19-33行

### 6.2 镜像源配置

所有部署均使用阿里云镜像源，解决国内访问问题：

- Docker镜像源：`https://mirrors.aliyun.com/docker-ce/`
- Kubernetes镜像：`registry.aliyuncs.com/google_containers`
- Containerd pause镜像：`registry.aliyuncs.com/google_containers/pause:3.9`

### 6.3 常见问题

部署过程中遇到问题，请参考：

- `详细使用阿里源安装kubeadm、kubelet、kubectl.md` 第七步（第2486-3150行）
- 包含：kubelet启动失败、镜像拉取失败、节点NotReady、Worker无法加入、负载均衡器问题等

---

## 七、文件清单

### 7.1 文档文件

| 文件名 | 大小 | 说明 |
|--------|------|------|
| 使用阿里源安装docker.md | 108行 | Docker安装教程 |
| 详细使用阿里源安装kubeadm、kubelet、kubectl.md | 3447行 | K8s集群完整部署教程 |
| 详细安装KubeSphere教程.md | - | KubeSphere安装指南 |
| screen替代方案tmux.md | - | tmux工具使用说明 |

### 7.2 配置文件

| 文件名 | 类型 | 用途 |
|--------|------|------|
| kube-flannel.yml | YAML | Flannel网络插件配置 |
| components.yaml | YAML | Kubernetes组件配置 |

### 7.3 脚本文件

| 文件名 | 类型 | 用途 |
|--------|------|------|
| fix-k8s-init.sh | Shell | K8s初始化修复 |
| fix-kubesphere-install.sh | Shell | KubeSphere安装修复 |
| fix-kubesphere-all.sh | Shell | KubeSphere全面修复 |

### 7.4 二进制文件

| 文件名 | 版本 | 说明 |
|--------|------|------|
| cni-plugins-linux-amd64-v1.2.0.tgz | v1.2.0 | CNI插件包 |

---

## 八、版本信息

- Kubernetes版本：v1.28.0
- Docker CE：支持多版本（推荐最新稳定版）
- Containerd：包含在Docker源中
- Flannel：v0.22.0
- CNI插件：v1.2.0

---

## 九、技术支持

### 9.1 文档更新日志

详见各文档顶部的更新说明，例如：

- `详细使用阿里源安装kubeadm、kubelet、kubectl.md` 顶部包含2025-10-23的重大更新说明

### 9.2 验证脚本

文档中提供了完整的验证脚本：

- 集群健康检查脚本（附录A.1）
- 节点环境检查脚本（附录A.2）

位置：`详细使用阿里源安装kubeadm、kubelet、kubectl.md` 第3153-3399行

---

## 十、快速开始

### 10.1 新手入门

如果您是第一次部署Kubernetes，建议按以下顺序阅读：

1. 先阅读 `使用阿里源安装docker.md` 了解容器运行时
2. 完整阅读 `详细使用阿里源安装kubeadm、kubelet、kubectl.md` 的前言和目录
3. 根据需求选择单Master（4A）或高可用（4B）部署路径
4. 严格按照文档步骤执行，不要跳过验证环节

### 10.2 高级用户

如果您已有Kubernetes部署经验：

1. 直接查看 `详细使用阿里源安装kubeadm、kubelet、kubectl.md` 的关键章节
2. 重点关注第19-33行的网络拓扑决策
3. 高可用部署务必先配置并验证负载均衡器（4B.1）
4. 遇到问题直接查看第七步故障排查

---

## 结语

本文档集合经过实际生产环境验证，包含详细的步骤说明和问题解决方案。部署过程中如遇到问题，请先查阅对应文档的故障排查章节。

最后更新：2025-11-03

