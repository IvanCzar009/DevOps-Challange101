# 🔄 Kibana Port Change Summary: 5601 → 5061

## ✅ **Files Updated Successfully:**

### **1. Core Installation Scripts:**
- ✅ `install-elk.sh` - Updated Docker port mapping from `"5601:5601"` to `"5061:5601"`
- ✅ `install-elk.sh` - Updated service check URLs from `localhost:5601` to `localhost:5061`
- ✅ `install-elk.sh` - Updated final summary URLs

### **2. Management Scripts:**
- ✅ `sequential-install.sh` - Updated Kibana health check from port 5601 to 5061
- ✅ `sequential-install.sh` - Updated final URL display
- ✅ `status.sh` - Updated Kibana endpoint check and display URL
- ✅ `start-services.sh` - Updated Kibana URL display

### **3. Infrastructure Configuration:**
- ✅ `main.tf` - Updated embedded Docker compose port mapping
- ✅ `main.tf` - Updated final deployment URL display

### **4. Documentation:**
- ✅ `PORTS_REFERENCE.md` - Updated all Kibana port references from 5601 to 5061
- ✅ `PORTS_REFERENCE.md` - Updated example URLs and security group rules

### **5. React App Integration:**
- ✅ `deploy-react-app.sh` - Updated Kibana link
- ✅ `group6-react-app/deploy.sh` - Updated Kibana service URL

---

## 🔧 **Technical Changes Made:**

### **Docker Port Mapping:**
```yaml
# BEFORE:
ports:
  - "5601:5601"  # External:Internal

# AFTER:
ports:
  - "5061:5601"  # External:Internal
```

### **Health Check URLs:**
```bash
# BEFORE:
curl http://localhost:5601/api/status

# AFTER:
curl http://localhost:5061/api/status
```

### **Public Access URL:**
```bash
# BEFORE:
http://54.176.13.124:5601

# AFTER:
http://54.176.13.124:5061
```

---

## ⚠️ **Important Notes:**

1. **Internal Container Port**: Still uses 5601 inside the container
2. **External Access Port**: Now uses 5061 for public access
3. **Health Checks**: Container health checks still use internal port 5601
4. **Security Group**: AWS security group was already configured for 5061
5. **Firewall Rules**: user-data.sh was already configured for 5061

---

## 🚀 **What This Means:**

### **For New Deployments:**
- Kibana will be accessible at `http://54.176.13.124:5061`
- All scripts will automatically use the new port
- No manual configuration needed

### **For Existing Deployments:**
- You'll need to restart the ELK stack for the change to take effect
- Run: `cd ~/elk && docker-compose down && docker-compose up -d`
- Update any bookmarks from port 5601 to 5061

### **For AWS Security Group:**
- Port 5061 is already properly configured
- No additional security group changes needed

---

## 🔍 **Verification Commands:**

After redeploying, you can verify the change with:

```bash
# Check Docker port mapping
docker ps | grep kibana

# Test new port access
curl -I http://localhost:5061

# Verify from outside
curl -I http://54.176.13.124:5061
```

---

**✅ All Kibana port references have been successfully updated from 5601 to 5061!**