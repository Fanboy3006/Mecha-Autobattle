// 远程 ZIP 单成员提取器：只下载中央目录 + 目标成员的数据块，不碰整包。
// 用法: node zipmember.mjs <url> <memberName> <outFile>
import { writeFile, mkdir } from 'fs/promises';
import { dirname } from 'path';

const [url, member, out] = process.argv.slice(2);
if (!url || !member || !out) { console.error('usage: zipmember.mjs <url> <member> <out>'); process.exit(2); }

const log = (...a) => console.log(`[${((Date.now()-T0)/1000).toFixed(1)}s]`, ...a);
const T0 = Date.now();

let bytesDownloaded = 0;
async function rangeGet(start, end) {
  const r = await fetch(url, { headers: { Range: `bytes=${start}-${end}` }, redirect: 'follow' });
  if (r.status !== 206 && r.status !== 200) throw new Error(`range ${start}-${end} -> HTTP ${r.status}`);
  if (r.status === 200) throw new Error('server ignored Range; refusing to download full 1.28 GB');
  const cr = r.headers.get('content-range'); // bytes start-end/total
  const total = Number(cr.split('/')[1]);
  const buf = Buffer.from(await r.arrayBuffer());
  bytesDownloaded += buf.length;
  return { buf, total };
}

// 1) 拿尾部，解析 EOCD
const TAIL = 65536;
const head = await rangeGet(0, 0);
const totalSize = head.total;
log(`remote total = ${totalSize} bytes (${(totalSize/1048576).toFixed(1)} MiB)`);
const tailStart = Math.max(0, totalSize - TAIL);
const { buf: tail } = await rangeGet(tailStart, totalSize - 1);
log(`tail fetched ${tail.length} bytes from ${tailStart}`);

let eocd = -1;
for (let i = tail.length - 22; i >= 0; i--) {
  if (tail.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
}
if (eocd < 0) throw new Error('EOCD not found');
let cdCount = tail.readUInt16LE(eocd + 10);
let cdSize  = tail.readUInt32LE(eocd + 12);
let cdOfs   = tail.readUInt32LE(eocd + 16);
log(`EOCD: entries=${cdCount} cdSize=${cdSize} cdOffset=${cdOfs}`);

// ZIP64 (tpz 有 >65535 成员的可能)
if (cdOfs === 0xffffffff || cdCount === 0xffff) {
  for (let i = tail.length - 22 - 20; i >= 0; i--) {
    if (tail.readUInt32LE(i) === 0x06064b50) {
      cdCount = Number(tail.readBigUInt64LE(i + 32));
      cdSize  = Number(tail.readBigUInt64LE(i + 40));
      cdOfs   = Number(tail.readBigUInt64LE(i + 48));
      log(`ZIP64 EOCD: entries=${cdCount} cdSize=${cdSize} cdOffset=${cdOfs}`);
      break;
    }
  }
}

// 2) 读中央目录（若不在 tail 内就单独 range 取）
let cd;
if (cdOfs >= tailStart && cdOfs + cdSize <= totalSize) {
  cd = tail.subarray(cdOfs - tailStart, cdOfs - tailStart + cdSize);
} else {
  ({ buf: cd } = await rangeGet(cdOfs, cdOfs + cdSize - 1));
}
log(`central directory ${cd.length} bytes`);

// 3) 遍历中央目录条目
let p = 0, found = null, n = 0;
while (p + 46 <= cd.length && cd.readUInt32LE(p) === 0x02014b50) {
  const method   = cd.readUInt16LE(p + 10);
  const compSize = cd.readUInt32LE(p + 20);
  const uncompSize = cd.readUInt32LE(p + 24);
  const nameLen  = cd.readUInt16LE(p + 28);
  const extraLen = cd.readUInt16LE(p + 30);
  const cmtLen   = cd.readUInt16LE(p + 32);
  const lho      = cd.readUInt32LE(p + 42);
  const name     = cd.toString('latin1', p + 46, p + 46 + nameLen);
  n++;
  if (name === member || name.endsWith('/' + member) || name.endsWith(member)) {
    found = { name, method, compSize, uncompSize, lho };
  }
  p += 46 + nameLen + extraLen + cmtLen;
}
log(`scanned ${n} central-directory entries`);
if (!found) {
  console.error(`MEMBER NOT FOUND: ${member}`);
  process.exit(3);
}
log(`FOUND ${found.name}  method=${found.method} comp=${found.compSize} uncomp=${found.uncompSize}`);

// 4) 读本地文件头拿到真实数据偏移
const { buf: lhBuf } = await rangeGet(found.lho, found.lho + 29);
if (lhBuf.readUInt32LE(0) !== 0x04034b50) throw new Error('bad local header signature');
const lhNameLen  = lhBuf.readUInt16LE(26);
const lhExtraLen = lhBuf.readUInt16LE(28);
const dataStart  = found.lho + 30 + lhNameLen + lhExtraLen;
log(`local header: nameLen=${lhNameLen} extraLen=${lhExtraLen} dataStart=${dataStart}`);

// 5) 下载成员数据（分块，便于进度）
const CHUNK = 8 * 1024 * 1024;
const chunks = [];
for (let off = 0; off < found.compSize; off += CHUNK) {
  const end = Math.min(off + CHUNK, found.compSize) - 1;
  const { buf } = await rangeGet(dataStart + off, dataStart + end);
  chunks.push(buf);
  if (found.compSize > CHUNK) log(`  member progress ${Math.min(off + CHUNK, found.compSize)}/${found.compSize}`);
}
let data = Buffer.concat(chunks);
if (data.length !== found.compSize) throw new Error(`size mismatch ${data.length} != ${found.compSize}`);
log(`member compressed bytes = ${data.length}`);

// 6) method 0 = stored 直接就是 zip 文件；method 8 = deflate 需要还原
if (found.method === 8) {
  const { inflateRawSync } = await import('zlib');
  data = inflateRawSync(data);
  log(`inflated -> ${data.length} bytes`);
} else if (found.method !== 0) {
  throw new Error(`unsupported compression method ${found.method}`);
}

await mkdir(dirname(out), { recursive: true });
await writeFile(out, data);
if (data.readUInt32LE(0) !== 0x04034b50) throw new Error('output does not start with PK\\x03\\x04');
log(`WROTE ${out} (${data.length} bytes) magic=PK\\x03\\x04 OK`);
log(`total network bytes = ${bytesDownloaded} (${(bytesDownloaded/1048576).toFixed(2)} MiB)`);
