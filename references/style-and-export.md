# Self-Contained Style, Layout, and Export

Use this reference to write a public R script whose parameters and rendering choices are visible without the rfigure skill directory.

## Contents

1. Complete parameter block
2. Explicit publication theme
3. Fonts and CJK text
4. Lowercase panel tags and layout
5. Align the data-panel rectangles
6. Fixed-aspect patchwork panels
7. Explicit export
8. Device notes

## 1. Complete Parameter Block

Put consequential values near the top of every delivered script:

```r
library(ggplot2)

FONT_FAMILY  <- "Arial"
TEXT_PT      <- 8
TAG_PT       <- 9
TEXT_GG      <- TEXT_PT / ggplot2::.pt   # .pt = 72.27 / 25.4
LINE_MM      <- 25.4 / 72
DATA_LINE_MM <- LINE_MM * 1.8

FIG_WIDTH_MM  <- 85
FIG_HEIGHT_MM <- 65
FIG_DPI       <- 600
RANDOM_SEED   <- 20260818

paper_palette <- c(
  Reference = "#6B6B6B",
  Treatment = "#0072B2"
)
```

`element_text()` sizes are points. `geom_text()` and `annotate()` use a different text unit, so use `TEXT_GG`; a bare `size = 8` there is about 22.8 pt.

## 2. Explicit Publication Theme

Write the style into the figure script. The following block may be copied and adapted; it must remain visible in the delivered file:

```r
p <- ggplot(data_to_plot, aes(x, y)) +
  geom_point() +
  theme_classic(base_size = TEXT_PT, base_family = FONT_FAMILY) +
  theme(
    text = element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    axis.text = element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    axis.title = element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    legend.text = element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    legend.title = element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    strip.text = element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    plot.caption = element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    plot.tag = element_text(
      family = FONT_FAMILY, size = TAG_PT, face = "bold", colour = "black"
    ),
    panel.border = element_rect(
      colour = "black", fill = NA, linewidth = LINE_MM
    ),
    axis.line = element_blank(),
    axis.ticks = element_line(colour = "black", linewidth = LINE_MM),
    panel.grid = element_blank(),
    plot.background = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "white", colour = NA),
    legend.background = element_rect(fill = "white", colour = NA),
    legend.key = element_rect(fill = "white", colour = NA),
    legend.key.size = grid::unit(3, "mm"),
    plot.margin = margin(2, 2, 2, 2, "mm")
  )
```

Reference/null lines use `LINE_MM`. Fitted lines, box outlines, and error bars normally use `DATA_LINE_MM` so evidence is visibly heavier than structure.

A local `publication_theme <- theme_classic(...) + theme(...)` object is acceptable when its full definition appears in the same script. Never replace the visible block with `source()` or an unavailable custom theme.

## 3. Fonts and CJK Text

Check the chosen family explicitly:

```r
available_fonts <- unique(systemfonts::system_fonts()$family)
if (!FONT_FAMILY %in% available_fonts) {
  stop("Font is unavailable: ", FONT_FAMILY)
}
```

Arial lacks CJK glyphs. For a Chinese figure set, for example, `FONT_FAMILY <- "PingFang SC"` on a compatible macOS machine, then use that variable in every text role shown above. Do not change only top-level `text`; explicit axis, legend, strip, caption, annotation, and tag families must match.

## 4. Lowercase Panel Tags and Layout

Use lowercase tags by default:

```r
library(patchwork)

composite <- (p1 | p2) / p3 +
  plot_annotation(tag_levels = "a") &
  theme(
    plot.tag = element_text(
      family = FONT_FAMILY,
      size = TAG_PT,
      face = "bold",
      colour = "black"
    )
  )
```

For an individual panel use `labs(tag = "a")`. Switch to uppercase only when the user, journal, or existing manuscript convention requires it.

- Prefer a legend inside when inspected whitespace exists; declare its NPC position and justification.
- On ggplot2 ≥ 3.5 use `legend.position = "inside"` plus `legend.position.inside = c(x, y)`.
- For a spatial panel, use a fully transparent, borderless legend background and transparent keys so the legend blends into verified map whitespace. For a non-spatial panel, use a readable, usually semi-opaque background only when transparency would reduce legibility.
- If there is no safe interior space, prefer direct labels or a right-side/shared guide. Avoid top/bottom placement as the routine fallback because it reduces data-panel height.
- Collect guides only when aesthetic meaning and scale limits are identical.
- Collect axes only when compared axes truly share a scale.
- Attach patchwork with `library(patchwork)` before using `|` or `/`; otherwise use `patchwork::wrap_plots()`.

## 5. Align the Data-Panel Rectangles

Alignment means the rendered data rectangles share edges. Equal outer plot slots are not enough: legends, axis titles, tick labels, captions, and fixed coordinates can move or shrink the panel inside each slot.

Alignment alone is not enough. A mathematically aligned grid can still be badly proportioned if notes, legends, or a mismatched canvas make the data panels tiny or very flat.

For a regular grid:

1. Use one flat `wrap_plots()` call so every row uses the same column geometry and every column uses the same row geometry.
2. Apply one explicit `aspect.ratio` to every ordinary panel that must have an equal frame.
3. Use equal `widths` and `heights` only after the common panel aspect is declared.
4. Keep the complete border theme on every panel, including heatmaps.
5. Measure panel viewport coordinates from the final composition at the final physical size.
6. Measure rendered panel height/width and total data-panel area as a share of the full figure.
7. Prefer one shared figure note outside the image over repeated prose captions beneath every panel.

```r
PANEL_ASPECT <- 0.72
PANEL_ALIGNMENT_TOLERANCE_MM <- 0.20
PANEL_ASPECT_TOLERANCE <- 0.03
MIN_PANEL_AREA_SHARE <- 0.40  # provisional diagnostic for this 2 x 2 design

composite <- patchwork::wrap_plots(
  p1 + theme(aspect.ratio = PANEL_ASPECT),
  p2 + theme(aspect.ratio = PANEL_ASPECT),
  p3 + theme(aspect.ratio = PANEL_ASPECT),
  p4 + theme(aspect.ratio = PANEL_ASPECT),
  ncol = 2,
  widths = c(1, 1),
  heights = c(1, 1)
) +
  plot_annotation(tag_levels = "a")
```

Do not use this when the rows are expected to share columns:

```r
# Each nested row can calculate different panel-column geometry.
misaligned <- (p1 | p2) / (p3 | p4)
```

At final size, require:

- panels in each column have the same left and right coordinates;
- panels in each row have the same bottom and top coordinates;
- all regular-grid panels have equal width and height;
- the rendered aspect matches the requested one at a tolerance tight enough to catch a dropped `aspect.ratio` (0.005, not 0.03);
- every deviation is no larger than the declared physical tolerance.
- each rendered panel's height/width is within the declared tolerance of `PANEL_ASPECT`;
- total data-panel area is above the declared figure-specific minimum.

The maintainer test `scripts/panel_alignment_smoke_test.R` contains a viewport-coordinate implementation. Public figure code must inline the relevant function definition; never `source()` the test or require recipients to have this skill.

For a standard 2 × 2 figure, a 40% panel-area share is a practical starting diagnostic, not a universal journal standard. Set the threshold in the public script and justify a lower value for layouts that inherently need more surrounding material.

If a guide or caption is too large, change the figure design, legend location, direct labelling, margins, or physical dimensions. Shared sample-size, uncertainty, transformation, missingness, and exclusion information can live in one figure-level caption or notes block outside the image. Do not declare success because the outer canvases occupy equal slots, and do not solve the problem by making the data panels unreadably small.

## 6. Fixed-Aspect Patchwork Panels

`coord_fixed()`, `coord_equal()`, `coord_polar()`, and `coord_sf()` cannot always be both evenly sized and aligned.

1. Leave patchwork widths/heights as `NA` when fixed aspect should control space, and leave them unset entirely when `theme(aspect.ratio)` is what defines the panel shape. Explicit numeric `widths`/`heights` make each panel fill its slot and silently discard `aspect.ratio`: measured on ggplot2 4.0.3 / patchwork 1.3.2, requesting 0.618 with `widths = c(1, 1), heights = c(1, 1)` renders 0.570, identical to requesting nothing.
2. Use `-1null` in a mixed `grid::unit()` vector when a row/column must expand for fixed aspect:

```r
plot_layout(
  widths = grid::unit(c(1, 3, -1), c("null", "cm", "null"))
)
```

3. Use `patchwork::free()` when alignment creates waste.
3b. `plot_annotation(theme = theme(plot.margin = ...))` does not merely pad the outside of a composition: patchwork pushes that theme into every child plot, replacing each child's own `plot.margin`. Measured on a two-panel row, adding a `plot_annotation` margin moved the left panel edge from 13.46 mm to 11.53 mm and widened each panel from 43.67 mm to 45.60 mm. Use it deliberately, and re-measure the panel rectangles afterwards rather than assuming only the outer frame changed.
4. Use `wrap_elements(full = plot)` only when loss of normal panel alignment is acceptable.
5. Do not claim equal numeric widths produce equal fixed-aspect panel sizes.
6. If equal panel frames are mandatory and the fixed aspect is not scientifically meaningful, remove the fixed coordinate and apply the common panel `aspect.ratio` instead.
7. If the fixed aspect is scientifically meaningful, preserve it and give that plot a dedicated row/column, inset, or explicitly unequal layout. Never stretch a map or geometric comparison merely to make a rectangular grid look regular.

## 7. Explicit Export

Use target journal dimensions when verified. Otherwise treat these as provisional starts.

A multi-panel composite must stay at or below 210 mm of canvas width (A4 paper width) so that it can be placed into Word or a manuscript template at 100% scale; rescaling a too-wide composite shrinks 8 pt text below legibility and thins the 1 pt frame. Height carries no such ceiling. Two cases are exempt: a single-panel figure, which occupies little of the page, is rarely rescaled, and should be sized from its evidence; and an explicitly requested golden-ratio variant, where the extra width is what keeps the panels golden instead of surrounding them with empty canvas. Report the width whenever it passes 210 mm, together with the fact that such a figure will be rescaled in an A4 page.


| Use | Starting size |
|---|---|
| Small single panel | 70 × 75 mm |
| General single column | 85 × 60–80 mm |
| Square comparison | 100 × 100 mm |
| Double-column / multi-panel | 180–200 × 100–140 mm |
| China map | about 190 × 125 mm |

Single-panel entries above are starting points, not ceilings. The 210 mm ceiling applies to the composite canvas only.

Write the output path, overwrite guard, device, size, units, DPI, and background directly:

```r
output_png <- "outputs/figure.png"
dir.create(dirname(output_png), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_png)) stop("Refusing to overwrite: ", output_png)

ggsave(
  filename = output_png,
  plot = p,
  device = ragg::agg_png,
  width = FIG_WIDTH_MM,
  height = FIG_HEIGHT_MM,
  units = "mm",
  dpi = FIG_DPI,
  bg = "white"
)

stopifnot(file.exists(output_png), file.info(output_png)$size > 0)
```

For SVG, repeat the call with `device = svglite::svglite`. For TIFF, use `device = ragg::agg_tiff` and `compression = "lzw"`.

Long notes need explicit wrapping and bottom space:

```r
wrapped_note <- paste(strwrap(long_note, width = 72), collapse = "\n")

p <- p +
  labs(caption = wrapped_note) +
  theme(
    plot.caption = element_text(hjust = 0, lineheight = 1.05),
    plot.margin = margin(2, 2, 5, 2, "mm")
  )
```

Increase figure height if needed. Correct pixel dimensions do not prove captions or legends are unclipped; inspect the rendered file.

## 8. Device Notes

- PNG: `ragg::agg_png`.
- TIFF: `ragg::agg_tiff` with LZW compression.
- SVG: `svglite::svglite`; fonts are normally referenced, not embedded.
- PDF on macOS: use an explicit Quartz PDF device and test the result.
- PDF elsewhere: use `grDevices::cairo_pdf` only after opening a small probe file and drawing text successfully. `capabilities("cairo")` alone can be a false positive.
- If no verified font-aware PDF device is available, export SVG and convert it with a trusted tool while preserving page size.

Inspect physical dimensions, resolution, fonts, background, clipping, and file size after export.

For an explicitly requested golden-ratio variant, define the constant in the public script, hold the canvas ratio near-exact, hold the panels inside a declared ratio band (1.50 to 1.75 by default) rather than on the point value, choose the width the geometry needs and report it if it passes 210 mm, set the outer height from the width, and verify the rendered panel ratios rather than trusting layout inputs. Preserve fixed-aspect map geometry even when that prevents an exact golden panel.

Official references:

- [ggplot2 theme reference](https://ggplot2.tidyverse.org/reference/theme.html)
- [ggplot2 ggsave reference](https://ggplot2.tidyverse.org/reference/ggsave.html)
- [ragg agg_png reference](https://ragg.r-lib.org/reference/agg_png.html)
- [patchwork layout guide](https://patchwork.data-imaginist.com/articles/guides/layout.html)
