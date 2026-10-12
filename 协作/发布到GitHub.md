# 发布到 GitHub（2026-10-12 核查 + 操作说明）

## 1. 统筹（DSH）为什么自己推不了 —— 环境事实，不是仓库问题

2026-10-12 在本机沙箱里实测：

| 检查 | 结果 |
|---|---|
| `git remote -v` | **没有任何 remote** |
| `gh --version` | **没装 `gh`** |
| `git --version` | 2.52.0.windows.1，`credential.helper = manager`（Git Credential Manager 在） |
| `~/.git-credentials` / `~/.ssh` | **都没有** → 没有缓存凭据、没有 SSH 密钥 |
| `git ls-remote https://github.com/…` | `fatal: … schannel: AcquireCredentialsHandle failed: SEC_E_NO_CREDENTIALS (0x8009030e)` |
| `Invoke-WebRequest -Method Head https://github.com` | `The SSL connection could not be established` |
| `curl -I https://api.github.com` | `curl: (35) schannel: AcquireCredentialsHandle failed: SEC_E_NO_CREDENTIALS` |

→ **沙箱里所有 HTTPS 出网都建不起 TLS**（不只 GitHub）。所以「建仓库 / push / 装 `gh`」这三件事
**统筹都做不到**；**在作者自己的终端里（不受这个沙箱限制）可以。**

## 2. 作者要跑的三步（一次就够）

1. **在 GitHub 上建一个空仓库**（不要勾 README / .gitignore / license，要真空仓库）；
2. 打开你自己的 PowerShell（**不是** DSH 那个沙箱终端），执行：

```powershell
cd F:\DSH-mecha\mecha-autobattle
git remote add origin https://github.com/<你的账号>/<仓库名>.git
git push -u origin main
```

3. 第一次会弹 **Git Credential Manager** 的浏览器登录（授权一次，以后就不用再登）。

推完告诉我，我可以接着做这些（**不需要网络**）：核对 `git log` / `git status`、把
「以后每次交付都由统筹准备好、你一条命令推」写成流程，或者准备 `git bundle` 单文件备份。

## 3. ★ 推之前请先定：**私有**还是**公开**（作者 2026-10-12 已定：**公开**）

> **作者决定**：仓库 `fanboy3006/Mecha-Autobattle`，**公开、给朋友试玩**；作者原话
> 「这个我需要公开，给朋友试玩，**可以写你说的那些东西，之后会改掉**」。
> → **`README.md` 顶部已加免责声明**（同人练习作 / 角色与机体名版权归原作者 / 计划正式发布前改成原创名字 /
> 仓库不含任何原作素材：图标原创、音乐为 Suno 生成、本地版权音乐与图片已被 `.gitignore` 排除）。
> **「以后要把名字全换成原创」这件事仍然记在待办里。** 下面这段「建议先私有」的理由**留档备查**。

**理由（命名与版权）**：`src/js/10-数据.js` 里的机师名 / 机体名 / 势力名**来自版权作品**
（例：洛克昂、希罗、拉克丝、刹那、Feena；势力名：天人 / ATX / 秘银 / 卫星国防军 / 月之国…）。
`CLAUDE.md` 与原来的方案里都记着一条未办事项：**「公开前先换成自己的名字」**。
所以：
- **私有仓库**：现在就可以推，零风险；
- **公开仓库**：建议**先改名**（或者在 README 里写清「同人练习作、角色与机体名所有权归原作者、本项目不含任何原作素材」）——由作者拍板。

**已核查「没有夹带不该公开的东西」**：

- 跟踪文件 **111 个**；最大的 PDF/音频全是**作者用 Suno 生成的曲子**（`audio/SUNO/*.mp3`，3–4 MB 一首，共 9 首）；
- `audio/` 根目录的**版权 mp3** 与 `图片库/` **已被 `.gitignore` 排除**（`git ls-files` 里一个都没有）；
- 没有密钥 / 令牌类文件；`art/mech-icons.js` 是原创矢量图标。

## 4. 体积（推之前知情即可）

| 项 | 大小 |
|---|---|
| 工作区（含两份生成物 HTML 各 1.29 MB） | 约 **68 MB** |
| `.git`（历史） | 约 **96 MB** |
| 合计 | 约 **164 MB** |

GitHub 单文件上限 100 MB、仓库建议 1 GB 以内 —— **我们远没到**，直接推没问题。
若想让仓库更小：把 `audio/SUNO/*.mp3` 挂到 GitHub Release（或 Git LFS）再推；**要不要做由作者定**。

## 5. 以后再推（流程建议）

- 每件交付仍然是「**统筹准备好提交**（`node tools/verify-all.mjs` 全绿 + 文档齐全）」；
- **push 由作者按需执行**（`git push`），统筹不碰凭据；
- 如果哪天本机沙箱的 TLS 修好、或作者给统筹一个可用凭据，再谈「统筹直接推」。
