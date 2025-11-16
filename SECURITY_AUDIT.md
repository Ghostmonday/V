# Security Audit and Penetration Testing Guide

This document outlines the security validation process for the VibeZ application.

## 1. Dependency Security Audit

### Run npm audit
```bash
cd server
npm audit
```

### Fix auto-fixable issues
```bash
npm audit fix
```

### Document manual fixes
- Review `npm audit` output for vulnerabilities that require manual intervention
- Document each vulnerability:
  - Package name and version
  - Severity level (low, moderate, high, critical)
  - Description of vulnerability
  - Recommended fix
  - Status (fixed, pending, accepted risk)

### Example audit workflow
```bash
# Full audit report
npm audit --json > audit-report.json

# Fix automatically fixable issues
npm audit fix

# Review remaining issues
npm audit
```

## 2. Penetration Testing with OWASP ZAP

### Prerequisites
- Install OWASP ZAP: https://www.zaproxy.org/download/
- Deploy application to test environment
- Obtain test API keys and credentials

### Baseline Scan
```bash
# Start ZAP daemon
zap.sh -daemon -host 0.0.0.0 -port 8080 -config api.disablekey=true

# Run baseline scan
zap-cli quick-scan --self-contained --start-options '-config api.disablekey=true' http://localhost:3000
```

### Full Scan (for production)
```bash
# Spider scan
zap-cli spider http://localhost:3000

# Active scan
zap-cli active-scan http://localhost:3000

# Generate report
zap-cli report -o zap-report.html -f html
```

### Test Areas

#### Encryption Implementation
- [ ] Verify Signal Protocol encryption is properly implemented
- [ ] Test that unencrypted messages are rejected in E2E rooms
- [ ] Verify AES-256 encryption for sensitive data
- [ ] Test key rotation and management

#### Rate Limiting
- [ ] Test rate limit enforcement
- [ ] Verify tiered rate limits (free/pro/enterprise)
- [ ] Test rate limit bypass attempts
- [ ] Verify rate limit headers are present

#### SQL Injection Prevention
- [ ] Test all database queries for SQL injection vulnerabilities
- [ ] Verify parameterized queries are used
- [ ] Test input validation on all endpoints
- [ ] Test RLS (Row Level Security) policies

#### Authentication & Authorization
- [ ] Test JWT token validation
- [ ] Verify token expiration
- [ ] Test unauthorized access attempts
- [ ] Verify role-based access control

#### API Security
- [ ] Test CORS configuration
- [ ] Verify HTTPS enforcement
- [ ] Test input validation
- [ ] Verify output encoding

## 3. Manual Security Testing

### Encryption Tests
```bash
# Test Signal Protocol encryption
npm test -- e2e-encryption.test.ts

# Test AES-256 encryption
npm test -- auth-encryption.test.ts
```

### Rate Limiting Tests
```bash
# Test rate limit middleware
npm test -- rateLimit.test.ts
```

### Input Validation Tests
```bash
# Test input validation
npm test -- input-validation.test.ts
```

## 4. Security Checklist

### Code Review Checklist
- [ ] All sensitive data is encrypted at rest
- [ ] All communications use HTTPS/TLS
- [ ] E2E encryption implemented for messages
- [ ] Rate limiting enabled on all endpoints
- [ ] Input validation on all user inputs
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention (output encoding)
- [ ] CSRF protection
- [ ] Secure session management
- [ ] Proper error handling (no information leakage)

### Infrastructure Checklist
- [ ] Secrets stored in vault (not in code)
- [ ] Database access restricted (RLS policies)
- [ ] Redis access restricted
- [ ] Logging configured (no sensitive data)
- [ ] Monitoring and alerting configured
- [ ] Backup and recovery procedures

## 5. Remediation Process

1. **Identify**: Document all security findings
2. **Prioritize**: Rank by severity (Critical > High > Medium > Low)
3. **Fix**: Implement fixes for each finding
4. **Verify**: Re-test to confirm fixes
5. **Document**: Update this document with findings and resolutions

## 6. Regular Security Audits

- **Monthly**: Dependency audit (`npm audit`)
- **Quarterly**: Full penetration test
- **Annually**: Third-party security audit
- **On Release**: Security checklist review

## 7. Reporting Template

```markdown
## Security Audit Report - [Date]

### Summary
- Total vulnerabilities found: X
- Critical: X
- High: X
- Medium: X
- Low: X

### Critical Findings
1. [Finding description]
   - Severity: Critical
   - Impact: [Description]
   - Remediation: [Steps taken]
   - Status: [Fixed/Pending]

### Recommendations
- [Recommendation 1]
- [Recommendation 2]

### Next Steps
- [Action item 1]
- [Action item 2]
```

