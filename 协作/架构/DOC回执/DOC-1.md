# DOC-1 回执：说明书换代 + 设计约定 + 临时文件清单

1. **归档**：根 `CLAUDE.md`（231 行，JS 时代）= `git mv` → `协作/归档/CLAUDE-JS时代.md`，**内容逐字节未变**（hash 对过）。
   仓库里「`CLAUDE.md` 第 N 节」那类旧引用照旧在归档那份里对得上（新 `CLAUDE.md` 已注明这层关系）。
2. **新 `CLAUDE.md`**：56 行（上限 80）—— 项目是什么 · **唯一引擎 = `godot/`** · 目录与入口（`godot/README.md`、
   `协作/开发路线图-v0.1.md`、`协作/设计/`、`协作/架构/`、回执目录、RouteMap、设计约定）· 协作分工（作者 / Claude 设计评审 /
   DS4.1F 代码 / ARGON 设计稿）· 施工单与回执规矩（小文件回执 ≤40 行、一个 Batch 一个提交、两道门禁、只重录一次、
   一次一个文件、规则先文档、不编造）。**JS 时代内容一律没搬**。
3. **新 `协作/设计/设计约定.md`**：从旧 §7 搬仍然有效的 6 条（规则先文档 + 数值暂定 / 三层反馈 / 设计判断归作者与 Claude /
   **职业分工**（会话原句一字不改）/ 中文与版权 / 旧战棋只读），每条标出处；过时的没搬，文末列了「没搬的几条」及去处。
4. **根目录临时文件（只列不删，等作者定）** —— 共 **68 项，全部未跟踪、都被 `.gitignore` 忽略**（`git check-ignore` 逐类验过）：
   - `.tmp-*.log` **42**：`.tmp-3b4*`×8 · `.tmp-check*`×7 · `.tmp-rm*`×6 · `.tmp-rt3b*`×11 · `.tmp-sub*`×8 · `.tmp-probe.log` · `.tmp-routemap.log`
   - `.tmp-msg-*.txt` **6** · `.tmp-*.mine` **2**（`.tmp-dh` / `.tmp-unit_card`）· `tmp-*.mjs` **13**（中间态 / 写文档 / 即时探查 /
     反馈探查 / 合成×3 / 探查2–4 / 新段 / 防御探查×2）
   - 临时目录 **5**：`tmp-stage`、`.tmp`、`.tmp-balance-测试`、`.tmp-ui-bug`、`.tmp-wt-head2`
   - 另：`export_templates/`、`feature_profiles/`、`script_templates/`、`text_editor_themes/` 是**未跟踪但非临时**的 Godot 项目目录，
     单列、不建议删。
5. 门禁：本任务没碰代码，红绿与 COL-1 收尾一致（`--check` EXIT=0；全量 1 项红 = 那条局外样例，等 G3）。单独一个提交 `[DOC-1]`。
