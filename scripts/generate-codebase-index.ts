#!/usr/bin/env ts-node

import * as fs from 'fs';
import * as path from 'path';
import { promisify } from 'util';
import { exec } from 'child_process';

const writeFile = promisify(fs.writeFile);
const execPromise = promisify(exec);

interface FileIndex {
  path: string;
  category: string;
  lines: number;
  size: number;
  lastModified: string;
  language: string;
}

const IGNORED_DIRS = ['node_modules', '.git', 'dist', 'build', '.next', '.turbo', 'coverage'];
const CODE_EXTENSIONS = ['.ts', '.tsx', '.js', '.jsx', '.swift', '.sql', '.json'];

async function generateIndex() {
  console.log('🔍 Generating codebase index...');
  
  const { stdout } = await execPromise(
    `find . -type f \\( ${CODE_EXTENSIONS.map(ext => `-name "*${ext}"`).join(' -o ')} \\) | grep -v ${IGNORED_DIRS.map(d => `-e "/${d}/"`).join(' ')} | xargs wc -l | sort -rn`
  );
  
  const lines = stdout.split('\n').filter(Boolean);
  const files: FileIndex[] = [];
  
  for (const line of lines) {
    const match = line.match(/^\s*(\d+)\s+(.+)$/);
    if (match && match[2] !== 'total') {
      const [, lineCount, filePath] = match;
      const cleanPath = filePath.replace('./', '');
      
      // Get file stats
      const stats = fs.statSync(cleanPath);
      
      files.push({
        path: cleanPath,
        category: categorizeFile(cleanPath),
        lines: parseInt(lineCount),
        size: stats.size,
        lastModified: stats.mtime.toISOString(),
        language: getLanguage(cleanPath)
      });
    }
  }
  
  const index = {
    generated: new Date().toISOString(),
    totalFiles: files.length,
    totalLines: files.reduce((sum, f) => sum + f.lines, 0),
    totalSize: files.reduce((sum, f) => sum + f.size, 0),
    categories: groupByCategory(files),
    topFiles: files.slice(0, 20),
    files: files
  };
  
  await writeFile('CODEBASE_INDEX.json', JSON.stringify(index, null, 2));
  console.log('✅ Generated CODEBASE_INDEX.json');
  
  // Generate quick reference file
  const quickRef = `# VibeZ Codebase Quick Reference

## Statistics
- Total Files: ${index.totalFiles}
- Total Lines: ${index.totalLines.toLocaleString()}
- Total Size: ${(index.totalSize / 1024 / 1024).toFixed(2)} MB

## Largest Files
${files.slice(0, 10).map(f => `- ${f.path} (${f.lines} lines)`).join('\n')}

## File Types
${Object.entries(groupByExtension(files))
  .sort((a, b) => b[1] - a[1])
  .map(([ext, count]) => `- ${ext}: ${count} files`)
  .join('\n')}

## Quick Links
- [Full Documentation](./CODEBASE_COMPLETE.md)
- [HTML Version](./CODEBASE_COMPLETE.html)
- [JSON Index](./CODEBASE_INDEX.json)
`;
  
  await writeFile('CODEBASE_QUICKREF.md', quickRef);
  console.log('✅ Generated CODEBASE_QUICKREF.md');
}

function categorizeFile(filePath: string): string {
  if (filePath.includes('/services/')) return 'Backend Services';
  if (filePath.includes('/routes/')) return 'API Routes';
  if (filePath.includes('/middleware/')) return 'Middleware';
  if (filePath.includes('/ws/')) return 'WebSocket';
  if (filePath.includes('/frontend/iOS/')) return 'iOS Frontend';
  if (filePath.includes('/v-app/')) return 'Next.js Frontend';
  if (filePath.includes('.sql') || filePath.includes('/sql/')) return 'Database/SQL';
  if (filePath.includes('/types/')) return 'TypeScript Types';
  if (filePath.includes('/config/')) return 'Configuration';
  if (filePath.includes('/test') || filePath.includes('.test.')) return 'Tests';
  return 'Other';
}

function getLanguage(filePath: string): string {
  const ext = path.extname(filePath);
  const langMap: Record<string, string> = {
    '.ts': 'TypeScript',
    '.tsx': 'TypeScript React',
    '.js': 'JavaScript',
    '.jsx': 'JavaScript React',
    '.swift': 'Swift',
    '.sql': 'SQL',
    '.json': 'JSON'
  };
  return langMap[ext] || 'Unknown';
}

function groupByCategory(files: FileIndex[]): Record<string, number> {
  return files.reduce((acc, file) => {
    acc[file.category] = (acc[file.category] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);
}

function groupByExtension(files: FileIndex[]): Record<string, number> {
  return files.reduce((acc, file) => {
    const ext = path.extname(file.path);
    acc[ext] = (acc[ext] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);
}

generateIndex().catch(console.error);
