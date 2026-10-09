# Resting resource preview

Patch 8 HotBar uses HighlightResourcesCommand only for transient action hover and ClearResourceHighlightsCommand on mouse leave. CAM keeps the same native resource renderer, but persistent controller focus must leave it in the resting quantity state instead of permanent hover preview.

## 2026-10-09 corrective candidate for #166 — native predicted cost in external resource bar

Operator testing established a missing controller capability: unlike vanilla radials, CAM does not highlight the resources an action would consume in the standard resource bar. The 0.0.75 failure concerned the **CAM-owned upper tab preview**, not permission to remove feedback from the game-owned normal HUD.

To preserve the distinction, CAM's upper `LSActionPointResources` renderer must keep the native action-resource identity, available count, maximum, icon source and Roman levels, but explicitly **not** inherit action-hover cost highlighting (`HighlightedActionPoints=0`). The original external bar is not replaced or re-rendered. Only BG3's `HighlightResourcesCommand` receives the actual focused `VMHotBarSlot`, after the native 70ms focus-stability handoff. The focus-change boundary must clear stale highlights first; the delayed route must never clear its just-applied cost.

This replaces the old CAM-specific prohibition on highlighting **only for a source-level candidate**. It does not invalidate the historical 0.0.75 runtime finding and must not be merged or released as proven without the combined milestone game test: verify resting upper tab icons/counters remain correct while actual predicted cost appears in the external bar; move focus across actions/zero-cost/spells/metamagic, leave the menu, and change tabs. It remains unproven whether the native game HUD's preview command and CAM's tab preview share a view-model state that can affect other UI unexpectedly.
