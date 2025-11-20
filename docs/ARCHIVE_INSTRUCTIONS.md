# Archive Instructions for Historical Documentation

This document provides instructions for archiving the `docs/archive/` directory to a separate repository.

## Purpose

The `docs/archive/` directory contains historical documentation, completion summaries, test reports, and validation documents that are no longer actively used but should be preserved for:
- Historical reference
- IP documentation
- Acquisition due diligence
- Lessons learned documentation

## Archive Process

### Option 1: Create Separate Archive Repository (Recommended)

1. **Create a new repository** (e.g., `Ghostmonday/VibeZ-archive` or `VibeZ-archive`)
   ```bash
   # On GitHub/GitLab, create a new private repository
   ```

2. **Export the archive directory**
   ```bash
   cd /path/to/VibeZ
   git subtree push --prefix=docs/archive origin archive-branch
   # Or use git filter-branch if you prefer
   ```

3. **Alternative: Manual export**
   ```bash
   # Create archive directory
   mkdir -p /tmp/vibez-archive
   cp -r docs/archive/* /tmp/vibez-archive/
   
   # Initialize git repo
   cd /tmp/vibez-archive
   git init
   git add .
   git commit -m "Initial archive export from VibeZ main repo"
   
   # Add remote and push
   git remote add origin <archive-repo-url>
   git push -u origin main
   ```

4. **Update main repository**
   - After archiving, remove `docs/archive/` from main repo
   - Update `handover.md` with link to archive repository
   - The `.gitignore` already ignores `docs/archive/` (line 44)

### Option 2: Git Subtree (Advanced)

If you want to keep the archive as part of the main repo but in a separate branch:

```bash
git subtree split --prefix=docs/archive -b archive-branch
git push origin archive-branch
```

## Archive Repository Structure

The archive repository should maintain the same structure:
```
VibeZ-archive/
├── historical/
│   ├── PHASE3_COMPLETION_SUMMARY.md
│   ├── PHASE5_COMPLETION.md
│   ├── TEST_RESULTS_SUMMARY.md
│   └── ... (all historical files)
├── CODEBASE_COMPLETE.html
├── CONSOLIDATED_DOCUMENTATION.md
└── README.md (archive repository README)
```

## Archive Repository README Template

```markdown
# VibeZ Historical Documentation Archive

This repository contains archived historical documentation from the VibeZ project.

## Contents

- **historical/**: Historical completion summaries, test reports, and validation documents
- **Root files**: Consolidated documentation and codebase snapshots

## Purpose

These documents are preserved for:
- Historical reference
- IP documentation
- Acquisition due diligence
- Lessons learned

## Last Updated

Archived from main VibeZ repository on: [DATE]

## Access

This archive is maintained separately from the main VibeZ codebase. For current documentation, see the main repository.
```

## After Archiving

Once the archive is created and pushed:

1. Remove `docs/archive/` from main repository:
   ```bash
   git rm -r docs/archive/
   git commit -m "Remove archived documentation (moved to separate archive repo)"
   ```

2. Update `handover.md` to reference the archive:
   ```markdown
   ## Historical Documentation
   
   Historical documentation, completion summaries, and old test reports have been archived to a separate repository: [VibeZ-archive](https://github.com/Ghostmonday/VibeZ-archive)
   ```

3. Verify `.gitignore` includes `docs/archive/` (already present on line 44)

## Notes

- The archive repository can be private if it contains sensitive information
- Consider adding a README to the archive repo explaining its purpose
- Archive repository can be used for creating "lessons learned" documentation or e-books
- Keep archive repository updated if you continue to archive historical docs



