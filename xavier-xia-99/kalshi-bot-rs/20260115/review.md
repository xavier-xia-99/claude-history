# Session Review - 2026-01-15

## Major Discovery: Backup Gap

### What Gets Backed Up (Current)
- ✅ `project/.claude/` - Settings, commands, skills (< 5KB)
- ✅ `CLAUDE.md` - Project instructions
- ✅ `review.md` - Session summary

### What's Missing from Backup (CRITICAL GAP)
- ❌ `~/.claude/projects/{project}/` - **Actual conversation history (508KB for this session!)**
- ❌ `~/.claude/debug/` - Debug logs with error traces
- ❌ `~/.claude/history.jsonl` - Global conversation index (306 lines)
- ❌ `~/.claude/shell-snapshots/` - Command execution history
- ❌ `~/.claude/file-history/` - File change tracking

**Impact**: We're backing up configuration but losing the actual conversations, debug info, and command history!

## Session Accomplishments

### 1. Backup Automation Hook Created
- Added PostToolUse hook triggered when `review.md` is written
- Automatically runs: `backup-claude-history.sh --force && rm review.md`
- Eliminates manual backup step - no more forgetting!

### 2. Backup-History Skill Documentation Fixed
- Corrected flow: Generate review.md → Auto-backup → Auto-cleanup
- Removed incorrect "delete before backup" instructions
- Added cleanup behavior documentation

### 3. Permission Configuration Updated
- Added backup script permissions
- Added review.md cleanup permissions
- Consolidated Skill(backup-history) permission

### 4. Discovered Claude Data Structure
```
~/.claude/
├── projects/{project}/{session-id}.jsonl  (508KB - CURRENT SESSION)
├── debug/latest → {session-id}.txt        (33KB - ERRORS/WARNINGS)
├── history.jsonl                          (306 lines - GLOBAL INDEX)
├── shell-snapshots/                       (COMMAND HISTORY)
└── file-history/                          (FILE CHANGES)

project/.claude/
├── settings.local.json                    (PERMISSIONS/HOOKS)
├── commands/                              (CUSTOM COMMANDS)
└── skills/                                (CUSTOM SKILLS)
```

## Critical Issues Found

### 1. Reflection Skill Not Functional
- **Problem**: Skill returns "Launching skill: reflection" but doesn't generate output
- **Root Cause**: reflection skill is an interactive meta-analysis prompt, not an automatic summarizer
- **Evidence**: Multiple invocations, zero review.md files created
- **Workaround**: Manually write review.md using Write tool

### 2. Backup Script Misses Conversation Data
- **Problem**: Only backs up `project/.claude/` (config), not `~/.claude/projects/` (conversations)
- **Impact**: Losing 508KB of conversation history per session
- **Why**: Script was designed for project settings, not global Claude data
- **Fix Needed**: Either:
  - Modify backup script to include `~/.claude/projects/{project}/`
  - Create separate "full backup" vs "config backup" modes

### 3. Context7 MCP Connection Failures
**From debug logs:**
```
ERROR: MCP server "plugin:context7:context7" Connection failed
ERROR: Request was aborted
```
- Context7 available but not reliable
- May explain why doc lookups sometimes fail

### 4. UserPromptSubmit Hooks Create Noise
**Every message shows:**
```
hook success: I have these agents available...
hook success: REPEAT OUTLOUD: I WILL NOT CREATE REDUNDANT FILES...
```
- Typos in messages ("WLL", "APROPRIATE", "SOLTUTION")
- Doesn't enforce behavior, just echoes
- Clutters every interaction

### 5. Skill Execution Distraction Pattern
**Observed behavior:**
1. User invokes `/backup-history`
2. I call reflection skill
3. Reflection skill loads meta-analysis prompt
4. I start analyzing the prompt itself instead of executing backup
5. User redirects: "why aren't we doing the backup?"

**Root cause**: No "stay focused on skill objective" guidance in instructions

## Errors/Warnings from Debug Log
- Context7 MCP connection failures (npm errors)
- Aborted requests during message streaming
- No critical failures, but reliability concerns

## Learnings & Recommendations

### Immediate Actions Needed
1. **Fix backup scope**: Include `~/.claude/projects/{project}/` in backups
2. **Test full backup**: Verify 508KB conversation history gets preserved
3. **Fix reflection skill**: Either make it generate files or document it's interactive-only
4. **Remove noisy hooks**: Delete UserPromptSubmit echo commands

### Documentation Improvements
1. **Add "Skill Execution Protocol"** to CLAUDE.md
   ```markdown
   When skill invoked: Stay focused → Complete objective → Report results
   Do NOT: Analyze the skill itself, get sidetracked, suggest improvements mid-execution
   ```

2. **Document Claude data structure** in backup-history skill
   - Explain `~/.claude/` vs `project/.claude/` distinction
   - Clarify what gets backed up and what doesn't

3. **Add diagnostic handling guidance**
   - When to fix dead code warnings
   - Priority: Errors > Unused imports > Dead code (if not public API)

### Architecture Insights
- **Session size**: 230 lines / 508KB for one session = substantial
- **Debug logs**: Valuable for troubleshooting Context7, MCP, API issues
- **Shell snapshots**: Could be valuable for understanding command patterns
- **File history**: Tracks what changed when (version control supplement)

## Next Steps (Priority Order)
1. ✅ **Create automation hook** (DONE - PostToolUse on review.md)
2. **Expand backup scope** to include ~/.claude/projects/{project}/
3. **Test end-to-end backup** with conversation data
4. **Clean up settings.local.json** (remove noisy hooks, consolidate permissions)
5. **Fix or document reflection skill** limitations
6. **Update CLAUDE.md** with skill execution protocol

## Metrics
- Session length: 230 conversation turns
- Conversation data: 508KB (not currently backed up!)
- Debug logs: 33KB
- Project config: ~5KB (currently backed up)
- Total valuable data: ~546KB per session

## Conclusion
Successfully automated backup triggering, but discovered critical gap: we're backing up 1% of the valuable data (config) and missing 99% (conversations, debug logs, history). Need to expand backup scope urgently.
