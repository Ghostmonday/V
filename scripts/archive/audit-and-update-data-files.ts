#!/usr/bin/env ts-node

import * as fs from 'fs';
import * as path from 'path';
import { promisify } from 'util';
import { exec } from 'child_process';

const readFile = promisify(fs.readFile);
const writeFile = promisify(fs.writeFile);
const stat = promisify(fs.stat);
const execPromise = promisify(exec);

interface DataFile {
  path: string;
  type: 'index' | 'schema' | 'config' | 'other';
  lastModified: Date;
  size: number;
  needsUpdate: boolean;
  reason?: string;
}

async function auditDataFiles(): Promise<DataFile[]> {
  console.log('🔍 Auditing data files...\n');
  
  const dataFiles: DataFile[] = [];
  const now = new Date();
  
  // Key data files to audit
  const filesToCheck = [
    'CODEBASE_INDEX.json',
    'CODEBASE_COMPLETE.md',
    'CODEBASE_COMPLETE.html',
    'CODEBASE_QUICKREF.md',
    'schemas/events.json',
    'CONSOLIDATED_DOCUMENTATION.md'
  ];
  
  for (const filePath of filesToCheck) {
    try {
      const stats = await stat(filePath);
      const fileType = categorizeFile(filePath);
      const ageInHours = (now.getTime() - stats.mtime.getTime()) / (1000 * 60 * 60);
      
      // Determine if update is needed
      let needsUpdate = false;
      let reason = '';
      
      if (filePath.includes('CODEBASE_INDEX') || filePath.includes('CODEBASE_COMPLETE')) {
        // Regenerate if older than 24 hours or if codebase changed significantly
        if (ageInHours > 24) {
          needsUpdate = true;
          reason = `File is ${Math.round(ageInHours)} hours old`;
        }
      }
      
      if (filePath === 'schemas/events.json') {
        // Check if schema is valid JSON
        try {
          const content = await readFile(filePath, 'utf-8');
          JSON.parse(content);
        } catch (e) {
          needsUpdate = true;
          reason = 'Invalid JSON format';
        }
      }
      
      dataFiles.push({
        path: filePath,
        type: fileType,
        lastModified: stats.mtime,
        size: stats.size,
        needsUpdate,
        reason
      });
      
      const status = needsUpdate ? '⚠️  NEEDS UPDATE' : '✅ Up to date';
      console.log(`${status} ${filePath} (${(stats.size / 1024).toFixed(1)}KB, ${Math.round(ageInHours)}h old)`);
      if (reason) console.log(`   Reason: ${reason}`);
    } catch (error) {
      console.log(`❌ Missing: ${filePath}`);
    }
  }
  
  return dataFiles;
}

function categorizeFile(filePath: string): 'index' | 'schema' | 'config' | 'other' {
  if (filePath.includes('INDEX') || filePath.includes('index')) return 'index';
  if (filePath.includes('schema')) return 'schema';
  if (filePath.includes('config')) return 'config';
  return 'other';
}

async function regenerateCodebaseIndex() {
  console.log('\n📊 Regenerating CODEBASE_INDEX.json...');
  try {
    await execPromise('npx ts-node scripts/generate-codebase-index.ts');
    console.log('✅ CODEBASE_INDEX.json regenerated');
  } catch (error) {
    console.error('❌ Error regenerating CODEBASE_INDEX.json:', error);
  }
}

async function regenerateCodebaseDoc() {
  console.log('\n📚 Regenerating CODEBASE_COMPLETE.md...');
  try {
    await execPromise('npx ts-node scripts/generate-codebase-doc.ts');
    console.log('✅ CODEBASE_COMPLETE.md regenerated');
  } catch (error) {
    console.error('❌ Error regenerating CODEBASE_COMPLETE.md:', error);
  }
}

async function validateSchemas() {
  console.log('\n🔍 Validating schema files...');
  
  const schemaFiles = [
    'schemas/events.json'
  ];
  
  for (const schemaPath of schemaFiles) {
    try {
      const content = await readFile(schemaPath, 'utf-8');
      const parsed = JSON.parse(content);
      
      // Basic validation
      if (typeof parsed !== 'object') {
        console.log(`⚠️  ${schemaPath}: Root must be an object`);
        continue;
      }
      
      // Check for common issues
      const keys = Object.keys(parsed);
      if (keys.length === 0) {
        console.log(`⚠️  ${schemaPath}: Empty schema`);
      } else {
        console.log(`✅ ${schemaPath}: Valid (${keys.length} event types)`);
      }
      
      // Validate event structure
      for (const [eventName, eventSchema] of Object.entries(parsed)) {
        if (typeof eventSchema !== 'object') {
          console.log(`⚠️  ${schemaPath}: Event "${eventName}" schema must be an object`);
        }
      }
    } catch (error) {
      console.log(`❌ ${schemaPath}: ${error}`);
    }
  }
}

async function checkCodebaseChanges() {
  console.log('\n🔄 Checking for codebase changes...');
  
  try {
    // Check git status for modified files
    const { stdout } = await execPromise('git status --porcelain 2>/dev/null || echo ""');
    const modifiedFiles = stdout.split('\n').filter(Boolean);
    
    if (modifiedFiles.length > 0) {
      console.log(`📝 Found ${modifiedFiles.length} modified files`);
      console.log('   Index files may need regeneration');
      return true;
    } else {
      console.log('✅ No uncommitted changes');
      return false;
    }
  } catch (error) {
    // Not a git repo or git not available
    console.log('ℹ️  Could not check git status');
    return false;
  }
}

async function main() {
  console.log('🚀 Data Files Audit and Update\n');
  console.log('=' .repeat(50) + '\n');
  
  // Audit existing files
  const dataFiles = await auditDataFiles();
  
  // Check for codebase changes
  const hasChanges = await checkCodebaseChanges();
  
  // Validate schemas
  await validateSchemas();
  
  // Determine what needs updating
  const needsUpdate = dataFiles.filter(f => f.needsUpdate);
  const shouldRegenerate = needsUpdate.length > 0 || hasChanges;
  
  console.log('\n' + '='.repeat(50));
  console.log('\n📋 Summary:');
  console.log(`   Total files audited: ${dataFiles.length}`);
  console.log(`   Files needing update: ${needsUpdate.length}`);
  console.log(`   Codebase has changes: ${hasChanges ? 'Yes' : 'No'}`);
  
  if (shouldRegenerate) {
    console.log('\n🔄 Regenerating outdated files...\n');
    
    // Regenerate index files
    if (needsUpdate.some(f => f.path.includes('INDEX'))) {
      await regenerateCodebaseIndex();
    }
    
    // Regenerate documentation
    if (needsUpdate.some(f => f.path.includes('COMPLETE'))) {
      await regenerateCodebaseDoc();
    }
    
    console.log('\n✅ Update complete!');
  } else {
    console.log('\n✅ All data files are up to date!');
  }
  
  console.log('\n' + '='.repeat(50));
}

main().catch(console.error);

