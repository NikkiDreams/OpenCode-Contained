---
name: sharp-edges
description: Use when identifying APIs, configs, or patterns that are technically correct but practically dangerous.
---

# Sharp Edges

## When to Use This Skill
- Debugging unexpected behavior from seemingly correct code
- Reviewing code for hidden type coercion or silent failures
- Identifying deprecated patterns with subtle bugs
- Auditing configs that seem right but produce wrong results

## Workflow
1. Identify the suspicious code or configuration
2. Check language documentation for edge cases and known gotchas
3. Test the behavior in a minimal reproduction
4. Document the sharp edge: what looks correct, what actually happens, and why
5. Provide a safe alternative that makes the behavior explicit
6. Add a comment or lint rule to prevent recurrence

## Rules
- Document the expected behavior vs actual behavior clearly
- Provide a concrete fix, not just a warning
- Test edge cases with the exact input types involved
- Check language version — behavior may differ across versions
- Don't dismiss as "just how it works" — if it surprises users, it's a sharp edge
