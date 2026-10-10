# Article pages

The desk source uses discrete sheets instead of mouse-wheel scrolling. Short
sources show one sheet without navigation; long sources show **← 1 / N →**
below the body. PageUp/PageDown also turn pages. The font size stays unchanged.
The article number and selected headline refer to the whole article.

## View and layout

- `Scenes/source_pager.tscn` and `Scripts/source_pager.gd` own navigation and layout.
  `newsroom_screen.gd` instances the scene as `Canvas/World/SourcePages`, beside
  the existing `SourceText`; the desk scene's authored layout is preserved.
- The screen's **Source Page Scene** accepts the page-control scene. In that
  scene, **Turn Seconds** defaults to 0.6, **Footer Gap** to 20 canvas pixels,
  and **Paragraph Fill Minimum** to 0.55. Button styling uses muted paper/olive
  colors. `Row` contains the two buttons and the counter. Navigation uses
  z-index 7: above the paper marks, below the stamp, pencil, eraser and desk shadows.
- A hidden, non-threaded RichTextLabel shapes the full plain-text source with
  the body's font, width and spacing. Native line ranges and heights choose
  contiguous character spans. A paragraph boundary is preferred when at least
  55% of the sheet is filled; oversized paragraphs split at wrapped lines.
- The visible label holds only the current span. Newline separators at a sheet's
  edges are omitted from the view; the complete `source_text` is preserved.
  The last sheet starts at the top with no duplicated earlier lines. Layout is
  calculated on a new source, resize or theme change, rather than every frame.
- Page changes absorb and reveal the body, all marks and the paginator through
  the same flowing ink mask. The old sheet disappears before the hidden content
  swap; the next sheet then appears. Blank-paper portions share the same page
  anchor as the rest of the stroke. The article title, number and seal stay stable
  during page turns; their longer ink transition runs when changing articles.
- Separate `page_absorption_progress` / `page_reveal_progress` uniforms preserve
  the article's own transition. The body/paginator share one local material;
  the brush has its own grain-enabled copy with synchronized progress.

## Tools and saves

`ProofreadingSurface.bind(body, state, character_offset)` displays a page while
the state keeps the complete typo copy. Page-local line ranges are translated
to full-source character offsets for targets and strokes. `set_page_offset()`
finishes an active stroke and rebuilds only the visible geometry. The original
two-argument `bind()` remains available for standalone surfaces.

The pencil can stay held while using navigation; page buttons are GUI input
exclusions. The eraser can also stay held. Drawing, erasing and stamping wait for a page transition to finish.
The stamp publishes the whole article from any sheet; no reading minimum is
enforced. Navigation is blocked during stamp movement, publication feedback,
headline choices and the article's ink transition. The footer is excluded from
the seal footprint.

`presentation.newsroom.source_article_id` and `source_character` retain the
reading position. Character anchors survive a different pagination layout;
the article ID prevents a stale page from being applied to another material.
Saving during a page turn retains its destination. Older saves without these
optional fields start on the first sheet. Typos, mark IDs and qualification
settlement retain their values; the current typo schema is documented in
[PROOFREADING.md](PROOFREADING.md). Live publication feedback
does not reset the current sheet.

Native layout API: [RichTextLabel](https://docs.godotengine.org/en/stable/classes/class_richtextlabel.html).
