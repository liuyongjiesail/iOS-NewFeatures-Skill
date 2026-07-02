#!/usr/bin/env node

/**
 * iOS New Features Skill - Validation Script
 * Checks documentation quality and completeness
 */

const fs = require('fs');
const path = require('path');

const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

const referenceDir = path.join(__dirname, '..', 'skills', 'ios-new-features', 'reference');
const skillFile = path.join(__dirname, '..', 'skills', 'ios-new-features', 'SKILL.md');

let errors = 0;
let warnings = 0;

function validateFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const fileName = path.basename(filePath);

  log(`\n📄 Validating: ${fileName}`, 'blue');

  // Check for required sections
  const requiredSections = ['Quick Example', 'Key APIs', 'Important Notes'];
  const missingSections = requiredSections.filter(section =>
    !content.includes(`## ${section}`)
  );

  if (missingSections.length > 0) {
    log(`  ⚠️  Missing sections: ${missingSections.join(', ')}`, 'yellow');
    warnings++;
  }

  // Check for code blocks
  const codeBlocks = content.match(/```swift/g);
  if (!codeBlocks || codeBlocks.length === 0) {
    log('  ❌ No Swift code examples found', 'red');
    errors++;
  } else {
    log(`  ✅ Found ${codeBlocks.length} code examples`, 'green');
  }

  // Check for iOS version
  const versionMatch = content.match(/iOS \d+\+|macOS \d+\+|visionOS \d+\+/);
  if (!versionMatch) {
    log('  ⚠️  No iOS/macOS/visionOS version specified', 'yellow');
    warnings++;
  }

  // Check for WWDC reference
  const wwdcMatch = content.match(/WWDC \d{4}/);
  if (!wwdcMatch) {
    log('  ℹ️  No WWDC session reference', 'blue');
  }

  // Check file size
  const sizeKB = Buffer.byteLength(content, 'utf-8') / 1024;
  if (sizeKB < 2) {
    log(`  ⚠️  File seems too small (${sizeKB.toFixed(1)} KB)`, 'yellow');
    warnings++;
  }
}

function validateIndex() {
  log('\n📋 Validating Feature Index...', 'blue');

  const skillContent = fs.readFileSync(skillFile, 'utf-8');
  const referenceFiles = fs.readdirSync(referenceDir)
    .filter(f => f.endsWith('.md'))
    .map(f => f.replace('.md', ''));

  // Check if all reference files are listed in index
  const missingInIndex = referenceFiles.filter(fileName => {
    const refPath = `reference/${fileName}.md`;
    return !skillContent.includes(refPath);
  });

  if (missingInIndex.length > 0) {
    log('  ❌ Files not listed in index:', 'red');
    missingInIndex.forEach(f => log(`     - ${f}.md`, 'red'));
    errors++;
  } else {
    log('  ✅ All reference files are indexed', 'green');
  }

  // Check for broken links in index
  const linkMatches = [...skillContent.matchAll(/\[reference\/(.+?)\.md\]/g)];
  const brokenLinks = linkMatches.filter(match => {
    const fileName = match[1];
    return !referenceFiles.includes(fileName);
  });

  if (brokenLinks.length > 0) {
    log('  ❌ Broken links in index:', 'red');
    brokenLinks.forEach(match => log(`     - ${match[1]}.md`, 'red'));
    errors++;
  }
}

async function validate() {
  log('\n========================================', 'blue');
  log('  iOS New Features Skill Validator', 'blue');
  log('========================================', 'blue');

  // Validate each reference file
  const files = fs.readdirSync(referenceDir).filter(f => f.endsWith('.md'));

  log(`\n🔍 Found ${files.length} reference files`, 'blue');

  files.forEach(file => {
    validateFile(path.join(referenceDir, file));
  });

  // Validate index
  validateIndex();

  // Summary
  log('\n========================================', 'blue');
  log('  Validation Summary', 'blue');
  log('========================================', 'blue');
  log(`\n📊 Files checked: ${files.length}`);
  log(`❌ Errors: ${errors}`, errors > 0 ? 'red' : 'green');
  log(`⚠️  Warnings: ${warnings}`, warnings > 0 ? 'yellow' : 'green');

  if (errors === 0 && warnings === 0) {
    log('\n✅ All checks passed!\n', 'green');
  } else if (errors === 0) {
    log('\n⚠️  Validation completed with warnings\n', 'yellow');
  } else {
    log('\n❌ Validation failed with errors\n', 'red');
    process.exit(1);
  }
}

validate().catch(error => {
  log(`\n❌ Error: ${error.message}\n`, 'red');
  process.exit(1);
});
