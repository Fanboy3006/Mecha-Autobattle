#!/usr/bin/env node
import fs from 'fs';
import { 去注释, 量注释, 量体积 } from './build_godot_routemap.mjs';

function stripCodeLines(src) {
  const noComment = 去注释(src.replace(/\r\n/g, '\n'));
  return noComment.split('\n').map(l => l.trimEnd()).filter(l => l.trim() !== '');
}

const headFile = process.argv[2];
const curFile = process.argv[3];
if (!headFile || !curFile) { console.error('Usage: node check_strip_diff.mjs <head-file> <cur-file>'); process.exit(1); }

const headSrc = fs.readFileSync(headFile, 'utf8').replace(/\r\n/g, '\n');
const curSrc = fs.readFileSync(curFile, 'utf8').replace(/\r\n/g, '\n');

const headLines = stripCodeLines(headSrc);
const curLines = stripCodeLines(curSrc);

const headJoined = headLines.join('\n');
const curJoined = curLines.join('\n');

let diffLines = 0;
if (headJoined !== curJoined) {
  const maxLen = Math.max(headLines.length, curLines.length);
  for (let i = 0; i < maxLen; i++) {
    if (headLines[i] !== curLines[i]) {
      diffLines++;
      if (diffLines <= 5) {
        console.error(`Mismatch at code line ${i + 1}:\n  HEAD: ${headLines[i]}\n  CURR: ${curLines[i]}`);
      }
    }
  }
}

const headC = 量注释(headSrc);
const curC = 量注释(curSrc);
const headV = 量体积(headSrc);
const curV = 量体积(curSrc);

console.log(`${curFile}:`);
console.log(`  HEAD: ${headSrc.split('\n').length} lines, ${Buffer.byteLength(headSrc)} B, ${headV.estTokens} tokens, comment ${(headC.占比 * 100).toFixed(1)}% (${headC.注释字节} B)`);
console.log(`  CURR: ${curSrc.split('\n').length} lines, ${Buffer.byteLength(curSrc)} B, ${curV.estTokens} tokens, comment ${(curC.占比 * 100).toFixed(1)}% (${curC.注释字节} B)`);
console.log(`  Stripped non-empty code lines: HEAD=${headLines.length}, CURR=${curLines.length}, diffLines=${diffLines}, exactMatch=${headJoined === curJoined}`);
if (diffLines > 0) process.exit(1);
