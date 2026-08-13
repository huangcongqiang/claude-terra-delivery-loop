# Claude + Terra Delivery Loop

面向单个有界工程任务的高置信交付 Skill：由 Claude Code 实施，Codex 检查真实 diff、裁决并修复，独立 reviewer 按风险复审，直到最新完整审查没有已知 P0/P1/P2，再完成集成验证与资源清理。

## 核心流程

```text
冻结任务包
  → 建立可恢复基线
  → Claude Code 有界实施
  → 检查真实文件和 diff
  → 独立多视角复审
  → Codex 修复与重新验证
  → 最新候选完整复审
  → 集成、验证、写回、清理
```

## 主要能力

- 通过 [`claude-code-dispatcher`](https://github.com/huangcongqiang/claude-code-dispatcher) 调度本地 Claude CLI。
- 使用 Ponytail 选择最小充分实现，限制无依据的抽象、依赖、配置和脚手架。
- 冻结目标、工作目录、基线、允许路径、禁止动作、验收标准和验证命令。
- 拒绝空 diff、越界修改、未经授权的删除和 `git diff --check` 错误。
- 对明确获准的单个 gitignored 文件记录 SHA-256/`ABSENT` 基线，避免普通 Git diff 的忽略文件盲区。
- 使用领域/状态、Schema/集成、交付/参考三个只读复审视角；宿主不允许内置 reviewer 时，使用允许的独立 reviewer 或主 Agent 复审并披露替代。
- P0/P1/P2 修复后重新执行受影响复审，并对最新候选完成一次完整审查。
- 支持 Figma、截图和演示项目的结构、状态、视口和交互一致性验收。
- 对 Claude 成功但没有 diff、会话停滞和工作区漂移提供有界恢复路径。

## 角色边界

| 角色 | 职责 |
| --- | --- |
| Claude Code | 在冻结范围内实施并运行 worker 侧检查 |
| 独立 reviewer | 只读发现可执行的 P0/P1/P2，不编辑文件或改变任务状态 |
| Codex 主 Agent | 唯一交付负责人，检查 diff、裁决发现、修复、集成和验收 |
| Ponytail | 选择最小充分方案，不弱化功能、安全、业务规则或验证 |

该 Skill 不拥有长期项目队列。处于 LoopX 工程计划中时，LoopX 仍是唯一任务状态源；长期多任务管理应使用 [`loopx-engineering-manager`](https://github.com/huangcongqiang/loopx-engineering-manager)。

## 适用范围

适合：

- 多步骤代码、API、Schema、架构或 UI 实现；
- 明确要求 Claude 实施、独立复审或持续 review-fix；
- 需要严格控制 diff 范围、处理 Claude 空 diff 或保护现有用户改动；
- 需要对照 Figma、截图、演示项目和既有规格交付。

简单且强耦合的一两行改动可由主 Agent 直接完成，同时保留必要的验证门禁。

## 依赖

- Git；
- Ruby；
- Claude Code CLI；
- `claude-code-dispatcher` Skill；
- `ponytail` Skill；
- 适用的独立 reviewer 能力，或由主 Agent 执行披露后的只读复审替代。

## 安装

```bash
git clone git@github.com:huangcongqiang/claude-terra-delivery-loop.git \
  ~/.codex/skills/claude-terra-delivery-loop
```

确保依赖 Skill 已安装在 Codex 可发现目录中。

## 使用

在 Codex 中显式调用：

```text
使用 $claude-terra-delivery-loop 按任务卡完成实施、复审、修复、验证与集成。
```

任务包至少应冻结：

- 一个可观察目标；
- 绝对工作目录和不可变基线；
- 权威规格、代码入口及 Figma/演示引用；
- Ponytail 强度、最小充分方案层级和明确非目标；
- 允许与禁止修改范围；
- 验收标准和精确验证命令。

完整模板见 [`references/task-packets.md`](references/task-packets.md)。

## Diff 范围门禁

```bash
ruby scripts/check_delivery_diff.rb \
  --repo /absolute/worker/repo \
  --base BASELINE_SHA \
  --allow 'design/api/*' \
  --allow 'design/api/**/*' \
  --expect 'design/api/openapi.yaml'
```

常用参数：

- `--allow GLOB`：允许修改的相对路径，可重复；
- `--expect GLOB`：必须出现的修改，可重复；
- `--allow-delete`：仅在任务明确允许删除时使用；
- `--allow-empty`：仅在任务明确允许空 diff 时使用；
- `--allow-ignored PATH=BASELINE`：授权一个精确 gitignored 普通文件，`BASELINE` 为修改前 SHA-256 或 `ABSENT`。

忽略文件示例：

```bash
ruby scripts/check_delivery_diff.rb \
  --repo /absolute/worker/repo \
  --base BASELINE_SHA \
  --allow 'local.fixture' \
  --expect 'local.fixture' \
  --allow-ignored 'local.fixture=7a1f...完整64位sha256'
```

不得授权忽略目录、glob、依赖/构建树或秘密文件。

## 空 Diff 与重连恢复

Claude 报告成功但没有文件变化时：

1. 先验证基线是否已经满足验收；
2. 检查 worker 目录、revision、权限、会话输出和其它 worktree；
3. 仅允许一次目标更小、目标文件和失败断言更明确的重试；
4. 仍无 diff 时由主 Agent 接管或报告真实阻塞，不对未变化代码进行虚构复审。

等待期间使用有界状态检查；两次输出不变后检查进程/会话状态，不反复新建或重连 worker。

## 验证

```bash
python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py .
ruby scripts/check_delivery_diff_test.rb
ruby -c scripts/check_delivery_diff.rb
git diff --check
```

## 仓库结构

```text
claude-terra-delivery-loop/
├── SKILL.md
├── README.md
├── agents/openai.yaml
├── references/task-packets.md
└── scripts/
    ├── check_delivery_diff.rb
    └── check_delivery_diff_test.rb
```
