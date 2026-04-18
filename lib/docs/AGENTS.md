# AGENTS.md

## Review guidelines

- Prioritize architecture integrity over stylistic issues.
- Flag any logic placed in widgets that should live in services.
- Flag duplicate calculations when totals tables should be the source of truth.
- Flag schema drift between docs and code.
- Treat changes that break stock/custom shared pipeline as high severity.
- Prefer small, surgical diffs over broad rewrites.
- Do not suggest moving logic into UI for convenience.
- Call out missing tests or validation steps when changes affect scoring, totals, badges, or completion flow.