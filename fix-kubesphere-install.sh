#!/bin/bash
# KubeSphere 安装修复脚本
# 
# 功能：
#   - 清理旧的 KubeSphere 安装资源
#   - 健壮地等待资源完全删除
#   - 按正确顺序部署 installer 和 configuration
#   - 验证 CRD 注册后再应用配置
#
# 使用方法：
#   1. 确保当前目录包含以下文件：
#      - kubesphere-installer.yaml（必须包含 CRD 定义）
#      - cluster-configuration.yaml
#   2. 执行：bash fix-kubesphere-install.sh
#   3. 或者：chmod +x fix-kubesphere-install.sh && ./fix-kubesphere-install.sh
#
# 前置要求：
#   - kubectl 已安装并配置
#   - 具有集群管理员权限
#   - （可选）jq 已安装（用于强制删除卡住的 namespace）
#
# 注意：此脚本会删除现有的 KubeSphere 安装，请确认后再执行

set -e

echo "=========================================="
echo "KubeSphere 安装修复脚本"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查必需工具
echo "检查必需工具..."
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}错误：kubectl 未安装或不在 PATH 中${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}警告：jq 未安装，某些高级功能可能不可用${NC}"
    echo "如果遇到 namespace 删除卡住的问题，请安装 jq："
    echo "  dnf install -y jq"
    echo ""
fi

# 步骤 1：清理现有资源
echo -e "${YELLOW}步骤 1/7: 清理现有资源...${NC}"
kubectl delete -f cluster-configuration.yaml 2>/dev/null && echo "已删除 cluster-configuration" || echo "cluster-configuration 不存在或已删除"
kubectl delete -f kubesphere-installer.yaml 2>/dev/null && echo "已删除 kubesphere-installer" || echo "kubesphere-installer 不存在或已删除"
kubectl delete namespace kubesphere-system 2>/dev/null && echo "已删除 kubesphere-system namespace" || echo "kubesphere-system namespace 不存在或已删除"

echo "等待 namespace 完全删除..."
# 健壮的等待机制：最多等待 120 秒
timeout=120
elapsed=0
while kubectl get namespace kubesphere-system &>/dev/null; do
    if [ $elapsed -ge $timeout ]; then
        echo -e "${YELLOW}警告：namespace 删除超时，尝试强制删除...${NC}"
        # 强制删除 namespace（移除 finalizers）
        if command -v jq &> /dev/null; then
            kubectl get namespace kubesphere-system -o json | jq '.spec.finalizers = []' | kubectl replace --raw /api/v1/namespaces/kubesphere-system/finalize -f - 2>/dev/null || true
        else
            echo -e "${YELLOW}提示：如需强制删除，请安装 jq 后重新运行脚本${NC}"
            echo "或手动执行：kubectl delete namespace kubesphere-system --force --grace-period=0"
        fi
        sleep 5
        break
    fi
    echo "等待 namespace 删除... ($elapsed/$timeout 秒)"
    sleep 5
    elapsed=$((elapsed + 5))
done

if kubectl get namespace kubesphere-system &>/dev/null; then
    echo -e "${RED}错误：无法删除 namespace，请手动检查${NC}"
    kubectl get namespace kubesphere-system
    exit 1
else
    echo -e "${GREEN}✓ 旧资源已完全清理${NC}"
fi

# 步骤 2：验证 YAML 文件存在
echo -e "${YELLOW}步骤 2/7: 验证 YAML 文件...${NC}"
if [ ! -f "kubesphere-installer.yaml" ]; then
    echo -e "${RED}错误：找不到 kubesphere-installer.yaml 文件${NC}"
    echo "请确保在正确的目录中运行此脚本（通常是 ~/kubesphere）"
    exit 1
fi

if [ ! -f "cluster-configuration.yaml" ]; then
    echo -e "${RED}错误：找不到 cluster-configuration.yaml 文件${NC}"
    echo "请确保在正确的目录中运行此脚本（通常是 ~/kubesphere）"
    exit 1
fi

echo -e "${GREEN}✓ YAML 文件验证通过${NC}"

# 步骤 3：部署 KubeSphere Installer
echo -e "${YELLOW}步骤 3/7: 部署 KubeSphere Installer...${NC}"
kubectl apply -f kubesphere-installer.yaml

# 验证 namespace 创建
sleep 3
kubectl get ns kubesphere-system || {
    echo -e "${RED}错误：kubesphere-system namespace 创建失败${NC}"
    exit 1
}
echo -e "${GREEN}✓ Installer 部署成功${NC}"

# 步骤 4：等待 Installer Pod 启动
echo -e "${YELLOW}步骤 4/7: 等待 ks-installer Pod 启动...${NC}"
echo "这可能需要 30-90 秒，请耐心等待..."

kubectl wait --for=condition=Ready pod -l app=ks-installer -n kubesphere-system --timeout=180s || {
    echo -e "${RED}错误：ks-installer Pod 启动超时${NC}"
    echo "查看 Pod 状态："
    kubectl get pods -n kubesphere-system
    echo ""
    echo "查看 Pod 详情："
    kubectl describe pod -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}')
    exit 1
}

echo -e "${GREEN}✓ ks-installer Pod 已启动${NC}"

# 检查 Pod 状态
POD_STATUS=$(kubectl get pods -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].status.phase}')
echo "当前 Pod 状态: $POD_STATUS"

# 查看初始日志
echo ""
echo "查看 ks-installer 初始日志："
kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}') --tail=15
echo ""

# 步骤 5：等待 ClusterConfiguration CRD 注册
echo -e "${YELLOW}步骤 5/7: 等待 ClusterConfiguration CRD 注册...${NC}"
echo "这是关键步骤，请等待..."

timeout=120
elapsed=0
until kubectl get crd clusterconfigurations.installer.kubesphere.io &>/dev/null; do
    if [ $elapsed -ge $timeout ]; then
        echo -e "${RED}错误：等待 CRD 注册超时（${timeout} 秒）${NC}"
        echo "检查 installer Pod 日志："
        kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}')
        exit 1
    fi
    echo "CRD 尚未注册，等待中... ($elapsed/$timeout 秒)"
    sleep 5
    elapsed=$((elapsed + 5))
done

echo -e "${GREEN}✓ ClusterConfiguration CRD 已注册${NC}"

# 步骤 6：验证 CRD 已就绪
echo -e "${YELLOW}步骤 6/7: 验证 CRD 状态...${NC}"
kubectl get crd clusterconfigurations.installer.kubesphere.io

CRD_STATUS=$(kubectl get crd clusterconfigurations.installer.kubesphere.io -o jsonpath='{.status.conditions[?(@.type=="Established")].status}')
if [ "$CRD_STATUS" == "True" ]; then
    echo -e "${GREEN}✓ CRD 状态正常${NC}"
else
    echo -e "${YELLOW}警告：CRD 状态未知，但继续安装...${NC}"
fi

# 步骤 7：应用 ClusterConfiguration
echo -e "${YELLOW}步骤 7/7: 应用 ClusterConfiguration...${NC}"
sleep 3
kubectl apply -f cluster-configuration.yaml

# 验证 ClusterConfiguration 创建
sleep 3
kubectl get cc -n kubesphere-system ks-installer || {
    echo -e "${RED}错误：ClusterConfiguration 创建失败${NC}"
    exit 1
}

echo -e "${GREEN}✓ ClusterConfiguration 已创建${NC}"

# 最终验证
echo ""
echo "=========================================="
echo -e "${GREEN}安装已成功启动！${NC}"
echo "=========================================="
echo ""

echo "查看安装状态："
kubectl get pods -n kubesphere-system

echo ""
echo "查看安装日志（实时跟踪）："
echo "kubectl logs -n kubesphere-system \$(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}') -f"

echo ""
echo -e "${YELLOW}提示：安装过程需要 10-30 分钟，请使用上述命令查看实时日志${NC}"
echo ""
echo "安装完成后，您将看到类似以下的输出："
echo "  Console: http://172.16.0.10:30880"
echo "  Account: admin"
echo "  Password: P@88w0rd"
echo ""
echo -e "${GREEN}脚本执行完成！${NC}"

