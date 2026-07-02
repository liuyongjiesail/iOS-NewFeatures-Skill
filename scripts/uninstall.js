#!/usr/bin/env node

/**
 * iOS New Features Skill - Uninstall Script
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');

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

function getClaudeSkillsDir() {
  const homeDir = process.env.HOME || process.env.USERPROFILE;
  return path.join(homeDir, '.claude', 'skills', 'ios-new-features');
}

async function askQuestion(query) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  return new Promise(resolve => rl.question(query, ans => {
    rl.close();
    resolve(ans);
  }));
}

async function uninstall() {
  log('\n========================================', 'blue');
  log('  iOS New Features Skill Uninstaller', 'blue');
  log('========================================\n', 'blue');

  const targetDir = getClaudeSkillsDir();

  if (!fs.existsSync(targetDir)) {
    log('ℹ️  Skill is not installed\n', 'yellow');
    return;
  }

  log(`📁 Skill location: ${targetDir}`, 'blue');
  const answer = await askQuestion('\n⚠️  Are you sure you want to uninstall? (y/N) ');

  if (answer.toLowerCase() !== 'y') {
    log('\n🚫 Uninstallation cancelled\n', 'yellow');
    return;
  }

  log('\n🗑️  Removing skill...', 'blue');
  fs.rmSync(targetDir, { recursive: true, force: true });

  if (!fs.existsSync(targetDir)) {
    log('✅ Skill uninstalled successfully!\n', 'green');
    log('💡 You can reinstall anytime with:', 'blue');
    log('   npm install -g @claude-code/ios-new-features-skill\n');
  } else {
    log('❌ Failed to uninstall\n', 'red');
    process.exit(1);
  }
}

uninstall().catch(error => {
  log(`\n❌ Error: ${error.message}\n`, 'red');
  process.exit(1);
});
