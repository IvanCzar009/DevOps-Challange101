# Quick GitHub Token Setup Guide

## 🔑 Get Your GitHub Personal Access Token:

1. **Go to GitHub Settings:**
   ```
   https://github.com/settings/tokens
   ```

2. **Generate New Token:**
   - Click "Generate new token (classic)"
   - Note: `DevOps Webhook Setup`
   - Expiration: `30 days` (or your preference)
   - Scopes: ✅ Check `repo` (Full control of private repositories)

3. **Copy the Token** (you'll only see it once!)

4. **Run the Setup Script:**
   ```powershell
   .\setup-github-webhook-automatic.ps1 -GitHubToken "YOUR_TOKEN_HERE"
   ```

## 🚀 Alternative One-Liner Setup:

If you have your token ready, run this command:

```powershell
$token = "YOUR_GITHUB_TOKEN_HERE"
.\setup-github-webhook-automatic.ps1 -GitHubToken $token
```

## ✅ After Setup:

Test the webhook by pushing any change:
```bash
echo "Webhook test" >> README.md
git add README.md  
git commit -m "Test automatic webhook trigger"
git push origin terraform-optimized
```

Jenkins should automatically trigger Build #3! 🎉