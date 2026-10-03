# AGENTS.md

## Project objective

Build a controller-first replacement for Baldur's Gate 3 action radials.

The preferred end state is a tabbed grid that exposes the complete action set without forcing the player through many radial pages.

## Non-negotiable architecture rules

1. **BG3 remains the source of truth.**
   Do not reimplement spell availability, action costs, targeting, upcasting, recasts, cooldowns, resources, or execution rules if the existing UI/action model can provide them.

2. **Thin UI adapter.**
   The mod may categorize and present actions, but should pass selection back into the native action flow whenever possible.

3. **Controller-first.**
   Every interactive element must have deterministic controller focus/navigation. Mouse support is secondary.

4. **Do not optimize around unverified assumptions.**
   If an engine binding, data shape, page/state name, or dispatch mechanism is not proven against the current game/toolkit, document it as an assumption and isolate it behind a spike.

5. **Minimize manual testing.**
   Add static validation and fixture-driven tests for everything that does not require the running game.

6. **Milestone game tests only.**
   In-game testing should be requested only when a build crosses a defined proof boundary that cannot be established statically.

## Development order

1. Research and document the current controller action UI/data path.
2. Prove read access to the native action collection.
3. Prove dispatch of one selected native action.
4. Build the smallest navigable controller grid.
5. Add categorization/tabs.
6. Add spell-level filtering.
7. Cover edge cases: upcast, variants, recast, toggles, temporary actions, item actions, class resources.
8. Polish and compatibility work.

## Pull request expectations

Every PR must state:

- what behavior or assumption it proves;
- what can be validated automatically;
- what still requires an in-game proof;
- whether it changes any documented architecture decision.

Do not claim in-game behavior is working unless it has been proven in-game.
