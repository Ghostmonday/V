#!/usr/bin/env ts-node

import * as fs from 'fs';
import * as path from 'path';
import { promisify } from 'util';
import { exec } from 'child_process';

const readFile = promisify(fs.readFile);
const writeFile = promisify(fs.writeFile);
const execPromise = promisify(exec);

interface FileInfo {
  path: string;
  content: string;
  lines: number;
  category: string;
}

const IGNORED_DIRS = ['node_modules', '.git', 'dist', 'build', '.next', '.turbo', 'coverage'];
const CODE_EXTENSIONS = ['.ts', '.tsx', '.js', '.jsx', '.swift', '.sql', '.json'];
const OUTPUT_FILE = 'CODEBASE_COMPLETE.md';

async function getAllCodeFiles(dir: string): Promise<string[]> {
  const { stdout } = await execPromise(
    `find "${dir}" -type f \\( ${CODE_EXTENSIONS.map((ext) => `-name "*${ext}"`).join(' -o ')} \\) | grep -v ${IGNORED_DIRS.map((d) => `-e "/${d}/"`).join(' ')} | sort`
  );
  return stdout.split('\n').filter(Boolean);
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

async function processFiles(files: string[]): Promise<Map<string, FileInfo[]>> {
  const categorizedFiles = new Map<string, FileInfo[]>();

  for (const file of files) {
    try {
      const content = await readFile(file, 'utf-8');
      const lines = content.split('\n').length;
      const category = categorizeFile(file);

      const fileInfo: FileInfo = {
        path: file.replace(process.cwd() + '/', ''),
        content,
        lines,
        category,
      };

      if (!categorizedFiles.has(category)) {
        categorizedFiles.set(category, []);
      }
      categorizedFiles.get(category)!.push(fileInfo);
    } catch (error) {
      console.error(`Error reading ${file}:`, error);
    }
  }

  return categorizedFiles;
}

function generateTableOfContents(categories: Map<string, FileInfo[]>): string {
  let toc = '# VibeZ Complete Codebase\n\n';
  toc += `Generated: ${new Date().toISOString()}\n`;
  toc += `Total Categories: ${categories.size}\n\n`;

  toc += '## Table of Contents\n\n';

  // Category overview
  let categoryIndex = 1;
  for (const [category, files] of categories) {
    toc += `${categoryIndex}. [${category}](#${category.toLowerCase().replace(/[^a-z0-9]/g, '-')}) (${files.length} files, ${files.reduce((sum, f) => sum + f.lines, 0)} lines)\n`;
    categoryIndex++;
  }

  toc += '\n---\n\n';

  // Quick navigation
  toc += '## Quick Navigation\n\n';
  toc += '### Key Files\n';
  const keyFiles = [
    'src/server/index.ts',
    'src/ws/gateway.ts',
    'src/services/user-authentication-service.ts',
    'src/services/message-service.ts',
    'frontend/iOS/VibeZApp.swift',
  ];

  for (const keyFile of keyFiles) {
    toc += `- [${keyFile}](#${keyFile.replace(/[^a-z0-9]/g, '-')})\n`;
  }

  toc += '\n### Search Hints\n';
  toc += '- Authentication: Search for "auth", "jwt", "token"\n';
  toc += '- WebSocket: Search for "ws", "socket", "real-time"\n';
  toc += '- Database: Search for "supabase", "sql", "query"\n';
  toc += '- Frontend: Search for "swift", "view", "component"\n';

  return toc;
}

function generateFileSection(file: FileInfo): string {
  const anchorId = file.path.replace(/[^a-z0-9]/g, '-');
  const extension = path.extname(file.path).slice(1) || 'text';

  return `### <a id="${anchorId}"></a>${file.path}
\`\`\`${extension}
${file.content}
\`\`\`

[↑ Back to ${file.category}](#${file.category.toLowerCase().replace(/[^a-z0-9]/g, '-')})

---

`;
}

async function generateCodebaseDoc() {
  console.log('🔍 Scanning codebase...');
  const files = await getAllCodeFiles(process.cwd());
  console.log(`📁 Found ${files.length} code files`);

  console.log('📂 Categorizing files...');
  const categorizedFiles = await processFiles(files);

  console.log('📝 Generating documentation...');
  let output = generateTableOfContents(categorizedFiles);

  // Add category sections
  for (const [category, files] of categorizedFiles) {
    const categoryAnchor = category.toLowerCase().replace(/[^a-z0-9]/g, '-');
    output += `## <a id="${categoryAnchor}"></a>${category}\n\n`;
    output += `**${files.length} files** | **${files.reduce((sum, f) => sum + f.lines, 0)} total lines**\n\n`;

    // List files in category
    output += '### Files\n';
    for (const file of files) {
      output += `- [${file.path}](#${file.path.replace(/[^a-z0-9]/g, '-')}) (${file.lines} lines)\n`;
    }
    output += '\n';

    // Add file contents
    for (const file of files) {
      output += generateFileSection(file);
    }
  }

  // Add statistics
  output += '## Statistics\n\n';
  const totalFiles = Array.from(categorizedFiles.values()).reduce(
    (sum, files) => sum + files.length,
    0
  );
  const totalLines = Array.from(categorizedFiles.values()).reduce(
    (sum, files) => sum + files.reduce((fileSum, f) => fileSum + f.lines, 0),
    0
  );

  output += `- Total Files: ${totalFiles}\n`;
  output += `- Total Lines: ${totalLines}\n`;
  output += `- Average Lines per File: ${Math.round(totalLines / totalFiles)}\n`;

  console.log('💾 Writing to file...');
  await writeFile(OUTPUT_FILE, output);

  // Create HTML version for better navigation
  const htmlOutput = `
<!DOCTYPE html>
<html>
<head>
  <title>VibeZ Codebase</title>
  <style>
    body { font-family: -apple-system, monospace; margin: 40px; }
    pre { background: #f4f4f4; padding: 10px; overflow-x: auto; }
    a { color: #0066cc; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .toc { position: fixed; left: 0; top: 0; width: 300px; height: 100vh; 
           overflow-y: auto; background: #fafafa; padding: 20px; }
    .content { margin-left: 340px; }
    .category { margin-bottom: 30px; }
    details { margin: 10px 0; }
    summary { cursor: pointer; font-weight: bold; }
  </style>
</head>
<body>
  <div class="toc">
    <h2>Navigation</h2>
    ${Array.from(categorizedFiles.entries())
      .map(
        ([category, files]) => `
      <details open>
        <summary>${category} (${files.length})</summary>
        <ul>
          ${files.map((f) => `<li><a href="#${f.path.replace(/[^a-z0-9]/g, '-')}">${path.basename(f.path)}</a></li>`).join('')}
        </ul>
      </details>
    `
      )
      .join('')}
  </div>
  <div class="content">
    ${output.replace(/```(\w+)\n([\s\S]*?)```/g, '<pre><code class="$1">$2</code></pre>')}
  </div>
</body>
</html>`;

  await writeFile('CODEBASE_COMPLETE.html', htmlOutput);

  console.log(`✅ Generated ${OUTPUT_FILE} (${(output.length / 1024 / 1024).toFixed(2)} MB)`);
  console.log(`✅ Generated CODEBASE_COMPLETE.html for better navigation`);
}

// Run the script
generateCodebaseDoc().catch(console.error);
