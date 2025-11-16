#!/usr/bin/env python3
"""
Delete original markdown files after consolidation.
"""
import os
import re

# Read consolidated file to get list of files that were consolidated
with open('CONSOLIDATED_DOCUMENTATION.md', 'r') as f:
    content = f.read()

# Extract all source file paths
sources = re.findall(r'\*\*Source\*\*: `([^`]+)`', content)
print(f'Found {len(sources)} files in consolidated document')

# Delete each file
deleted = []
not_found = []
errors = []

for source in sources:
    if os.path.exists(source):
        try:
            os.remove(source)
            deleted.append(source)
        except Exception as e:
            errors.append((source, str(e)))
    else:
        not_found.append(source)

print(f'✅ Deleted {len(deleted)} files')
print(f'⚠️  {len(not_found)} files not found (may have been already deleted)')
if errors:
    print(f'❌ {len(errors)} errors:')
    for source, error in errors[:5]:
        print(f'   {source}: {error}')

if deleted:
    print(f'\nSample deleted files:')
    for f in deleted[:10]:
        print(f'   - {f}')

