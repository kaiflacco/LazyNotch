# Decide the documentation and deletion disposition

Type: grilling
Label: wayfinder:grilling
Status: resolved
Blocked by: 01

## Question

After the inventory, decide which current source files, assets, and documentation are retained, rewritten, or deleted. Remove stale README and index links, preserve useful project knowledge, and require explicit evidence before deleting ambiguous files or feature code.

## Answer

- Retain `README.md`, `CONTEXT.md`, `AGENTS.md`, `docs/agents/`, `.scratch/`, `.agents/`, and `skills-lock.json` as current product, domain, agent-workflow, or local planning artifacts.
- Keep the previously deleted design, product, engineering, and research documents deleted. Do not restore obsolete documentation wholesale; preserve durable knowledge through `CONTEXT.md`, the active spec, tickets, and ADRs when needed.
- Rewrite stale README and index links to point only to existing documentation, and remove references to missing image assets unless an asset is later proven necessary.
- Retain ambiguous source files, assets, and the `LazyNotch.app` scaffold. Delete them only after direct evidence shows no build, runtime, resource, supported-feature, or documentation role.
