# GitHub to GitLab Migration Guide

This guide covers migrating from GitHub Actions to GitLab CI/CD to address security concerns with self-hosted runners on public repositories.

## Why Migrate?

### GitHub Security Issue
GitHub displays this warning for public repositories with self-hosted runners:

> ⚠️ **Using self-hosted runners in public repositories is not recommended.** Forks of your public repository can potentially run dangerous code on your self-hosted runner by creating a pull request.

### GitLab Security Benefits
- ✅ **Fork MR pipelines disabled by default** for external contributors
- ✅ **Manual approval required** for external merge request pipelines
- ✅ **Repository can remain public** for team collaboration
- ✅ **Granular access controls** for runner usage
- ✅ **Better environment protection** mechanisms

## Migration Steps

### 1. Create GitLab Repository

1. Go to **gitlab.com/stetter-homelab**
2. Create new project: **talos-terraform-poc**
3. Set visibility to **Public**

### 2. Push Code to GitLab

```bash
# Add GitLab remote
git remote add gitlab git@gitlab.com:stetter-homelab/talos-terraform-poc.git

# Push all branches and tags
git push gitlab --all
git push gitlab --tags
```

### 3. Install GitLab Runner

On **core.rsdn.io**:

```bash
# Remove GitHub Actions runner if installed
sudo systemctl stop github-runner
sudo systemctl disable github-runner
sudo userdel -r github-runner  # Optional: remove user

# Install GitLab runner
sudo ./scripts/setup-gitlab-runner.sh

# Register runner (get token from GitLab project settings)
sudo gitlab-runner register \
  --url https://gitlab.com/ \
  --registration-token YOUR_TOKEN \
  --name core-runner \
  --tag-list homelab,linux,proxmox \
  --executor shell

# Start service
systemctl enable gitlab-runner
systemctl start gitlab-runner
```

### 4. Configure GitLab Variables

**Project Settings → CI/CD → Variables**:

| Variable | Value | GitHub Equivalent |
|----------|--------|------------------|
| `PROXMOX_API_TOKEN` | `terraform@pve!terraform=SECRET` | Repository Secret |
| `TF_VAR_proxmox_endpoint` | `https://192.168.1.5:8006/` | Environment Variable |

### 5. Set Up Security Controls

#### Protected Branches
**Project Settings → Repository → Protected Branches**
- Protect `main` branch
- Require maintainer permissions for push/merge

#### Environment Protection
**Project Settings → CI/CD → Environments**
- Create `production` environment
- Enable **Protected environment**
- Require manual approval for deployments

#### Fork Pipeline Control
**Project Settings → CI/CD → General pipelines**
- Set **Fork pipelines** to manual approval

### 6. Test Migration

1. **Create test MR** in GitLab
2. **Verify dev pipeline** runs automatically
3. **Merge to main** and verify production pipeline
4. **Test external fork** security controls

### 7. Update Team References

- Update documentation links
- Notify team of new repository location
- Update CI/CD status badges
- Archive or delete GitHub repository

## Conversion Reference

### Workflow Syntax

#### GitHub Actions
```yaml
name: Deploy Production
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: [self-hosted, linux, homelab]
    environment: production
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        run: terraform apply
        env:
          PROXMOX_TOKEN: ${{ secrets.PROXMOX_API_TOKEN }}
```

#### GitLab CI/CD
```yaml
stages:
  - deploy
deploy-prod:
  stage: deploy
  tags: [homelab, linux, proxmox]
  environment:
    name: production
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual
  script:
    - terraform apply
  variables:
    PROXMOX_TOKEN: $PROXMOX_API_TOKEN
```

### Key Differences

| Feature | GitHub Actions | GitLab CI/CD |
|---------|----------------|--------------|
| **Configuration** | `.github/workflows/` | `.gitlab-ci.yml` |
| **Runner Selection** | `runs-on: [tags]` | `tags: [list]` |
| **Manual Approval** | Environment protection | `when: manual` |
| **Secrets** | Repository secrets | Project variables |
| **Artifacts** | `upload-artifact` | `artifacts:` section |
| **Environment URLs** | `environment: url:` | `environment: url:` |

### Security Model

| Aspect | GitHub | GitLab |
|--------|---------|---------|
| **Fork PRs** | Run automatically | Manual approval |
| **External Contributors** | Full runner access | Restricted by default |
| **Environment Protection** | Repository settings | Project + pipeline rules |
| **Runner Isolation** | Limited options | Comprehensive controls |

## Testing Security

### Test External Fork Security

1. **Fork repository** from different GitLab account
2. **Create malicious MR** with dangerous script
3. **Verify pipeline requires approval** and doesn't run automatically
4. **Test approval workflow** works correctly

### Test Environment Protection

1. **Push to main branch** with terraform changes
2. **Verify production job** requires manual approval
3. **Test approval process** and deployment execution
4. **Validate cluster credentials** are properly handled

## Rollback Plan

If migration issues occur:

### Quick Rollback
```bash
# Revert to GitHub workflow temporarily
git checkout main
git revert <migration-commit>
git push origin main

# Re-enable GitHub runner if needed
sudo systemctl enable github-runner
sudo systemctl start github-runner
```

### Full Rollback
1. **Archive GitLab repository**
2. **Restore GitHub repository** from archive
3. **Re-configure GitHub secrets** and environments
4. **Update team references** back to GitHub

## Post-Migration Checklist

- [ ] GitLab repository created and populated
- [ ] GitLab runner installed and registered
- [ ] Security controls configured and tested
- [ ] Team notified of new repository location
- [ ] Documentation updated with GitLab references
- [ ] External references updated (badges, links)
- [ ] GitHub repository archived or deleted
- [ ] Deployment pipeline tested end-to-end
- [ ] Security tested with external fork simulation

## Benefits Realized

After successful migration:

✅ **Enhanced Security**: External contributions can't execute arbitrary code
✅ **Public Repository**: Team can still access and contribute
✅ **Better Controls**: Granular permissions and environment protection  
✅ **Professional Workflow**: Industry-standard GitOps practices
✅ **Risk Mitigation**: Production infrastructure protected from malicious code

## Support

For migration issues:
- Review GitLab CI/CD documentation
- Check runner logs: `journalctl -u gitlab-runner -f`
- Test pipeline locally with GitLab CLI tools
- Validate security controls with fork testing

The migration provides significant security improvements while maintaining team collaboration capabilities.