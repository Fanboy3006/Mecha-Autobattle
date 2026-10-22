#!/usr/bin/env node
import fs from 'fs';

const file = process.argv[2];
if (!file) {
  console.error('Usage: node clean_history_comments.mjs <file>');
  process.exit(1);
}

const raw = fs.readFileSync(file, 'utf8');
const hasCrlf = raw.includes('\r\n');
const lines = raw.replace(/\r\n/g, '\n').split('\n');

const out = [];

// Obvious historical / noisy full-line comment patterns (never touching line 0)
const histRegexes = [
  /★/,
  /2026-\d{2}-\d{2}/,
  /任务单/,
  /施工单/,
  /CR-[12345]/,
  /DEBT-\d+/i,
  /DS41F|DS4F|Claude|Opus|Argon/i,
  /从前.*现在|以前.*现在|原先.*现在|原本.*现在/,
  /黄金样例|168\s*场|逐字不变|逐字一致|零影响|一个字段都不多|与改前/,
  /^\s*#\s*[═=─\-]{6,}\s*$/, // pure horizontal border lines
];

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  if (i === 0) {
    out.push(line);
    continue;
  }
  const trimmed = line.trim();
  if (trimmed.startsWith('#')) {
    // Keep rule anchors like # [规范v0.3...] if they don't have historical narrative, or strip if historical
    let isHist = false;
    for (const re of histRegexes) {
      if (re.test(trimmed)) {
        isHist = true;
        break;
      }
    }
    if (isHist) {
      continue;
    }
  }
  out.push(line);
}

const result = out.join(hasCrlf ? '\r\n' : '\n');
fs.writeFileSync(file, result, 'utf8');
console.log(`Processed ${file}: ${lines.length} -> ${out.length} lines`);
