---
name: ljg-push
description: 把 ~/.workbuddy/skills/ 里所有更新过的 skills 同步到 GitHub 个人仓库 (TTbingo/<skill-name>)，每个 skill 独立推送到对应仓库。支持指定 skill 名称、dry-run、force 模式。Use when user says '/ljg-push', 'push skills', '推送 skills', '同步 skills', 'sync ljg', or whenever skills get updated and need shipping.
user_invocable: true
---

# skill-push: 推送 skills 到 GitHub

把本地 `~/.workbuddy/skills/` 里改过的 skills，一键同步到 GitHub 个人仓库（`TTbingo/<skill-name>`）。

## 仓库命名规则

每个 skill 推送到独立仓库：

| Skill 名称 | GitHub 仓库 |
|-----------|------------|
| `k12-math-tutor` | `git@github.com:TTbingo/k12-math-tutor.git` |
| `ljg-think` | `git@github.com:TTbingo/ljg-think.git` |
| `ljg-push` | `git@github.com:TTbingo/ljg-push.git` |
| 任意 `<skill-name>` | `git@github.com:TTbingo/<skill-name>.git` |

## 前置条件

每个 skill 目录必须：
1. 已初始化 git repo（`$SKILLS_LOCAL/<skill>/.git/` 存在）
2. 已配置远程仓库（`git remote add origin git@github.com:TTbingo/<skill>.git`）
3. GitHub 上已创建对应仓库（脚本不会自动创建仓库）

**初始化命令（首次推送某 skill 时）：**
```bash
cd ~/.workbuddy/skills/<skill-name>
git init
git remote add origin git@github.com:TTbingo/<skill-name>.git
```

## 使用方法

### 基本用法

```bash
# 推送所有有变更的 skills
bash Tools/Push.sh

# 推送指定 skills
bash Tools/Push.sh k12-math-tutor ljg-think

# 只看不推（dry-run）
bash Tools/Push.sh --dry-run

# 强制推送所有（不检测变更）
bash Tools/Push.sh --force

# 对 ljg-* skills 使用双分支工作流（实验性）
bash Tools/Push.sh --ljg
```

### 参数说明

| 参数 | 说明 |
|-----|------|
| `--dry-run` | 显示会推送哪些 skills，不执行实际推送 |
| `--force` | 跳过变更检测，推送所有指定 skills |
| `--ljg` | 对 `ljg-*` 前缀的 skills 使用双分支工作流（master + md） |
| `skill1 skill2...` | 指定要推送的 skills（不指定则推送所有） |

## 变更检测

脚本会自动检测每个 skill 是否有未提交的变更：
- `git diff --quiet` — 已跟踪文件的变更
- `git ls-files --others --exclude-standard` — 未跟踪的新文件

无变更则跳过，不执行 commit + push。

## 提交流程

1. `git add .` — 添加所有变更
2. `git commit -m "Update <skill> (<timestamp>)"` — 用日期时间戳提交
3. `git pull --rebase` — 先拉取远端更新
4. `git push origin <branch>` — 推送到对应分支（main 或 master）

## 分支约定

- 默认推送到 `main` 分支
- 如果本地有 `master` 分支，则推送到 `master`
- `--ljg` 模式下，`ljg-*` skills 使用双分支（master + md），其他 skills 使用单分支

## 注意事项

- **脚本不会自动创建 GitHub 仓库**——需要先在 GitHub 上手动创建，或提供创建仓库的权限
- **认证依赖 gh CLI**——脚本依赖 `gh auth` 提供的 git credentials
- **推送前会 pull --rebase**——如果有冲突需要手动解决
- **ljg 双分支逻辑（master + md）目前未完全实现**——`--ljg` 模式会 fallback 到单分支推送

## Examples

*Example 1: 推送单个 skill*

```bash
User: /ljg-push k12-math-tutor
→ 检测 k12-math-tutor 是否有变更
→ 有变更则：git add + commit + push 到 TTbingo/k12-math-tutor
→ 报告推送结果
```

*Example 2: 推送所有变更的 skills*

```bash
User: /ljg-push
→ 遍历 ~/.workbuddy/skills/ 下所有子目录
→ 检测每个 skill 是否有变更
→ 有变更则推送
→ 报告推送结果
```

*Example 3: dry-run 模式*

```bash
User: /ljg-push --dry-run
→ 列出所有有变更的 skills
→ 显示会执行的操作
→ 不执行实际推送
```

## TODO

- [ ] 实现 ljg 双分支逻辑（master + md）作为可选模式
- [ ] 自动 bump 版本号（SKILL.md 中的 version 字段）
- [ ] 支持自动创建 GitHub 仓库（需要 gh repo create 权限）
- [ ] 添加 README 一致性检查（可选，针对有 README 的 skills）
