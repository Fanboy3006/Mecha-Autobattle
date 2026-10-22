# 归档搬家脚本（2026-10-21，Claude 生成）
# 在仓库根目录 F:\DSH-mecha\mecha-autobattle 下用 PowerShell 运行：  .\协作\归档\归档搬家-20261021.ps1
# 用 git mv 搬（可用 git 撤回）；文件不在 git 里时退回 Move-Item。只搬「确定」的，待确认清单见同目录 .md。
$ErrorActionPreference = 'Continue'
function Move-Archive($src, $dstDir) {
  if (-not (Test-Path -LiteralPath $src)) { Write-Host "跳过（不存在）：$src"; return }
  New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
  git mv -- "$src" "$dstDir/" 2>$null
  if ($LASTEXITCODE -ne 0) { Move-Item -LiteralPath $src -Destination $dstDir; Write-Host "Move-Item：$src" } else { Write-Host "git mv：$src" }
}

# 一、协作/ 根目录的 JS 时代文档 → 协作/归档/JS时代/
Move-Archive '协作/上报-接收端-AppsScript.md' '协作/归档/JS时代'
Move-Archive '协作/关卡变体池-机制对账.md' '协作/归档/JS时代'
Move-Archive '协作/关卡变体池-规格草案.md' '协作/归档/JS时代'
Move-Archive '协作/分工看板.md' '协作/归档/JS时代'
Move-Archive '协作/势力特色.md' '协作/归档/JS时代'
Move-Archive '协作/势力特色落地决定.md' '协作/归档/JS时代'
Move-Archive '协作/协作框架.md' '协作/归档/JS时代'
Move-Archive '协作/多智能体派单规范.md' '协作/归档/JS时代'
Move-Archive '协作/多模型高效协作指南.md' '协作/归档/JS时代'
Move-Archive '协作/战报分析-口径.md' '协作/归档/JS时代'
Move-Archive '协作/战棋协作可搬清单.md' '协作/归档/JS时代'
Move-Archive '协作/招募券系统-实现任务书.md' '协作/归档/JS时代'
Move-Archive '协作/招募券系统-规格.md' '协作/归档/JS时代'
Move-Archive '协作/接口约定.md' '协作/归档/JS时代'
Move-Archive '协作/敌人机制盘点-可用的钩子.md' '协作/归档/JS时代'
Move-Archive '协作/方向调整-全队方针与反馈.md' '协作/归档/JS时代'
Move-Archive '协作/架构债务.md' '协作/归档/JS时代'
Move-Archive '协作/架构快照.json' '协作/归档/JS时代'
Move-Archive '协作/秘银团队羁绊-新思路.md' '协作/归档/JS时代'
Move-Archive '协作/秘银联动机制-提案.md' '协作/归档/JS时代'
Move-Archive '协作/试玩说明-下一版.md' '协作/归档/JS时代'

# 二、Godot 迁移期 ARGON 交接文档 → 协作/归档/ARGON架构/
Move-Archive '协作/Godot迁移-ARGON验收对照表.md' '协作/归档/ARGON架构'
Move-Archive '协作/Godot迁移-GameplayArchitect交接卡.md' '协作/归档/ARGON架构'
Move-Archive '协作/Godot迁移-M4试玩清单.md' '协作/归档/ARGON架构'

# 三、协作/架构/ 下 ARGON 写的任务单、施工单、评审 → 协作/归档/ARGON架构/
Move-Archive '协作/架构/任务单-ATX-v0.3与卡牌新机制-ARGON.md' '协作/归档/ARGON架构'
Move-Archive '协作/架构/任务单-M4试玩反馈6项修复与体验升级-ARGON.md' '协作/归档/ARGON架构'
Move-Archive '协作/架构/任务单-M4试玩反馈二轮修复-站位与0.5s动画队列-ARGON.md' '协作/归档/ARGON架构'
Move-Archive '协作/架构/任务单-单机牌组与阶段制战斗-v1.0-ARGON.md' '协作/归档/ARGON架构'
Move-Archive '协作/架构/任务单-天人v0.1与规范v0.3断路器与顺劈-ARGON.md' '协作/归档/ARGON架构'
Move-Archive '协作/架构/任务单-战斗UI重构4x4与手牌纯可打与援护连线-ARGON.md' '协作/归档/ARGON架构'
Move-Archive '协作/架构/任务单-手牌三栏自适应缩放与友军拖拽绿线箭头-ARGON.md' '协作/归档/ARGON架构'
Move-Archive '协作/架构/任务单-殖民卫星军v0.1与觉醒QTE锁定链-ARGON.md' '协作/归档/ARGON架构'
Move-Archive '协作/架构/任务单-秘银v0.3与卡牌流转范围规则v1.0-ARGON.md' '协作/归档/ARGON架构'
Move-Archive '协作/架构/任务单-试玩三轮修复-敌方排位与战报飘字与友方选中-ARGON.md' '协作/归档/ARGON架构'
Move-Archive '协作/架构/任务单-试玩反馈修复-秘银连携与ATX武器栏与靶机-ARGON.md' '协作/归档/ARGON架构'
Move-Archive '协作/架构/任务单-零件系统改造-黑流树海原版对齐-ARGON.md' '协作/归档/ARGON架构'
Move-Archive '协作/架构/施工单-CR1-P1修复与Token瘦身示范-ARGON.md' '协作/归档/ARGON架构'
Move-Archive '协作/架构/施工单-CR2-出牌与攻击管线统一+规则钩子注册表-ARGON.md' '协作/归档/ARGON架构'
Move-Archive '协作/架构/施工单-CR3-收尾+大招槽分派+换装栈+大文件拆分-ARGON.md' '协作/归档/ARGON架构'
Move-Archive '协作/架构/施工单-CR4-ATX与秘银卡表抽数据+注释清理-ARGON.md' '协作/归档/ARGON架构'
Move-Archive '协作/架构/评审-单机牌组规则-v0.1-ARGON.md' '协作/归档/ARGON架构'
Move-Archive '协作/架构/评审-大招牌化与ATX-v0.1-ARGON.md' '协作/归档/ARGON架构'
Move-Archive '协作/架构/评审-秘银连携作战-v0.2与派生任务单-ARGON.md' '协作/归档/ARGON架构'


# 四、作者 10-21 同意按建议处理的待确认项
Move-Archive '协作/任务板.md' '协作/归档/JS时代'
Move-Archive '协作/协作日志.md' '协作/归档/JS时代'
Move-Archive '协作/架构/Godot迁移-M4收口与交接卡-下一任架构师.md' '协作/归档/迁移期'
Move-Archive '协作/架构/Godot-CodeReview交接卡-ClaudeOpus5.5.md' '协作/归档/迁移期'
Move-Archive '协作/架构/Godot-CodeReview报告-ClaudeOpus5.5.md' '协作/归档/迁移期'
Move-Archive '协作/架构/M4-表现层接口契约.md' '协作/归档/迁移期'
Move-Archive '协作/架构/迁移地图.md' '协作/归档/迁移期'
Move-Archive '协作/架构/依赖清单.json' '协作/归档/迁移期'
Move-Archive '协作/架构/CR-1回执.md' '协作/归档/迁移期'
Move-Archive '协作/架构/CR-1附件' '协作/归档/迁移期'
Move-Archive '协作/架构/CR-2回执.md' '协作/归档/迁移期'
Move-Archive '协作/架构/CR-3回执.md' '协作/归档/迁移期'
Move-Archive '协作/架构/CR-4回执.md' '协作/归档/迁移期'
Move-Archive '协作/架构/RT-1盘点.md' '协作/归档/迁移期'
Move-Archive '协作/架构/RT回执.md' '协作/归档/迁移期'
# 调研性质的挪进 协作/调研/（不是归档）
Move-Archive '协作/节点设计对比-黑流树海.md' '协作/调研'
Move-Archive '协作/路线结构调研-黑流树海与我们.md' '协作/调研'
Move-Archive '协作/集成战略藏品调研.md' '协作/调研'

Write-Host '完成。检查 git status 后提交：git commit -m "[docs] 协作/ 根目录 JS 时代与 ARGON 架构文档归档"'
