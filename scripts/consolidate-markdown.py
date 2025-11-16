#!/usr/bin/env python3
"""
Consolidate all markdown files into a single document.
"""
import os
import re
from pathlib import Path
from datetime import datetime

def get_file_size(filepath):
    """Get file size in bytes."""
    try:
        return os.path.getsize(filepath)
    except:
        return 0

def read_file_content(filepath):
    """Read file content safely."""
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            return f.read()
    except Exception as e:
        return f"<!-- Error reading file: {e} -->\n"

def consolidate_markdown_files(root_dir, output_file):
    """Consolidate all markdown files into one."""
    
    # Find all markdown files
    md_files = []
    for root, dirs, files in os.walk(root_dir):
        # Skip certain directories
        dirs[:] = [d for d in dirs if d not in ['.git', 'node_modules', 'dist', 'build', '.next']]
        
        for file in files:
            if file.endswith('.md') and file != 'CONSOLIDATED_DOCUMENTATION.md':
                filepath = os.path.join(root, file)
                rel_path = os.path.relpath(filepath, root_dir)
                md_files.append((rel_path, filepath))
    
    # Sort by path for consistent ordering
    md_files.sort(key=lambda x: x[0])
    
    # Create consolidated content
    consolidated = []
    consolidated.append("# VibeZ Consolidated Documentation\n")
    consolidated.append(f"**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    consolidated.append(f"**Purpose**: Complete consolidation of all markdown documentation files\n")
    consolidated.append(f"**Total Files Consolidated**: {len(md_files)}\n")
    consolidated.append("\n---\n\n")
    consolidated.append("## Table of Contents\n\n")
    
    # Build table of contents
    toc_sections = {}
    for rel_path, _ in md_files:
        # Categorize by directory
        parts = rel_path.split(os.sep)
        if len(parts) > 1:
            category = parts[0]
        else:
            category = "Root"
        
        if category not in toc_sections:
            toc_sections[category] = []
        toc_sections[category].append(rel_path)
    
    # Add TOC entries
    section_num = 1
    for category in sorted(toc_sections.keys()):
        consolidated.append(f"{section_num}. [{category}](#{category.lower().replace(' ', '-')})\n")
        section_num += 1
    
    consolidated.append("\n---\n\n")
    
    # Add content by category
    current_category = None
    for category in sorted(toc_sections.keys()):
        consolidated.append(f"# {category}\n\n")
        
        for rel_path in sorted(toc_sections[category]):
            _, filepath = next((p, f) for p, f in md_files if p == rel_path)
            
            # Add file header
            consolidated.append(f"## {rel_path}\n\n")
            consolidated.append(f"**Source**: `{rel_path}`\n\n")
            consolidated.append("---\n\n")
            
            # Read and add content
            content = read_file_content(filepath)
            if content.strip():
                consolidated.append(content)
                if not content.endswith('\n'):
                    consolidated.append('\n')
            else:
                consolidated.append("*(File is empty)*\n")
            
            consolidated.append("\n---\n\n")
    
    # Write consolidated file
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(''.join(consolidated))
    
    print(f"✅ Consolidated {len(md_files)} markdown files into {output_file}")
    print(f"📊 Total size: {get_file_size(output_file) / 1024 / 1024:.2f} MB")
    
    return len(md_files)

if __name__ == '__main__':
    root_dir = '/Users/rentamac/Desktop/VibeZ'
    output_file = '/Users/rentamac/Desktop/VibeZ/CONSOLIDATED_DOCUMENTATION.md'
    
    count = consolidate_markdown_files(root_dir, output_file)
    print(f"\n✅ Done! Consolidated {count} files.")

