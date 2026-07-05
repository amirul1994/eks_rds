1. **Backup & Disaster Recovery**
 - Implement kubernetes backup app like Velero for EKS backup and restore wth s3. Without proper backups incidenet like accidental cluster deletion will cause data loss permanently. It will help the team to recover quickly from disaster ensuring less downtime. 
 - Install Velero using Helm with S3 as a backup storage location, create a automated backup schedule. It will prevent permanent data loss.

2. **Network Policies**
 - Implement Kubernetes Network Policies using a CNI that supports these (e.g Calico) to restrict pod-to-pod communication. Without network policies, any pod in the cluster can communicate with any other pod, increasing the attack surface.
 - It enhances the security by limiting access, contains potential breaches, reduces the area of compromised pods, and helps meet zero-trust security requirements.
 - Install Calico (supported with the existing VPC CNI) using the AWS Calico operator, define network policies to allow only frontend → backend, backend → database, and deny all other traffic by default, then test policies using kubectl exec to verify connectivity.

3. **GitOps with Argo CD**
 - Implement Argo CD for GitOps-based deployments with automated sync policies and drift detection.
 - Manual kubectl apply deployments are not auditable, hard to roll back, and do not track configuration drift. Multiple team members making manual changes to the cluster can lead to configuration drift, making it impossible to know the cluster's actual state.
 - ArgoCD enables automated, auditable deployments, provides automatic drift correction, simplifies rollbacks to any previous Git commit, improves collaboration by using Git as the single source of truth, and reduces operational overhead.
 - Install Argo CD using Helm, 
 - configure it with Git repositories containing Helm charts or Kubernetes manifests - set automated.syncPolicy with prune: true and selfHeal: true, integrate with Argo CD Image Updater for automatic image updates