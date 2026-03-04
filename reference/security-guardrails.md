# Security Guardrails for Agent Teams
> Preventive controls to stop agents from accidentally (or through prompt injection)
> executing dangerous operations. Based on OWASP AI Agent Security Top 10 (2025).
>
> These guardrails use **PreToolUse** hooks that fire before every tool execution,
> allowing you to block or warn on dangerous operations before they happen.

---

## 1. Dangerous Command Blocking

Block shell commands that can cause irreversible damage.

**Hook Configuration** (add to `settings.json`):
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": { "tool_name": "Bash" },
        "hooks": [{
          "type": "command",
          "command": "./scripts/security-check.sh"
        }]
      }
    ]
  }
}
```

**Patterns to block** (exit 1 = hard block):
| Pattern | Risk | Action |
|---------|------|--------|
| `rm -rf /` or `rm -rf ~` | System destruction | Block |
| `DROP TABLE`, `DROP DATABASE` | Data loss | Block |
| `git push --force` to main/master | History destruction | Block |
| `chmod 777` | Security exposure | Block |
| `curl \| sh`, `wget \| bash` | Remote code execution | Block |
| `> /dev/sda`, `dd if=` | Disk destruction | Block |
| `:(){ :\|:& };:` | Fork bomb | Block |
| `kill -9 1`, `shutdown`, `reboot` | System disruption | Block |

## 2. Sensitive File Protection

Prevent agents from reading or writing files containing secrets.

**Protected patterns**:
- `.env`, `.env.*` — Environment variables with secrets
- `credentials.*`, `secrets.*` — Credential files
- `*.pem`, `*.key`, `*.p12` — Certificates and private keys
- `id_rsa`, `id_ed25519` — SSH keys
- `*.keystore`, `*.jks` — Java keystores
- `secrets/`, `.secrets/` — Secret directories

**Hook approach**: PreToolUse matcher for `Read`, `Edit`, `Write` tools. Check `$CLAUDE_TOOL_INPUT` for protected patterns. Exit 1 to block, exit 2 to warn.

## 3. Path Traversal Prevention

Block file operations that use `../` to escape intended directories.

**Why it matters**: A prompt injection in a file could instruct the agent to read `../../../etc/passwd` or write to files outside the project. Path traversal is the #3 OWASP AI Agent risk.

**Check**: Resolve all paths to absolute and verify they start with the project root.

**Implementation**: See `scripts/security-file-check.sh` for a ready-to-use PreToolUse hook that blocks path traversal and sensitive file access.

## 4. Sensitive Data Detection

Warn when agents write code containing hardcoded secrets.

**Patterns to detect** (exit 2 = warn, don't block):
| Pattern | Example |
|---------|---------|
| API keys | `AKIA[0-9A-Z]{16}` (AWS), `sk-[a-zA-Z0-9]{48}` (OpenAI) |
| Passwords | `password\s*=\s*["'][^"']+["']` |
| Tokens | `token\s*=\s*["'][a-zA-Z0-9]{20,}["']` |
| Private keys | `-----BEGIN (RSA\|EC\|OPENSSH) PRIVATE KEY-----` |
| Connection strings | `mongodb\+srv://.*:.*@`, `postgres://.*:.*@` |

**Action**: Print warning with file and line number. Let agent continue but flag for human review.

## 5. Network Safety

Warn on requests to internal or sensitive endpoints.

**Patterns to flag**:
- `localhost`, `127.0.0.1`, `0.0.0.0` — Local services
- `169.254.169.254` — Cloud metadata endpoint (AWS/GCP/Azure credential theft)
- `10.*`, `172.16-31.*`, `192.168.*` — Internal network ranges
- Any URL with credentials in the path (`https://user:pass@host`)

## Implementation Example

A minimal security check script (`./agent-team-templates/scripts/security-check.sh`):

```bash
#!/bin/bash
# PreToolUse security check — blocks dangerous Bash commands
INPUT="${CLAUDE_TOOL_INPUT:-}"

# Dangerous patterns (exit 1 = block)
BLOCKED_PATTERNS=(
  'rm -rf /'
  'rm -rf ~'
  'DROP TABLE'
  'DROP DATABASE'
  'git push.*--force.*main'
  'git push.*--force.*master'
  'chmod 777'
  'curl.*|.*sh'
  'wget.*|.*bash'
  '> /dev/sd'
  'mkfs\.'
  'dd if='
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$INPUT" | grep -qiE "$pattern"; then
    echo "BLOCKED: Dangerous command detected matching pattern: $pattern"
    echo "If this is intentional, run the command manually outside Claude Code."
    exit 1
  fi
done

exit 0
```

---

## Integration with Settings

Add to your `settings-template.json`:
```json
"PreToolUse": [
  {
    "matcher": { "tool_name": "Bash" },
    "hooks": [{
      "type": "command",
      "command": "./agent-team-templates/scripts/security-check.sh"
    }]
  }
]
```

> **Note**: These are preventive controls, not a complete security solution.
> Always review agent-produced code before deploying to production.
> See OWASP AI Agent Security Top 10 for the full threat model.
