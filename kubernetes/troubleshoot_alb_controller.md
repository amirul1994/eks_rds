## 🚀 Step-by-Step ALB Controller Problem Resolution

Here's the complete journey of troubleshooting and fixing the ALB Controller issue:

---

## 🔍 Step 1: Initial Symptoms

| Symptom | What We Saw |
|---------|-------------|
| **Ingress stuck** | `kubectl get ingress` showed no `ADDRESS` for 10+ minutes |
| **Controller logs** | `InvalidIdentityToken: The web identity token provided could not be validated` |
| **FailedBuildModel** | Ingress events showed `FailedBuildModel` errors |

---

## 🛠️ Step 2: Diagnosis

### 1. Checked ALB Controller Pods
```bash
kubectl get pods -n kube-system | grep aws-load-balancer-controller
```
✅ Pods were running.

### 2. Checked Ingress Events
```bash
kubectl describe ingress myapp-ingress
```
❌ Found `FailedBuildModel` with `InvalidIdentityToken` errors.

### 3. Checked Controller Logs
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=50
```
❌ Confirmed OIDC token validation failures.

### 4. Checked Service Account
```bash
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml
```
✅ Service account existed but had no annotation.

---

## 🔧 Step 3: Fixes Applied

### Fix 1: Create Service Account with Annotation
```bash
kubectl create sa aws-load-balancer-controller -n kube-system

kubectl annotate sa aws-load-balancer-controller -n kube-system \
  eks.amazonaws.com/role-arn=arn:aws:iam::381491977476:role/myapp-production-aws-load-balancer-controller-irsa
```
**Result:** Service account now linked to IAM role.

---

### Fix 2: Check and Fix OIDC Provider

#### 2.1 Check if OIDC Provider Exists
```bash
aws iam list-open-id-connect-providers
```
❌ No OIDC provider for the cluster.

#### 2.2 Create OIDC Provider
```bash
eksctl utils associate-iam-oidc-provider --cluster myapp-production --approve
```
✅ OIDC provider created in IAM.

---

### Fix 3: Verify IAM Role Trust Policy

#### 3.1 Check the Trust Policy
```bash
aws iam get-role --role-name myapp-production-aws-load-balancer-controller-irsa --query "Role.AssumeRolePolicyDocument"
```
✅ Trust policy was correct (matched cluster OIDC).

#### 3.2 Check Policy Attachment
```bash
aws iam list-attached-role-policies --role-name myapp-production-aws-load-balancer-controller-irsa
```
✅ `AWSLoadBalancerControllerPolicy` was attached.

---

### Fix 4: Reinstall ALB Controller

#### 4.1 Uninstall
```bash
helm uninstall aws-load-balancer-controller -n kube-system
```

#### 4.2 Reinstall with Correct Service Account
```bash
CLUSTER_NAME=$(aws eks list-clusters --query "clusters[0]" --output text)
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.resourcesVpcConfig.vpcId" --output text)

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1 \
  --set vpcId=$VPC_ID
```

---

### Fix 5: Verify and Test

#### 5.1 Check Pods
```bash
kubectl get pods -n kube-system | grep aws-load-balancer-controller
```
✅ 2 pods running.

#### 5.2 Check Controller Logs
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=20
```
✅ No more `InvalidIdentityToken` errors.

#### 5.3 Check Ingress
```bash
kubectl get ingress -w
```
✅ Address appeared within 2 minutes.

---

## 📊 Summary of Root Cause

| Root Cause | Why It Happened |
|------------|-----------------|
| **OIDC provider missing** | Not created by Terraform or manually |
| **Service account missing annotation** | Created manually but not annotated |
| **Trust policy mismatch** | Initially misaligned, later fixed |

---

## 🎯 Final Working State

| Component | Status |
|-----------|--------|
| **OIDC Provider** | ✅ Created |
| **Service Account** | ✅ Annotated with role ARN |
| **IAM Role** | ✅ Correct trust policy |
| **ALB Controller** | ✅ Running |
| **Ingress** | ✅ ALB created |
| **Target Groups** | ✅ Healthy |

---

## 🚀 Key Lessons

| Lesson | Why It Matters |
|--------|----------------|
| **Create OIDC provider first** | IRSA won't work without it |
| **Annotate service account** | Links pod to IAM role |
| **Use `eksctl` for IRSA** | Handles everything automatically |
| **Check controller logs** | First place to look for errors |
| **Reinstall after fixes** | Ensures changes take effect |