1. **Pod is in CrashLoopBack**
 - Check pods via 'kubectl logs <pod name> --previous'
 - Verify the container image and entrypoint or command
 - Check resource limits (e.g cpu/memory) and liveness probe, readiness probe and startup probe configuration
 - Check environment variables, secrets and configmaps values are correctly set.

2. **Deployment is successful, but app is not reachable**
 - Verify the service and ingress are correctly configured
 - Test service endpoints
 - Check network policies, rbac for proper permission in the cluster

3. **Difference between readiness and liveness probe**
 - The Readiness probe determines the pod is ready to receive traffic.
 - The liveness probe checks if the pod is running

4. **Docker build works locally but fails in pipeline**
 - Environment variables or secrets may not be available in the pipeline.
 - Firewall, prox or vpn restrict access to the image registry, or the registry is private
 - Pipeline may have a different Docker version, base image, or cache

5. **Pipeline fails during Docker build**
 - Review pipeline logs for specific error messages
 - Check Dockerfile syntax and steps
 - Verify that dependencies (e.g. apt-get, pip install) are available
 - Ensure registry credentials and network access are configured

6. **Certificate renewal failed**
 - Verify cert-manager or ACME configuration
 - Check the challenge type (HTTP-01 or DNS-01) and ensure it's configured correctly
 - Check if the ingress is reachable from the internet for HTTP-01 challenges
 - Ensure IAM permissions and dns records are correct for DNS-01 challenges

7. **Ingress returns 502 or 504**
 - Verify that the backend service is healthy and responding
 - Check the service port and the container port are matched
 - Check target group health checks
 - Ensure network policies or security groups are not blocking traffic

8. **Vendor SFTP connection to port 22 times out**
 - Verify that the bastion or jump host can reach the vendor SFTP endpoint
 - Check security group rules for outbound traffic on port 22
 - Check if there is a network firewall or proxy blocking the connection

9. **Terraform plan wants to recreate the cluster**
 - Look specifically for changes to cluster-critical resources like aws_eks_cluster, aws_eks_node_group, aws_vpc, aws_subnet, or aws_security_group. If any of these show forces replacement, the cluster will be recreated.
 - Check for immutable changes, common causes include changing version (Kubernetes version) for the EKS cluster, changing cidr_block for VPC/subnets, modifying name or role_arn of the cluster, or updating instance_type or disk_size in a managed node group without a rolling update strategy.
 - Run 'terraform state show <resource>' to see what's currently deployed and review the resource's lifecycle settings (create_before_destroy, prevent_destroy). Use terraform refresh to sync the state with the actual infrastructure before checking the plan.

10. **Upgrade EKS Cluster**
  - Review the kubernetes release notes, check for deprecated apis, ensure all addons (vpc cni, coredns, kube-proxy) are compatible with the target version. Perform a full test upgrade in the staging environment before upgrading prod cluster.
  - Upgrade the EKS control plane to the next minor version, then update any managed node groups and self‑managed nodes, followed by upgrading critical add‑ons (vpc cni, coredns, kube‑proxy, aws load balancer controller). Cordon and drain existing nodes to safely evict workloads before terminating them.
  - After the upgrade, verify cluster health and application functionality. If critical issues occur within 5 days of the upgrade, roll back the control plane to the previous version using the AWS Management Console, CLI, or API.

11. **Frontend loads, but backend API calls fail**
  - Verify that the frontend is using the correct API endpoint URL, check environment variables
  - Check if the backend service is exposed correctly via Ingress or Service
  - Use browser DevTools for network errors (404, 500, CORS errors)

12. **Backend pod is running, but database connection times out**
  - Verify database security group rules allow inbound traffic from EKS node security group on the database port
  - Confirm the database endpoint and port are correct in the backend configuration
  - Check if the database is in a healthy state (RDS status, CPU/memory utilization, Slow Query)

13. **Private DNS is not resolving database hostname**
  - Verify that the Route 53 Private Hosted Zone is associated with the correct VPC
  - Check if the A record exists in the private hosted zone
  - Confirm that VPC DNS settings (enable_dns_hostnames and enable_dns_support) are enabled

14. **Rotate database credentials safely**
  - Use AWS Secrets Manager with automatic rotation enabled
  - Use IRSA with EKS to retrieve credentials at runtime, and rotate without restarting the application
  - For manual rotation: create a new secret version with the new password, update the application to use the new version, and test connectivity
  - After validation, retire the old secret version and ensure no applications are using it

15. **Secrets were accidentally committed to GitHub**
  - Immediately revoke the secrets and rotate them (e.g.change passwords, regenerate API keys)
  - Remove the secrets from the repository history using git filter-branch 
  - Force push the cleaned history to GitHub and invalidate any exposed credentials