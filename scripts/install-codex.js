#!/usr/bin/env node

/**
 * iOS New Features Skill - Codex Install Script
 *
 * Codex (OpenAI CLI) does not auto-trigger skills. This installer:
 *   1. Copies the reference docs to ~/.codex/skills/ios-new-features/
 *   2. Injects an idempotent, marker-delimited instruction block into the
 *      global ~/.codex/AGENTS.md that points Codex at the installed docs.
 */

const fs = require('fs');
const path = require('path');

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

const BEGIN_MARKER = '<!-- BEGIN ios-new-features (managed by install-codex) -->';
const END_MARKER = '<!-- END ios-new-features (managed by install-codex) -->';

function getCodexDir() {
  const homeDir = process.env.HOME || process.env.USERPROFILE;
  return path.join(homeDir, '.codex');
}

function copyRecursive(src, dest) {
  const stats = fs.statSync(src);
  if (stats.isDirectory()) {
    if (!fs.existsSync(dest)) {
      fs.mkdirSync(dest, { recursive: true });
    }
    for (const child of fs.readdirSync(src)) {
      copyRecursive(path.join(src, child), path.join(dest, child));
    }
  } else {
    fs.copyFileSync(src, dest);
  }
}

function buildBlock(skillDir) {
  const agentsPath = path.join(skillDir, 'AGENTS.md');
  return [
    BEGIN_MARKER,
    '## iOS New Features Reference',
    '',
    'When a request involves iOS 18+ / iOS 26+ Swift or SwiftUI APIs, a specific WWDC session',
    '(2023–2025), or any trigger keyword listed in the index below, **read the matching reference',
    'file before writing code**. Do not answer newer-iOS API questions from memory alone.',
    '',
    `- Index & trigger keywords: \`${agentsPath}\``,
    `- Reference docs: \`${path.join(skillDir, 'reference')}/\``,
    END_MARKER,
    '',
  ].join('\n');
}

function upsertGlobalAgents(agentsFile, block) {
  let existing = '';
  if (fs.existsSync(agentsFile)) {
    existing = fs.readFileSync(agentsFile, 'utf-8');
  }

  const beginIdx = existing.indexOf(BEGIN_MARKER);
  const endIdx = existing.indexOf(END_MARKER);

  if (beginIdx !== -1 && endIdx !== -1) {
    // Replace the existing managed block in place.
    const before = existing.slice(0, beginIdx);
    const after = existing.slice(endIdx + END_MARKER.length);
    const updated = `${before}${block.trimEnd()}${after}`;
    fs.writeFileSync(agentsFile, updated.endsWith('\n') ? updated : `${updated}\n`);
    return 'updated';
  }

  // Append a fresh block.
  const separator = existing.length === 0 || existing.endsWith('\n') ? '' : '\n';
  const prefix = existing.length === 0 ? '' : '\n';
  fs.writeFileSync(agentsFile, `${existing}${separator}${prefix}${block}`);
  return existing.length === 0 ? 'created' : 'appended';
}

function install() {
  log('\n========================================', 'blue');
  log('  iOS New Features Skill (Codex) Installer', 'blue');
  log('========================================\n', 'blue');

  const codexDir = getCodexDir();
  const skillDir = path.join(codexDir, 'skills', 'ios-new-features');
  const agentsFile = path.join(codexDir, 'AGENTS.md');

  const sourceAgents = path.join(__dirname, '..', 'codex', 'AGENTS.md');
  const sourceReference = path.join(__dirname, '..', 'skills', 'ios-new-features', 'reference');

  if (!fs.existsSync(sourceAgents) || !fs.existsSync(sourceReference)) {
    log('❌ Source files not found. Run this from the cloned repository.\n', 'red');
    process.exit(1);
  }

  log(`📁 Target directory: ${skillDir}`, 'blue');

  // Fresh copy of the skill payload.
  if (fs.existsSync(skillDir)) {
    log('⚠️  Existing install found — refreshing...', 'yellow');
    fs.rmSync(skillDir, { recursive: true, force: true });
  }
  fs.mkdirSync(skillDir, { recursive: true });

  log('📋 Copying reference docs...', 'blue');
  fs.copyFileSync(sourceAgents, path.join(skillDir, 'AGENTS.md'));
  copyRecursive(sourceReference, path.join(skillDir, 'reference'));

  log('📝 Updating global ~/.codex/AGENTS.md...', 'blue');
  const action = upsertGlobalAgents(agentsFile, buildBlock(skillDir));

  // Verify.
  if (fs.existsSync(path.join(skillDir, 'AGENTS.md'))) {
    log('\n✅ Codex installation successful!\n', 'green');
    log('📍 Docs installed to:', 'blue');
    log(`   ${skillDir}`);
    log(`📍 Global instructions (${action}):`, 'blue');
    log(`   ${agentsFile}\n`);
    log('🎯 Next steps:', 'yellow');
    log('   1. Start (or restart) Codex');
    log("   2. Ask about an iOS 18+ API, e.g. 'How do I use AlarmKit?'");
    log('   3. Codex will read the matching reference file automatically\n');
    log('🚀 Happy coding!\n', 'green');
  } else {
    log('\n❌ Installation failed — AGENTS.md not copied.\n', 'red');
    process.exit(1);
  }
}

install();
