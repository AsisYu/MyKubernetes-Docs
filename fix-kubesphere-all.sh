#!/bin/bash
# KubeSphere 完整修复脚本（包含 metrics-server）
# 一键解决所有问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "KubeSphere 完整修复脚本"
echo "=========================================="
echo ""

# ========== 第一步：清理所有旧资源 ==========
echo -e "${YELLOW}[1/4] 清理所有旧资源...${NC}"
echo ""

# 清理 KubeSphere
echo "清理 KubeSphere 资源..."
kubectl delete -f cluster-configuration.yaml 2>/dev/null || true
kubectl delete -f kubesphere-installer.yaml 2>/dev/null || true

# 强制删除 namespace（如果卡住）
if kubectl get namespace kubesphere-system &>/dev/null; then
    echo "正在删除 kubesphere-system namespace..."
    kubectl delete namespace kubesphere-system --force --grace-period=0 2>/dev/null || true
    
    # 如果还是存在，尝试移除 finalizers
    if command -v jq &> /dev/null && kubectl get namespace kubesphere-system &>/dev/null; then
        echo "尝试强制清理 finalizers..."
        kubectl get namespace kubesphere-system -o json | jq '.spec.finalizers = []' | kubectl replace --raw /api/v1/namespaces/kubesphere-system/finalize -f - 2>/dev/null || true
    fi
    
    # 等待最多 30 秒
    timeout=30
    elapsed=0
    while kubectl get namespace kubesphere-system &>/dev/null && [ $elapsed -lt $timeout ]; do
        echo "等待 namespace 删除... ($elapsed/$timeout 秒)"
        sleep 3
        elapsed=$((elapsed + 3))
    done
fi

# 清理 metrics-server
echo "清理旧的 metrics-server..."
kubectl delete deployment -n kube-system metrics-server 2>/dev/null || true
kubectl delete service -n kube-system metrics-server 2>/dev/null || true
kubectl delete serviceaccount -n kube-system metrics-server 2>/dev/null || true
kubectl delete clusterrole system:aggregated-metrics-reader 2>/dev/null || true
kubectl delete clusterrole system:metrics-server 2>/dev/null || true
kubectl delete clusterrolebinding metrics-server:system:auth-delegator 2>/dev/null || true
kubectl delete clusterrolebinding system:metrics-server 2>/dev/null || true
kubectl delete rolebinding -n kube-system metrics-server-auth-reader 2>/dev/null || true
kubectl delete apiservice v1beta1.metrics.k8s.io 2>/dev/null || true

echo "等待资源完全删除..."
sleep 10

echo -e "${GREEN}✓ 资源清理完成${NC}"
echo ""

# ========== 第二步：安装 metrics-server ==========
echo -e "${YELLOW}[2/4] 安装 metrics-server...${NC}"
echo ""

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    k8s-app: metrics-server
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
    rbac.authorization.k8s.io/aggregate-to-edit: "true"
    rbac.authorization.k8s.io/aggregate-to-view: "true"
  name: system:aggregated-metrics-reader
rules:
- apiGroups:
  - metrics.k8s.io
  resources:
  - pods
  - nodes
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    k8s-app: metrics-server
  name: system:metrics-server
rules:
- apiGroups:
  - ""
  resources:
  - nodes/metrics
  verbs:
  - get
- apiGroups:
  - ""
  resources:
  - pods
  - nodes
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server-auth-reader
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: extension-apiserver-authentication-reader
subjects:
- kind: ServiceAccount
  name: metrics-server
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server:system:auth-delegator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: metrics-server
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    k8s-app: metrics-server
  name: system:metrics-server
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:metrics-server
subjects:
- kind: ServiceAccount
  name: metrics-server
  namespace: kube-system
---
apiVersion: v1
kind: Service
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
spec:
  ports:
  - name: https
    port: 443
    protocol: TCP
    targetPort: https
  selector:
    k8s-app: metrics-server
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  strategy:
    rollingUpdate:
      maxUnavailable: 0
  template:
    metadata:
      labels:
        k8s-app: metrics-server
    spec:
      containers:
      - args:
        - --cert-dir=/tmp
        - --secure-port=4443
        - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
        - --kubelet-use-node-status-port
        - --metric-resolution=15s
        - --kubelet-insecure-tls
        image: registry.cn-hangzhou.aliyuncs.com/google_containers/metrics-server:v0.6.4
        imagePullPolicy: IfNotPresent
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /livez
            port: https
            scheme: HTTPS
          periodSeconds: 10
        name: metrics-server
        ports:
        - containerPort: 4443
          name: https
          protocol: TCP
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /readyz
            port: https
            scheme: HTTPS
          initialDelaySeconds: 20
          periodSeconds: 10
        resources:
          requests:
            cpu: 100m
            memory: 200Mi
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
        volumeMounts:
        - mountPath: /tmp
          name: tmp-dir
      nodeSelector:
        kubernetes.io/os: linux
      priorityClassName: system-cluster-critical
      serviceAccountName: metrics-server
      volumes:
      - emptyDir: {}
        name: tmp-dir
---
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  labels:
    k8s-app: metrics-server
  name: v1beta1.metrics.k8s.io
spec:
  group: metrics.k8s.io
  groupPriorityMinimum: 100
  insecureSkipTLSVerify: true
  service:
    name: metrics-server
    namespace: kube-system
  version: v1beta1
  versionPriority: 100
EOF

echo "等待 metrics-server Pod 启动..."
sleep 15

echo -e "${GREEN}✓ metrics-server 安装完成${NC}"
echo ""

# ========== 第三步：验证 metrics-server ==========
echo -e "${YELLOW}[3/4] 验证 metrics-server...${NC}"
echo ""

# 检查 Pod 状态
echo "检查 Pod 状态..."
kubectl get pods -n kube-system | grep metrics-server

# 等待 Pod Ready
echo ""
echo "等待 Pod 就绪（最多 60 秒）..."
kubectl wait --for=condition=Ready pod -l k8s-app=metrics-server -n kube-system --timeout=60s || {
    echo -e "${RED}警告：Pod 未在 60 秒内就绪，查看详情：${NC}"
    kubectl describe pod -n kube-system -l k8s-app=metrics-server | tail -30
}

# 检查 APIService
echo ""
echo "检查 APIService 状态..."
kubectl get apiservice v1beta1.metrics.k8s.io

# 测试 metrics API
echo ""
echo "测试 metrics API..."
sleep 10
if kubectl top nodes &>/dev/null; then
    echo -e "${GREEN}✓ metrics-server 工作正常！${NC}"
    kubectl top nodes
else
    echo -e "${YELLOW}⚠ metrics API 暂时不可用，但会在几分钟内就绪${NC}"
fi

echo ""

# ========== 第四步：安装 KubeSphere ==========
echo -e "${YELLOW}[4/4] 安装 KubeSphere...${NC}"
echo ""

# 检查文件
if [ ! -f "kubesphere-installer.yaml" ] || [ ! -f "cluster-configuration.yaml" ]; then
    echo -e "${RED}错误：找不到必需的 YAML 文件${NC}"
    echo "请确保以下文件存在："
    echo "  - kubesphere-installer.yaml"
    echo "  - cluster-configuration.yaml"
    exit 1
fi

# 应用 installer
echo "应用 KubeSphere Installer..."
kubectl apply -f kubesphere-installer.yaml

# 等待 Pod 启动
echo "等待 ks-installer Pod 启动..."
sleep 15

# 应用 configuration
echo "应用 ClusterConfiguration..."
kubectl apply -f cluster-configuration.yaml

echo ""
echo -e "${GREEN}✓ KubeSphere 安装已启动！${NC}"
echo ""

# 显示状态
echo "当前状态："
kubectl get pods -n kubesphere-system

echo ""
echo "=========================================="
echo -e "${GREEN}修复完成！${NC}"
echo "=========================================="
echo ""
echo "查看安装日志："
echo "kubectl logs -n kubesphere-system -l app=ks-installer -f"
echo ""
echo "查看所有 Pod 状态："
echo "kubectl get pods -n kubesphere-system"
echo ""
echo -e "${YELLOW}提示：安装需要 10-30 分钟，请耐心等待${NC}"

