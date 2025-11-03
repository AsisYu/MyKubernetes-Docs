#!/bin/bash
# Kubernetes 初始化问题排查和修复脚本
# 适用于 CentOS 9 / Rocky Linux 9
# 解决 kubeadm init 失败、容器运行时问题、端口占用问题

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "请使用 root 用户运行此脚本"
        exit 1
    fi
}

# 检查端口占用情况
check_ports() {
    log_step "检查 Kubernetes 关键端口占用情况..."
    
    local ports=(6443 10259 10257 10250 2379 2380)
    local occupied=0
    
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":${port} " || ss -tuln 2>/dev/null | grep -q ":${port} "; then
            log_warn "端口 ${port} 被占用"
            occupied=1
        fi
    done
    
    if [ $occupied -eq 1 ]; then
        return 1
    else
        log_info "所有关键端口未被占用"
        return 0
    fi
}

# 强制清理所有 Kubernetes 进程
force_kill_k8s_processes() {
    log_step "强制停止所有 Kubernetes 相关进程..."
    
    local processes=("kube-apiserver" "kube-controller-manager" "kube-scheduler" "kubelet" "kube-proxy" "etcd")
    
    for process in "${processes[@]}"; do
        if pgrep -f "$process" > /dev/null; then
            log_warn "发现进程: $process，正在强制停止..."
            pkill -9 -f "$process" 2>/dev/null || true
        fi
    done
    
    sleep 3
    log_info "进程清理完成"
}

# 深度清理 Kubernetes 配置和数据
deep_cleanup() {
    log_step "执行深度清理..."
    
    # 停止服务
    log_info "停止相关服务..."
    systemctl stop kubelet 2>/dev/null || true
    systemctl stop containerd 2>/dev/null || true
    
    # 强制清理进程
    force_kill_k8s_processes
    
    # 清理容器和镜像
    log_info "清理容器..."
    crictl rm -f $(crictl ps -aq 2>/dev/null) 2>/dev/null || true
    crictl rmi --prune 2>/dev/null || true
    
    # 删除配置文件和数据目录
    log_info "删除配置文件和数据目录..."
    rm -rf /etc/kubernetes/
    rm -rf /var/lib/kubelet/
    rm -rf /var/lib/etcd/
    rm -rf /etc/cni/net.d/
    rm -rf /var/lib/cni/
    rm -rf /opt/cni/
    rm -rf $HOME/.kube/
    rm -rf /var/lib/dockershim/
    rm -rf /var/run/kubernetes/
    rm -rf /var/lib/cni/
    rm -rf /var/lib/calico/
    
    # 清理网络规则
    log_info "清理 iptables 规则..."
    iptables -F 2>/dev/null || true
    iptables -t nat -F 2>/dev/null || true
    iptables -t mangle -F 2>/dev/null || true
    iptables -X 2>/dev/null || true
    
    # 清理 IPVS
    if command -v ipvsadm &> /dev/null; then
        log_info "清理 IPVS 规则..."
        ipvsadm --clear 2>/dev/null || true
    fi
    
    # 重启服务
    log_info "重启 containerd 服务..."
    systemctl start containerd
    sleep 2
    
    log_info "深度清理完成"
}

# 步骤 1: 关闭 swap
disable_swap() {
    log_step "=== 步骤 1: 关闭 swap ==="
    swapoff -a
    sed -i '/swap/s/^/#/' /etc/fstab
    log_info "swap 已关闭并设置开机不启用"
    free -h
    echo ""
}

# 步骤 2: 加载必要的内核模块
load_kernel_modules() {
    log_step "=== 步骤 2: 加载内核模块 ==="
    
    cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF
    
    modprobe overlay
    modprobe br_netfilter
    
    log_info "验证模块是否加载："
    lsmod | grep overlay
    lsmod | grep br_netfilter
    echo ""
}

# 步骤 3: 配置 sysctl 参数
configure_sysctl() {
    log_step "=== 步骤 3: 配置 sysctl 参数 ==="
    
    cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    
    sysctl --system > /dev/null 2>&1
    
    log_info "验证 sysctl 参数："
    sysctl net.bridge.bridge-nf-call-iptables
    sysctl net.bridge.bridge-nf-call-ip6tables
    sysctl net.ipv4.ip_forward
    echo ""
}

# 步骤 4: 配置 containerd（重要！）
configure_containerd() {
    log_step "=== 步骤 4: 配置 containerd（关键步骤）==="
    
    # 备份原配置
    if [ -f /etc/containerd/config.toml ]; then
        log_warn "备份原有配置文件"
        cp /etc/containerd/config.toml /etc/containerd/config.toml.backup.$(date +%Y%m%d%H%M%S)
    fi
    
    # 生成默认配置
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    
    # 修改 SystemdCgroup 为 true（关键配置）
    log_info "配置 SystemdCgroup = true（90%的问题都是这里）"
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
    
    # 配置国内镜像加速
    log_info "配置阿里云镜像加速"
    sed -i 's#registry.k8s.io/pause:3.8#registry.aliyuncs.com/google_containers/pause:3.9#g' /etc/containerd/config.toml
    sed -i 's#registry.k8s.io/pause:3.9#registry.aliyuncs.com/google_containers/pause:3.9#g' /etc/containerd/config.toml
    
    log_info "containerd 配置完成"
    echo ""
}

# 步骤 5: 关闭防火墙和 SELinux
disable_firewall_selinux() {
    log_step "=== 步骤 5: 关闭防火墙和 SELinux ==="
    
    # 关闭防火墙
    if systemctl is-active --quiet firewalld; then
        log_warn "关闭防火墙（生产环境建议配置规则而不是关闭）"
        systemctl stop firewalld
        systemctl disable firewalld
    else
        log_info "防火墙已经是关闭状态"
    fi
    
    # 关闭 SELinux
    if [ "$(getenforce)" != "Permissive" ] && [ "$(getenforce)" != "Disabled" ]; then
        log_warn "设置 SELinux 为 permissive 模式"
        setenforce 0
        sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    else
        log_info "SELinux 已经是 permissive 或 disabled 状态"
    fi
    echo ""
}

# 步骤 6: 重启服务
restart_services() {
    log_step "=== 步骤 6: 重启 containerd 和 kubelet 服务 ==="
    
    systemctl daemon-reload
    systemctl restart containerd
    systemctl enable containerd
    
    if systemctl is-active --quiet containerd; then
        log_info "containerd 服务启动成功"
    else
        log_error "containerd 服务启动失败"
        systemctl status containerd --no-pager -l
    fi
    
    systemctl restart kubelet
    systemctl enable kubelet
    
    log_info "服务重启完成"
    sleep 2
    echo ""
}

# 步骤 7: 验证容器运行时
verify_container_runtime() {
    log_step "=== 步骤 7: 验证容器运行时 ==="
    
    log_info "检查 containerd 版本："
    if crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock version; then
        log_info "✓ 容器运行时验证成功"
    else
        log_error "✗ 容器运行时验证失败"
    fi
    
    echo ""
    log_info "测试拉取镜像："
    if crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock pull registry.aliyuncs.com/google_containers/pause:3.9; then
        log_info "✓ 镜像拉取成功"
    else
        log_warn "✗ 镜像拉取失败（不影响后续操作）"
    fi
    echo ""
}

# 步骤 8: 显示诊断信息
show_diagnostics() {
    log_step "=== 步骤 8: 系统诊断信息 ==="
    
    echo ""
    log_info "系统信息："
    cat /etc/os-release | grep -E "^NAME=|^VERSION="
    echo "内核版本: $(uname -r)"
    
    echo ""
    log_info "Containerd 版本:"
    containerd --version
    
    echo ""
    log_info "Kubernetes 组件版本："
    kubeadm version -o short
    kubelet --version
    kubectl version --client --short 2>/dev/null || kubectl version --client
    
    echo ""
    log_info "网络配置："
    ip addr show | grep -E "inet " | grep -v "127.0.0.1" | awk '{print $NF, $2}'
    
    echo ""
    log_info "服务状态："
    echo "  Firewall: $(systemctl is-active firewalld 2>/dev/null || echo '已关闭')"
    echo "  SELinux: $(getenforce)"
    echo "  Containerd: $(systemctl is-active containerd)"
    echo "  Kubelet: $(systemctl is-active kubelet)"
    
    echo ""
    if ! check_ports; then
        log_warn "⚠️  有端口被占用，建议执行深度清理"
    else
        log_info "✓ 所有关键端口未被占用"
    fi
    echo ""
}

# 主函数
main() {
    echo ""
    log_info "=========================================="
    log_info "  Kubernetes 初始化问题修复脚本"
    log_info "=========================================="
    echo ""
    
    check_root
    
    # 先检查端口占用情况
    if ! check_ports; then
        echo ""
        log_error "检测到端口被占用！需要先执行深度清理"
        echo ""
        read -p "是否执行深度清理（强制清理所有 K8s 相关进程和数据）？(y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            deep_cleanup
            check_ports
        else
            log_warn "已取消执行，请手动清理后再运行此脚本"
            exit 1
        fi
    else
        log_info "✓ 端口检查通过"
    fi
    
    echo ""
    read -p "是否执行系统配置修复步骤？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warn "已取消执行"
        exit 0
    fi
    
    echo ""
    disable_swap
    load_kernel_modules
    configure_sysctl
    configure_containerd
    disable_firewall_selinux
    restart_services
    verify_container_runtime
    show_diagnostics
    
    echo ""
    log_info "=========================================="
    log_info "  修复完成！"
    log_info "=========================================="
    echo ""
    log_info "现在可以重新运行 kubeadm init 命令："
    echo ""
    echo -e "${YELLOW}kubeadm init \\${NC}"
    echo -e "${YELLOW}  --image-repository registry.aliyuncs.com/google_containers \\${NC}"
    echo -e "${YELLOW}  --kubernetes-version v1.28.0 \\${NC}"
    echo -e "${YELLOW}  --pod-network-cidr=10.244.0.0/16 \\${NC}"
    echo -e "${YELLOW}  --control-plane-endpoint \"VIP地址:6443\" \\${NC}"
    echo -e "${YELLOW}  --apiserver-advertise-address=本机IP \\${NC}"
    echo -e "${YELLOW}  --upload-certs${NC}"
    echo ""
    log_info "示例（根据您的环境修改）："
    echo -e "${GREEN}kubeadm init \\${NC}"
    echo -e "${GREEN}  --image-repository registry.aliyuncs.com/google_containers \\${NC}"
    echo -e "${GREEN}  --kubernetes-version v1.28.0 \\${NC}"
    echo -e "${GREEN}  --pod-network-cidr=10.244.0.0/16 \\${NC}"
    echo -e "${GREEN}  --control-plane-endpoint \"172.16.0.100:6443\" \\${NC}"
    echo -e "${GREEN}  --apiserver-advertise-address=172.16.0.10 \\${NC}"
    echo -e "${GREEN}  --upload-certs${NC}"
    echo ""
    log_info "如果初始化仍有问题，请查看日志："
    echo "  journalctl -xeu kubelet -n 100"
    echo "  journalctl -xeu containerd -n 100"
    echo ""
    log_info "或者重新运行此脚本并选择深度清理"
}

# 执行主函数
main
