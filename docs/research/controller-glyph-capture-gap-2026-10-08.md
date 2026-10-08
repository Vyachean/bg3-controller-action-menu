# 2026-10-08 — resource point glyph mismatch: missing controller evidence

The operator reports **no visible change** after 0.0.91's
`LSActionPointResources.ActionPointTemplate` override. It is not a runtime
fix. Do not publish a new size/icon guess.

Exact installed Xbox App 1.8.910.0 source in
`bg3-controller-action-menu-inputs-20261008-093541.zip` confirms:

- `Mods/MainUI/GUI/Pages/HotBar.xaml` renders
  `ActionResourcesCostPreview` via `ActionResourcesList` and
  `LSActionPointResources(Style=ActionResourcesTemplateSelector)`.
- `Public/Game/GUI/Library/DataTemplates.xaml` defines the keyboard
  resource point renderer with `IconIdToSourceConverter` and the
  `ActionResourcePoint*IconsPath` resources.
- `Public/Game/GUI/Library/Libs_Controller.xaml` merges
  `DataTemplates_c.xaml` and `ActionResourceTemplates_c.xaml`.
- Neither controller file was included by the old capture expressions.

An **old** public `akintos/bg3-data` mirror shows genuinely different
controller resource icon assets and sizes in these files. It is corroborating
architectural evidence, **not** current Patch 8 source.

The next release therefore performs one read-only capture through the same
universal VBS. It explicitly requires all of:
`Public/Game/GUI/Library/DataTemplates.xaml`,
`Public/Game/GUI/Library/DataTemplates_c.xaml`,
`Public/Game/GUI/Library/ActionResourceTemplates_c.xaml`, and
`Mods/MainUI/GUI/Pages/HotBar.xaml`. Missing packaged files fail closed;
SHA256 and exact packaged paths appear in the manifest.

No mod/runtime XAML or gameplay behavior is changed in this milestone.
The installed game PAK, saves, mod configuration and installed CAM mod are
not modified by capture. Compare the two native renderer stacks before
choosing a new runtime seam or asking for an in-game test.
