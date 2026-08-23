# Guide: Splitting PR into Two Separate PRs

Based on the maintainer feedback, this PR needs to be split into two separate PRs to allow independent review and discussion.

## Current Situation

Branch: `add-supply-chain-deception-skills`
Commit: Latest changes condensed both skills and added negative-trigger descriptions

## Option 1: Create Two New Branches (Recommended)

This approach creates fresh PRs while preserving your authorship:

### Step 1: Create Branch for Dependency Confusion Skill

```bash
# From main branch
git checkout main
git pull origin main

# Create new branch for first skill
git checkout -b add-dependency-confusion-detection

# Cherry-pick only the dependency confusion files
git checkout add-supply-chain-deception-skills -- \
  skills/detecting-dependency-confusion-attacks/

# Stage and commit
git add skills/detecting-dependency-confusion-attacks/
git commit -m "Add skill: detecting-dependency-confusion-attacks

Detects and prevents dependency confusion attacks with advanced
behavioral detection including install script analysis and runtime
monitoring. Complements existing detecting-dependency-confusion skill
with:
- Phase 4: Install script behavior analysis (malicious postinstall detection)
- Phase 6: Behavioral monitoring (Socket.dev, Snyk integration)
- Automated detection of 2026 attack campaigns (Mini Shai-Hulud, TanStack)

Mapped to MITRE ATT&CK T1195.002 and NIST CSF supply chain controls."

# Push to your fork
git push origin add-dependency-confusion-detection
```

**Then create PR #1 with title**: `Add skill: detecting-dependency-confusion-attacks`

### Step 2: Create Branch for AD Honeytokens Skill

```bash
# From main branch
git checkout main

# Create new branch for second skill
git checkout -b add-ad-honeytokens-detection

# Cherry-pick only the AD honeytokens files
git checkout add-supply-chain-deception-skills -- \
  skills/deploying-ad-honeytokens-for-detection/

# Stage and commit
git add skills/deploying-ad-honeytokens-for-detection/
git commit -m "Add skill: deploying-ad-honeytokens-for-detection

Extends deploying-active-directory-honeytokens with broader SIEM
coverage and advanced detection scenarios:
- Multi-SIEM templates: Graylog, QRadar, LogRhythm, OSSIM (vs. Splunk/Sentinel only)
- ACL honeypots: Fake BloodHound permissions (GenericAll traps)
- DCSync detection: Event 4662 replication request monitoring
- Golden Ticket detection: Unusual TGT lifetime alerts

Mapped to MITRE ATT&CK T1003, T1558 and D3FEND D3-DUC."

# Push to your fork
git push origin add-ad-honeytokens-detection
```

**Then create PR #2 with title**: `Add skill: deploying-ad-honeytokens-for-detection`

## Option 2: Maintainer Splits From Your Branch

If you prefer, simply respond to the PR feedback:

```
Thanks for the detailed feedback. I've made the required changes:

✅ Condensed detecting-dependency-confusion-attacks: 742→381 lines
✅ Condensed deploying-ad-honeytokens-for-detection: 586→300 lines  
✅ Added negative-trigger descriptions for both skills
✅ Both skills pass validation

I'm happy to split this into two PRs as you suggested. Would you prefer:
1. I create two new branches and PRs from the updated commits, or
2. You split from this branch and preserve my commits/authorship?

For the dependency-confusion skill, the unique value is Phase 4 (install 
script analysis) and Phase 6 (behavioral monitoring). For AD honeytokens,
it's the multi-SIEM templates and DCSync/Golden Ticket phases.

Let me know your preference and I'll proceed accordingly within 14 days.
```

## PR Descriptions

### PR #1: detecting-dependency-confusion-attacks

**Title**: Add skill: detecting-dependency-confusion-attacks

**Description**:
```markdown
Adds advanced dependency confusion detection skill focused on behavioral 
analysis and runtime monitoring.

## Differentiation from existing `detecting-dependency-confusion`

The existing skill covers fundamental registry configuration and namespace 
claiming with `confused`/`dep-scan`. This skill extends that foundation with:

### Unique Contributions

1. **Phase 4: Install Script Behavior Analysis**
   - Detects 2026 attack campaigns (Mini Shai-Hulud, TanStack compromise)
   - Analyzes postinstall/preinstall hooks for exfiltration payloads
   - Includes `scripts/analyze_install_scripts.py` for automated analysis

2. **Phase 6: Behavioral Monitoring** 
   - Socket.dev integration for runtime detection
   - Snyk behavioral analysis
   - Network monitoring during package installation

3. **2026 Attack Intelligence**
   - Microsoft-documented reconnaissance payloads
   - Real-world IOCs and deobfuscated payloads
   - SIEM correlation rules

## Validation

- ✅ Passes `tools/validate-skill.py`
- ✅ 381 body lines (under 500 limit)
- ✅ Negative-trigger description points to existing skill
- ✅ MITRE ATT&CK T1195.002, NIST CSF SR.1-01/SR.2-01

## Related

Complements `detecting-dependency-confusion` - use that skill first for 
foundational configuration, then this skill for advanced detection.
```

### PR #2: deploying-ad-honeytokens-for-detection

**Title**: Add skill: deploying-ad-honeytokens-for-detection

**Description**:
```markdown
Extends AD honeytoken deployment with broader SIEM coverage and advanced 
attack detection scenarios.

## Differentiation from existing `deploying-active-directory-honeytokens`

The existing skill covers core honeytoken deployment (decoy accounts, SPNs,
GPO traps) with Splunk/Sentinel detection. This skill extends with:

### Unique Contributions

1. **Multi-SIEM Coverage** (`assets/siem-rules-templates.md`)
   - Graylog, QRadar, LogRhythm, OSSIM templates
   - Existing skill: Splunk, Sentinel only
   - Enables deployment in diverse SOC environments

2. **ACL Honeypots** (Phase 6)
   - Fake GenericAll permissions visible to BloodHound
   - Event 4662 detection for BloodHound-guided attacks
   - Not covered in existing skill

3. **DCSync & Golden Ticket Detection** (Phase 7)
   - Event 4662 replication request monitoring
   - Unusual TGT lifetime alerts
   - Post-compromise persistence detection

## Alternative: Merge into Existing Skill?

I acknowledge overlap with `deploying-active-directory-honeytokens`. If you 
prefer, the multi-SIEM templates, ACL honeypots, and DCSync phases could be 
merged into the existing skill rather than maintaining a separate one.

## Validation

- ✅ Passes `tools/validate-skill.py`  
- ✅ 300 body lines (under 500 limit)
- ✅ Negative-trigger description points to existing skill
- ✅ MITRE ATT&CK T1003, T1558; D3FEND D3-DUC

Open to feedback on whether this should be:
- Separate skill (current approach)
- Merged into existing `deploying-active-directory-honeytokens`
```

## Important Notes

1. **Do NOT open both PRs simultaneously** - Open PR #1 first, wait for feedback
2. **Address the index.json regeneration** - The maintainer mentioned this but the tool doesn't exist yet in the repo. May need manual update or wait for guidance.
3. **14-day response window** - Maintainer will close as stale if no response within 14 days
4. **Authorship preserved** - Using `git checkout` + `git commit` preserves your authorship

## Checklist Before Opening PRs

- [ ] Both skills condensed to <500 body lines
- [ ] Negative-trigger descriptions added
- [ ] Both skills pass validation
- [ ] Unique value propositions clearly documented
- [ ] PR descriptions explain differentiation from existing skills
- [ ] scripts/ and assets/ directories included
- [ ] Ready to address index.json if requested
