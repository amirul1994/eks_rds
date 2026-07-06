# 🔐 Complete SSL Certificate Installation Guide for EKS using cert-manager & Let's Encrypt

This guide provides step‑by‑step instructions to install and configure `cert-manager` with Let's Encrypt on an Amazon EKS cluster to automatically provision public, internet‑trusted SSL/TLS certificates.

---

## 📋 Prerequisites

- An existing EKS cluster (`kubectl get nodes` works)
- `kubectl` installed and configured
- Helm installed (optional, for verification)
- A registered domain name (e.g., `example.com`)
- An Ingress controller (e.g., AWS Load Balancer Controller) deployed on the cluster

---

## 📝 Step 1: Install cert-manager

### 1.1 Install cert-manager CRDs and Resources

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml
```

### 1.2 Verify cert-manager Installation

```bash
# Check the cert-manager pods
kubectl get pods -n cert-manager
```

Expected output:
```
NAME                                      READY   STATUS    RESTARTS   AGE
cert-manager-xxxxxxxxxx-xxxxx             1/1     Running   0          30s
cert-manager-cainjector-xxxxx             1/1     Running   0          30s
cert-manager-webhook-xxxxx                1/1     Running   0          30s
```

### 1.3 Verify cert-manager API is Available

```bash
kubectl api-resources | grep cert-manager
```

Expected output:
```
certificaterequests               cr      cert-manager.io/v1               true         CertificateRequest
certificates                      cert    cert-manager.io/v1               true         Certificate
challenges                        c       cert-manager.io/v1               true         Challenge
clusterissuers                    ci      cert-manager.io/v1               false        ClusterIssuer
issuers                           i       cert-manager.io/v1               true         Issuer
orders                            o       cert-manager.io/v1               true         Order
```

---

## 📝 Step 2: Configure Let's Encrypt ClusterIssuer

### 2.1 Choose Your Challenge Type

| Challenge Type | Use Case |
|----------------|----------|
| **HTTP-01** | For non‑wildcard certificates; requires a public Ingress endpoint |
| **DNS-01** | For wildcard certificates (`*.example.com`); requires DNS provider credentials |

---

### 2.2 Option A: HTTP‑01 Challenge (Recommended for Simple Domains)

**Create `cluster-issuer-http.yaml`:**

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # Production Let's Encrypt server
    server: https://acme-v02.api.letsencrypt.org/directory
    # Replace with your email address
    email: your-email@example.com
    # Secret to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: alb
```

**Apply the ClusterIssuer:**

```bash
kubectl apply -f cluster-issuer-http.yaml
```

---

### 2.3 Option B: DNS‑01 Challenge (For Wildcard Certificates)

**Create `cluster-issuer-dns.yaml`:**

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - dns01:
        route53:
          region: us-east-1
          # Optional: IAM role ARN for cross‑account access
          # role: arn:aws:iam::ACCOUNT_ID:role/Route53AccessRole
          accessKeyID: YOUR_ACCESS_KEY_ID
          secretAccessKeySecretRef:
            name: route53-credentials
            key: secret-access-key
```

**Create the Route53 credentials secret:**

```bash
kubectl create secret generic route53-credentials \
  -n cert-manager \
  --from-literal=secret-access-key=YOUR_SECRET_ACCESS_KEY
```

**Apply the ClusterIssuer:**

```bash
kubectl apply -f cluster-issuer-dns.yaml
```

---

### 2.4 Verify the ClusterIssuer

```bash
kubectl get clusterissuer letsencrypt-prod -o yaml
```

---

## 📝 Step 3: Request a Certificate

### 3.1 Create a Certificate Resource

**Create `certificate.yaml`:**

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-tls
  namespace: default
spec:
  # Secret name where the certificate will be stored
  secretName: myapp-tls-secret
  # Certificate validity duration (90 days)
  duration: 2160h
  # Renewal before expiry (15 days)
  renewBefore: 360h
  # The domain names to secure
  dnsNames:
  - myapp.example.com
  # Optional: Subject Alternative Names
  # - www.myapp.example.com
  # Reference to the ClusterIssuer
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
```

**Apply the Certificate:**

```bash
kubectl apply -f certificate.yaml
```

---

## 📝 Step 4: Verify Certificate Issuance

### 4.1 Check Certificate Status

```bash
kubectl get certificate myapp-tls -n default
```

Expected output:
```
NAME        READY   SECRET             AGE
myapp-tls   True    myapp-tls-secret   30s
```

### 4.2 Check Certificate Request

```bash
kubectl get certificaterequest -A
```

### 4.3 Describe the Certificate (for detailed status)

```bash
kubectl describe certificate myapp-tls -n default
```

### 4.4 Check for ACME Orders

```bash
kubectl get order -A
```

### 4.5 Verify the Secret Contains the Certificate

```bash
kubectl get secret myapp-tls-secret -n default -o yaml
```

---

## 📝 Step 5: Use the Certificate in an Ingress

### 5.1 For AWS Load Balancer Controller (ALB)

AWS ALB requires **AWS ACM certificates** for HTTPS listeners. You can import the cert-manager‑issued certificate into ACM.

**Export the certificate and key:**

```bash
kubectl get secret myapp-tls-secret -n default -o jsonpath='{.data.tls\.crt}' | base64 -d > tls.crt
kubectl get secret myapp-tls-secret -n default -o jsonpath='{.data.tls\.key}' | base64 -d > tls.key
kubectl get secret myapp-tls-secret -n default -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt
```

**Import into ACM (for the same region as your ALB):**

```bash
aws acm import-certificate \
  --certificate fileb://tls.crt \
  --private-key fileb://tls.key \
  --certificate-chain fileb://ca.crt \
  --region us-east-1
```

**Get the ACM certificate ARN:**

```bash
aws acm list-certificates --region us-east-1 --query "CertificateSummaryList[?DomainName=='myapp.example.com'].CertificateArn" --output text
```

**Use the ARN in the Ingress annotation:**

```yaml
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/xxxxx
```

---

### 5.2 For NGINX Ingress Controller

**Create `ingress.yaml`:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls-secret
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

**Apply the Ingress:**

```bash
kubectl apply -f ingress.yaml
```

---

## 📝 Step 6: Troubleshooting

### 6.1 Check cert-manager Logs

```bash
kubectl logs -n cert-manager deployment/cert-manager
```

### 6.2 Describe the Certificate

```bash
kubectl describe certificate myapp-tls -n default
```

### 6.3 Check CertificateRequest

```bash
kubectl describe certificaterequest -n default
```

### 6.4 Check Order and Challenges

```bash
kubectl get order -A
kubectl describe order -A
kubectl get challenge -A
```

### 6.5 Common Issues and Fixes

| Issue | Solution |
|-------|----------|
| **HTTP‑01 challenge fails** | Verify that your Ingress has a public IP and the domain resolves to it |
| **DNS‑01 challenge fails** | Check IAM permissions for Route53 and secret credentials |
| **Certificate not ready** | Check `kubectl describe certificate` for detailed events |
| **Rate limits** | Let's Encrypt has a limit of 50 certificates per domain per week |

---

## 📝 Step 7: Clean Up

```bash
# Delete the certificate
kubectl delete certificate myapp-tls -n default

# Delete the ClusterIssuer
kubectl delete clusterissuer letsencrypt-prod

# Uninstall cert-manager
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml
```

---

## ✅ Summary

| Step | What It Does |
|------|--------------|
| **1** | Installs cert-manager |
| **2** | Creates a Let's Encrypt ClusterIssuer |
| **3** | Requests a certificate |
| **4** | Verifies certificate issuance |
| **5** | Uses the certificate in an Ingress |
| **6** | Provides troubleshooting steps |
| **7** | Clean up resources (if needed) |
