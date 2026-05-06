#!/bin/bash

# EKS Deployment Status Checker
# Usage: ./check-eks-status.sh

CLUSTER_NAME="cloudpollpro-cluster"
REGION="eu-west-3"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================"
echo "  EKS Deployment Status Check"
echo "  Cluster: $CLUSTER_NAME"
echo "  Region: $REGION"
echo "========================================"
echo ""

# 1. Check Node Group Status
echo -e "${BLUE}[1/6] Node Group Status${NC}"
NODEGROUP_NAME=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --query 'nodegroups[0]' --output text 2>/dev/null)

if [ -n "$NODEGROUP_NAME" ] && [ "$NODEGROUP_NAME" != "None" ]; then
    NODEGROUP_STATUS=$(aws eks describe-nodegroup \
        --cluster-name $CLUSTER_NAME \
        --nodegroup-name $NODEGROUP_NAME \
        --region $REGION \
        --query 'nodegroup.status' \
        --output text 2>/dev/null)
    
    if [ "$NODEGROUP_STATUS" == "ACTIVE" ]; then
        echo -e "  ✓ ${GREEN}Node Group: $NODEGROUP_STATUS${NC}"
    elif [ "$NODEGROUP_STATUS" == "CREATING" ]; then
        echo -e "  ⏳ ${YELLOW}Node Group: $NODEGROUP_STATUS${NC}"
    else
        echo -e "  ✗ ${RED}Node Group: $NODEGROUP_STATUS${NC}"
    fi
else
    echo -e "  ⏳ ${YELLOW}Node Group: Not found yet${NC}"
fi
echo ""

# 2. Check EKS Addons
echo -e "${BLUE}[2/6] EKS Addons${NC}"
ADDONS=$(aws eks list-addons --cluster-name $CLUSTER_NAME --region $REGION --query 'addons' --output text 2>/dev/null)

if [ -n "$ADDONS" ] && [ "$ADDONS" != "None" ]; then
    for addon in $ADDONS; do
        ADDON_STATUS=$(aws eks describe-addon \
            --cluster-name $CLUSTER_NAME \
            --addon-name $addon \
            --region $REGION \
            --query 'addon.status' \
            --output text 2>/dev/null)
        
        if [ "$ADDON_STATUS" == "ACTIVE" ]; then
            echo -e "  ✓ ${GREEN}$addon: $ADDON_STATUS${NC}"
        elif [[ "$ADDON_STATUS" == "CREATING" || "$ADDON_STATUS" == "UPDATING" ]]; then
            echo -e "  ⏳ ${YELLOW}$addon: $ADDON_STATUS${NC}"
        else
            echo -e "  ✗ ${RED}$addon: $ADDON_STATUS${NC}"
        fi
    done
else
    echo -e "  ⏳ ${YELLOW}No addons installed yet${NC}"
fi
echo ""

# 3. Check Nodes
echo -e "${BLUE}[3/6] Kubernetes Nodes${NC}"
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME --kubeconfig /tmp/eks-check 2>/dev/null

NODE_COUNT=$(kubectl --kubeconfig /tmp/eks-check get nodes --no-headers 2>/dev/null | wc -l)
READY_COUNT=$(kubectl --kubeconfig /tmp/eks-check get nodes --no-headers 2>/dev/null | grep -c " Ready ")

if [ $NODE_COUNT -gt 0 ]; then
    if [ $READY_COUNT -eq $NODE_COUNT ]; then
        echo -e "  ✓ ${GREEN}Nodes: $READY_COUNT/$NODE_COUNT Ready${NC}"
    else
        echo -e "  ⏳ ${YELLOW}Nodes: $READY_COUNT/$NODE_COUNT Ready${NC}"
    fi
    kubectl --kubeconfig /tmp/eks-check get nodes 2>/dev/null | sed 's/^/    /'
else
    echo -e "  ⏳ ${YELLOW}No nodes have joined yet${NC}"
fi
echo ""

# 4. Check System Pods
echo -e "${BLUE}[4/6] System Pods (kube-system)${NC}"
SYSTEM_PODS=$(kubectl --kubeconfig /tmp/eks-check get pods -n kube-system --no-headers 2>/dev/null | wc -l)

if [ $SYSTEM_PODS -gt 0 ]; then
    RUNNING_PODS=$(kubectl --kubeconfig /tmp/eks-check get pods -n kube-system --no-headers 2>/dev/null | grep -c "Running")
    echo -e "  ℹ️  Running: $RUNNING_PODS/$SYSTEM_PODS pods"
    
    # Show any non-running pods
    NOT_RUNNING=$(kubectl --kubeconfig /tmp/eks-check get pods -n kube-system --no-headers 2>/dev/null | grep -v "Running" | grep -v "Completed")
    if [ -n "$NOT_RUNNING" ]; then
        echo -e "  ${YELLOW}Non-running pods:${NC}"
        echo "$NOT_RUNNING" | sed 's/^/    /'
    fi
else
    echo -e "  ⏳ ${YELLOW}No system pods yet${NC}"
fi
echo ""

# 5. Check Nginx Deployment
echo -e "${BLUE}[5/6] Nginx Deployment${NC}"
NGINX_DEPLOY=$(kubectl --kubeconfig /tmp/eks-check get deployment nginx -o json 2>/dev/null)

if [ $? -eq 0 ]; then
    REPLICAS=$(echo $NGINX_DEPLOY | jq -r '.spec.replicas')
    READY=$(echo $NGINX_DEPLOY | jq -r '.status.readyReplicas // 0')
    
    if [ "$READY" == "$REPLICAS" ]; then
        echo -e "  ✓ ${GREEN}Nginx: $READY/$REPLICAS replicas ready${NC}"
    else
        echo -e "  ⏳ ${YELLOW}Nginx: $READY/$REPLICAS replicas ready${NC}"
    fi
else
    echo -e "  ⏳ ${YELLOW}Nginx deployment not created yet${NC}"
fi
echo ""

# 6. Check Nginx Service
echo -e "${BLUE}[6/6] Nginx Service (LoadBalancer)${NC}"
NGINX_SVC=$(kubectl --kubeconfig /tmp/eks-check get service nginx -o json 2>/dev/null)

if [ $? -eq 0 ]; then
    LB_HOSTNAME=$(echo $NGINX_SVC | jq -r '.status.loadBalancer.ingress[0].hostname // empty')
    
    if [ -n "$LB_HOSTNAME" ]; then
        echo -e "  ✓ ${GREEN}LoadBalancer provisioned${NC}"
        echo -e "  ${GREEN}URL: http://$LB_HOSTNAME${NC}"
    else
        echo -e "  ⏳ ${YELLOW}LoadBalancer provisioning...${NC}"
    fi
else
    echo -e "  ⏳ ${YELLOW}Service not created yet${NC}"
fi
echo ""

echo "========================================"
echo "  Status check complete!"
echo "  Run again in a few minutes to see updates"
echo "========================================"
