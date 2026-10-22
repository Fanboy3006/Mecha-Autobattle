# 对局上报 · 接收端（Google Apps Script + 表格）

> 作者 2026-10-12 拍板：「**网页端任何人玩了以后都留下一条游戏记录**」。
> 方案 = **A. Google Apps Script + Google 表格**；上传策略 = **默认开启 + 页面明确告知 + 菜单里可关**。
> 本文是**接收端**（你要做的那 5 分钟）；**客户端**（游戏里那个上报模块）由统筹实现，地址先留空，你拿到 URL 我填进去。

---

## 一、你要做的 5 步

1. 打开 <https://sheets.new> **新建一个 Google 表格**（名字随意，例如 `机甲指挥-对局记录`）；
2. 菜单 **扩展程序 → Apps Script**（会开一个新标签页）；
3. 把下面**第 二 节整段代码**粘进去（覆盖里面原本的 `function myFunction() {}`），**Ctrl+S 保存**；
4. 右上角 **部署 → 新建部署** → 齿轮选 **Web 应用**：
   - **说明**：随便写（例如 `v1`）
   - **执行身份**：**我（你自己）**
   - **谁可以访问**：**任何人** ← 必须是这个，否则陌生玩家传不进来
   - 点 **部署** → 会要你**授权**（走一遍「高级 → 转到项目（不安全）→ 允许」，这是你自己写的脚本，正常流程）
5. 复制那条 **Web 应用 URL**（形如 `https://script.google.com/macros/s/AKfy…/exec`）→ **发给我**，我填进游戏配置。

> **自检**：部署完把那条 URL 粘到浏览器地址栏回车，应该看到一行 JSON：`{"ok":true,"条数":0}`（或已有条数）→ 说明接收端通了。

---

## 二、Apps Script 代码（整段粘贴）

```javascript
/** 机甲指挥 · 对局上报接收端（作者 2026-10-12） */
const 表名 = '对局';                       // 存数据的工作表名（不存在会自动建）
const 表头 = ['时间', '种子', '版本', '分队', '结果', '层', '回合数', '时长秒',
              '操作数', '对局ID', '记录分片数', '记录1', '记录2', '记录3', '记录4'];

function 取表() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sh = ss.getSheetByName(表名);
  if (!sh) {
    sh = ss.insertSheet(表名);
    sh.appendRow(表头);
  }
  return sh;
}

/** 浏览器用 POST 发 JSON 到这里 */
function doPost(e) {
  try {
    const 体 = JSON.parse((e && e.postData && e.postData.contents) || '{}');
    const sh = 取表();
    const 键 = String(体.对局ID || '');

    // 去重：同一局（对局ID）只写一行
    if (键) {
      const 现有 = sh.getLastRow() > 1
        ? sh.getRange(2, 10, sh.getLastRow() - 1, 1).getValues().flat().map(String)
        : [];
      if (现有.indexOf(键) >= 0) return 出({ ok: true, 重复: true });
    }

    // 记录分片（Google 表格单元格上限 5 万字符 → 4.5 万切一片，最多 4 片）
    const 全文 = JSON.stringify(体.录像 || 体);
    const 片 = [];
    for (let i = 0; i < 全文.length && 片.length < 4; i += 45000) 片.push(全文.slice(i, i + 45000));

    sh.appendRow([
      体.时间 || new Date().toISOString(),
      体.种子 || '', 体.版本 || '', 体.分队 || '', 体.结果 || '',
      体.层 || '', 体.回合数 || '', 体.时长秒 || '', 体.操作数 || '',
      键, 片.length, 片[0] || '', 片[1] || '', 片[2] || '', 片[3] || '',
    ]);
    return 出({ ok: true, 条数: sh.getLastRow() - 1 });
  } catch (err) {
    return 出({ ok: false, 错: String(err) });
  }
}

/** 浏览器打开 URL 时的自检 */
function doGet() {
  return 出({ ok: true, 条数: Math.max(0, 取表().getLastRow() - 1) });
}

function 出(对象) {
  return ContentService.createTextOutput(JSON.stringify(对象))
    .setMimeType(ContentService.MimeType.JSON);
}
```

---

## 三、客户端会发什么（协议，客户端按这个实现）

```json
{
  "对局ID": "604292-20261012-2340",
  "时间": "2026-10-12T23:40:57+08:00",
  "种子": 604292, "版本": "0.6.2", "分队": "无", "结果": "败",
  "层": 1, "回合数": 7, "时长秒": 812, "操作数": 52,
  "录像": { "格式版本": 1, "游戏版本": "0.6.2", "种子": 604292, "操作": [ … ] }
}
```

- **只发游戏数据**：不采集设备信息、不采集账号、不发 IP 之外的任何东西；`对局ID` = 种子 + 开始时间（用于去重，不是身份）。
- **失败不打扰**：网络失败就存本地队列，下次打开页面再试；**绝不影响玩法**。
- **可关闭**：开始界面一行告知 + 菜单里一个开关（默认开）。
- **只报肉鸽整局**：练习模式、调参室、单场战斗**不报**。

---

## 四、防刷与容量（现状与后手）

- 现在**没有任何鉴权**（静态页面的宿命）：URL 公开 → 理论上可被刷。缓解：**同一 `对局ID` 去重**、每局只写一行；真被刷了再上「简单口令 / 频率限制」。
- 容量：Google 表格**1000 万单元格**上限。每局一行约 15 列、记录分片 1–2 片 → **几千到上万局**没问题。
- 想把录像存到 **Google Drive 文件**（而不是表格单元格）也能做，等量大了再换（我会给升级版脚本）。
