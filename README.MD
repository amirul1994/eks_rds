## Configure OIDC for GitHub

### Step 1: Navigate to IAM → Identity Providers

1. Go to **AWS Console** → **IAM**
2. Click **Identity providers** in the left sidebar
3. Click **Add provider**

### Step 2: Fill in Provider Details

| Field          | Value                                      |
|----------------|--------------------------------------------|
| Provider type  | ✅ Select **OpenID Connect**               |
| Provider URL   | `https://token.actions.githubusercontent.com` |
| Audience       | `sts.amazonaws.com`                        |

### Step 3: Complete Setup

- Click **Add provider**

**Create an OIDC Trust Policy**

```bash
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::381491977476:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:amirul1994/eks_rds:*"
        }
      }
    }
  ]
}
```

**Create Role Using the trust policy**

```bash
aws iam create-role \
  --role-name github-actions-ecr-role \
  --assume-role-policy-document file://oidc_trust_policy.json
```

**Attach policy to Push to ECR**

```bash
aws iam attach-role-policy \
  --role-name github-actions-ecr-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
```