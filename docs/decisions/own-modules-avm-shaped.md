---
title: Own modules, AVM-shaped interfaces
description: Why this repo writes its own Terraform modules instead of consuming Azure Verified Modules, and why their interfaces copy AVM anyway.
category: decisions
order: 20
updated: 2026-10-15
status: living
---

## Context

Every stack in this repo used to declare its resources inline. As the
estate grew to five stacks, the same patterns (resource groups, Front
Door, naming, tagging) were repeated with small differences, and house
rules lived in reviewers' heads rather than in code.

Microsoft publishes [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/)
(AVM): supported, tested modules for most Azure resource types. The
obvious move would be to consume them.

## Decision

Write our own modules in `modules/`, but shape their interfaces like
AVM's. The resource group module, for example, takes `lock` and
`role_assignments` with `role_definition_id_or_name`, exactly as
`Azure/avm-res-resources-resourcegroup` does.

## Why not just use AVM

- **House rules need a home.** AVM modules are deliberately general.
  Ours refuse things at plan time: a region outside the UK, a resource
  group without an owner tag, a permanent Owner grant. Wrapping an AVM
  module to add those checks is possible, but then there are two layers
  to read instead of one.
- **Small surface, fully understood.** The resource group module's
  logic is about 50 lines of HCL. Every line is reviewable in one sitting, which
  matters for a codebase whose readers are often auditing it.
- **No telemetry by default.** AVM modules send usage telemetry to
  Microsoft unless `enable_telemetry = false` is set. Easy to switch off, but one
  more thing for every caller to remember.

## Why copy the AVM interface anyway

- Engineers who know AVM can read our module calls without opening the
  module.
- If AVM becomes the better trade-off (a new resource type, a complex
  one like Key Vault or Container Apps, or a client mandate), switching
  is a `source` change and some `moved` blocks, not a rewrite of every
  caller.

## Consequences

- Each module carries its own tests. Native `terraform test` with a
  mocked azurerm provider means the suite runs in CI with no Azure
  credentials (`.github/workflows/modules.yml`).
- Adopting a module in a live stack must be a state rename only. Each
  adoption uses `moved` blocks and has to show
  **0 to add, 0 to change, 0 to destroy** before it merges.
- For resource types where AVM's breadth clearly beats our opinions,
  this decision gets revisited per module rather than repo-wide.

## Alternatives considered

- **Consume AVM directly.** Least code to own, but the house rules
  would move back into review comments.
- **Wrap AVM modules.** Keeps AVM's maintenance, adds our checks, but
  doubles the layers to read and debug for very small resources.
- **No modules.** Fine for one stack; at five, the duplication was
  already producing drift between them.
