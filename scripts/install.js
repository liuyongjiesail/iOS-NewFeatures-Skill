#!/usr/bin/env node

/**
 * iOS New Features Skill - NPM Install Script
 * Automatically installs the skill to ~/.claude/skills/
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// ANSI colors
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
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
  return path.join(homeDir, '.claude', 'skills');
}

function copyRecursive(src, dest) {
  const exists = fs.existsSync(src);
  const stats = exists && fs.statSync(src);
  const isDirectory = exists && stats.isDirectory();

  if (isDirectory) {
    if (!fs.existsSync(dest)) {
      fs.mkdirSync(dest, { recursive: true });
    }
    fs.readdirSync(src).forEach(childItemName => {
      copyRecursive(
        path.join(src, childItemName),
        path.join(dest, childItemName)
      );
    });
  } else {
    fs.copyFileSync(src, dest);
  }
}

async function install() {
  log('\n========================================', 'blue');
  log('  iOS New Features Skill Installer', 'blue');
  log('========================================\n', 'blue');

  const skillsDir = getClaudeSkillsDir();
  const targetDir = path.join(skillsDir, 'ios-new-features');
  const sourceDir = path.join(__dirname, '..', 'ios-new-features');

  log(`📁 Target directory: ${targetDir}`, 'blue');

  // Check if already installed
  if (fs.existsSync(targetDir)) {
    log('⚠️  Skill already installed', 'yellow');
    log('   Removing old version...', 'yellow');
    fs.rmSync(targetDir, { recursive: true, force: true });
  }

  // Create skills directory
  if (!fs.existsSync(skillsDir)) {
    log('📦 Creating .claude/skills directory...', 'blue');
    fs.mkdirSync(skillsDir, { recursive: true });
  }

  // Copy skill files
  log('📋 Copying skill files...', 'blue');
  copyRecursive(sourceDir, targetDir);

  // Verify installation
  const skillFile = path.join(targetDir, 'SKILL.md');
  if (fs.existsSync(skillFile)) {
    log('\n✅ Installation successful!\n', 'green');
    log('📍 Skill installed to:', 'blue');
    log(`   ${targetDir}\n`);
    log('🎯 Next steps:', 'yellow');
    log('   1. Restart Claude Code (if running)');
    log('   2. Open any iOS project');
    log("   3. Try asking: 'How to use AlarmKit in iOS 26?'\n");
    log('🚀 Happy coding!\n', 'green');
  } else {
    log('\n❌ Installation failed!', 'red');
    log('   SKILL.md not found in target directory\n', 'red');
    process.exit(1);
  }
}

// Run installation
install().catch(error => {
  log(`\n❌ Error: ${error.message}\n`, 'red');
  process.exit(1);
});
