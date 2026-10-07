# Resting resource preview

Patch 8 HotBar uses HighlightResourcesCommand only for transient action hover and ClearResourceHighlightsCommand on mouse leave. CAM keeps the same native resource renderer, but persistent controller focus must leave it in the resting quantity state instead of permanent hover preview.
