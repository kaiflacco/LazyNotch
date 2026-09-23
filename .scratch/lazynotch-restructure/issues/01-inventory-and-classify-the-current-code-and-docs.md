# Inventory and classify the current code and docs

Type: task
Label: wayfinder:task
Status: resolved

## Question

Which current source files, assets, documentation files, generated outputs, and working-tree deletions are referenced, reachable, stale, generated, or orphaned? Produce a retention/deletion classification and identify broken references without deleting anything. Treat current modifications as input.

## Answer

- **Live application source:** the tracked Swift source plus the untracked `CodexUsageService` and `MediaRemoteBridge` additions are referenced by the app. The Codex service is wired into shell presentation and settings; the media bridge is used by the media service. Neither is an unused-file candidate.
- **Current implementation changes:** the modified Swift files and `Info.plist` are user work and must be preserved for later architectural and UI decisions. No reset or revert is authorized.
- **Documentation:** the tracked design, product, engineering, and research Markdown files are deleted in the working tree, but `README.md` and `INDEX.md` still link to many of them. Those links are broken. The README also references three missing design images. Documentation disposition remains a separate decision; nothing is deleted or restored by this inventory.
- **Workflow/planning files:** `.agents/`, `AGENTS.md`, `docs/agents/`, `.scratch/`, and `skills-lock.json` are Codex/skill and planning artifacts, not application runtime files. Keep them unless a later workflow decision says otherwise.
- **Build/runtime artifacts:** `.build/`, `main`, and `screenrecording/` are ignored local artifacts according to `.gitignore`. `LazyNotch.app` is a partially tracked app bundle scaffold with its executable ignored; treat it as a build/runtime artifact, not source to refactor or delete during this effort.
- **No deletion candidates are proven yet:** the inventory identifies broken documentation references and stale/missing assets, but no source or feature file can be safely deleted without the architecture and documentation disposition decisions.

The next decisions can now use this classification: define module/state boundaries, define in-process service contracts, decide the documentation and deletion policy, and choose the migration and verification order.
