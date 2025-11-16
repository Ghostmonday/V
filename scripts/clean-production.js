/**
 * Production Build Cleanup
 * Removes dev dependencies, console.logs, debugger statements
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const distDir = path.join(__dirname, '..', 'dist');

function removeConsoleLogs(filePath) {
  let content = fs.readFileSync(filePath, 'utf8');
  let hasIssues = false;
  
  // Remove console.log, console.debug, console.info, console.warn (keep console.error)
  const consoleMatches = content.match(/console\.(log|debug|info|warn)\s*\([^)]*\)\s*;?/g);
  if (consoleMatches && consoleMatches.length > 0) {
    hasIssues = true;
    content = content.replace(/console\.(log|debug|info|warn)\s*\([^)]*\)\s*;?/g, '');
  }
  
  // Remove debugger statements
  if (content.includes('debugger')) {
    hasIssues = true;
    content = content.replace(/debugger\s*;?/g, '');
  }
  
  // Remove TODO and FIXME comments (but keep in source files)
  const todoMatches = content.match(/\/\/\s*(TODO|FIXME):[^\n]*/gi);
  if (todoMatches && todoMatches.length > 0) {
    hasIssues = true;
    content = content.replace(/\/\/\s*(TODO|FIXME):[^\n]*/gi, '');
  }
  
  // Remove multi-line TODO comments
  content = content.replace(/\/\*\s*(TODO|FIXME):[\s\S]*?\*\//g, '');
  
  if (hasIssues) {
    console.log(`Cleaned: ${filePath}`);
  }
  
  fs.writeFileSync(filePath, content, 'utf8');
  return hasIssues;
}

console.log('Cleaning production build...');
let cleanedCount = 0;

function processDirectory(dir) {
  const files = fs.readdirSync(dir);
  
  for (const file of files) {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    
    if (stat.isDirectory()) {
      processDirectory(filePath);
    } else if (file.endsWith('.js')) {
      if (removeConsoleLogs(filePath)) {
        cleanedCount++;
      }
    }
  }
}

processDirectory(distDir);

// Verify no console.log or debugger remain
const verifyClean = (dir) => {
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    if (stat.isDirectory()) {
      verifyClean(filePath);
    } else if (file.endsWith('.js')) {
      const content = fs.readFileSync(filePath, 'utf8');
      if (content.match(/console\.(log|debug|info|warn)/) || content.includes('debugger')) {
        console.warn(`⚠️  Warning: ${filePath} still contains console.log or debugger`);
      }
    }
  }
};

verifyClean(distDir);
console.log(`Production cleanup complete. Cleaned ${cleanedCount} files.`);

