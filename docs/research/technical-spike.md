# Technical spike: native controller action path

## Purpose

Before implementing the final grid, prove the native controller action data and dispatch path in the current Baldur's Gate 3 build.

## Why this comes first

A visually complete grid built against guessed data bindings would create large amounts of disposable XAML and force repeated in-game trial and error.

The project instead requires evidence for the data/dispatch seam first.

## Questions to answer

1. What controller state opens when the player requests the combat action menu?
2. Which page/template renders each radial action?
3. Which bound collection contains the displayed actions?
4. Which fields expose:
   - identity;
   - name;
   - icon;
   - availability;
   - action type/category;
   - spell level;
   - cost/resources;
   - variants/upcast relationships?
5. What command/event/state transition is invoked when the player confirms an action?
6. What happens after confirmation for:
   - immediately executable actions;
   - targeted actions;
   - actions with variants;
   - upcastable spells?
7. How does cancellation return to the radial?
8. Which parts can be extended instead of overridden?

## Evidence sources

Use, in order:

1. current BG3 Toolkit/UI resources from the installed current game;
2. official Larian UI modding documentation;
3. current open-source UI mods such as ImprovedUI as structural examples;
4. older extracted UI sources only as secondary evidence, never as the sole basis for current binding names.

## Deliverable

Commit a research note containing:

- exact current state/page/resource names;
- minimal relevant XAML excerpts or descriptions where licensing permits;
- the native data binding path;
- the native selection/dispatch path;
- a proposed minimal hook;
- compatibility implications;
- unknowns that still require one in-game proof.

Then implement the smallest possible proof page.

## Success criterion

The spike is successful when a custom controller presentation can:

1. display at least one entry sourced from the native action collection; and
2. invoke that entry through the native action flow without hard-coding the action's gameplay behavior.

Until both are proven, do not build the full tab/grid product UI.
