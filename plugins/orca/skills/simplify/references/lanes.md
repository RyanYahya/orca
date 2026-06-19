# Simplify lane briefs

Four independent review angles. Each runs read-only over the same diff and returns findings in the shared format (file/line/angle/summary/fix). Apply only behavior-preserving cleanups.

## Reuse

Flag new code that re-implements something the codebase already has. Search shared/utility modules and files adjacent to the change. Name the existing helper or pattern to use instead.

## Simplification

Flag unnecessary complexity the diff adds: redundant or derivable state, copy-paste with slight variation, deep nesting, dead code left behind, or abstractions that don't pay for themselves. Name the simpler form that does the same job.

## Efficiency

Flag wasted work the diff introduces: redundant computation or repeated I/O, independent operations run sequentially, blocking work added to startup or hot paths, or long-lived objects that retain large enclosing scopes. Name the cheaper alternative.

## Altitude

Check that each change is implemented at the right depth, not as a fragile local patch. Special cases layered onto shared infrastructure signal the fix isn't deep enough; prefer generalizing the underlying mechanism over adding one-off branches.
