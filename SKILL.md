---
name: rfigure.skill
description: Use when creating, revising, or reviewing R/ggplot2 statistical figures for research papers, theses, ecology/environmental analyses, model outputs, grouped comparisons, maps, matrices, or multi-panel layouts that should follow Qiongwei's established plotting style.
---

# rfigure.skill

## Core Idea

This is a general scientific statistical plotting style, not a recipe book for one analysis method. First identify the statistical message, then choose the geometry, annotation, scale, and colors that make the evidence readable.

The style is evidence-first: clean white background, compact paper-ready typography, explicit statistical evidence, restrained color, and consistent visual language across the whole paper.

## Non-Negotiable Base

For formal publication-style figures:

1. Use Arial 8 pt for all text: axis text, axis titles, legends, annotations, facet strips. Tags (panel labels a/b/c/d) may be 9–10 pt **bold** as the only allowed exception.
2. Draw a black four-sided border around every panel.
3. Structural lines (panel border, axis ticks, reference/null lines) are 1 pt: set `LW <- 25.4 / 72`. Data geometries (fitted lines, error bars, box outlines) should be **clearly** heavier than structure — use `LW * 1.7` to `LW * 2.0` so data > structure. Lower factors (1.3–1.4×) sit below the perceptual threshold for line-weight differentiation at typical panel widths (60–100 mm) and produce figures where data lines are indistinguishable from the panel border.
4. Do not draw separate `axis.line`; the panel border is the axis frame.
5. Use a white plot/panel background.
6. Export in physical units (`mm`, `cm`, or `in`) at 300 or 600 DPI. Use a font-aware device (`ragg::agg_png`, `cairo_pdf`) — see "Engine and Fonts" below.

Requires ggplot2 ≥ 3.5 (for `legend.position = "inside"`, `geom_errorbar(orientation = "y")`); ggplot2 ≥ 3.4 if you only need `linewidth`. `geom_errorbarh()` emits a deprecation warning under 4.0.

```r
LW     <- 25.4 / 72                  # 1 pt expressed in mm (ggplot2 linewidth unit)
LW_DAT <- LW * 1.8                   # default weight for data lines / fitted lines (≥ 1.7× LW)
TXT_PT <- 8                          # in-points text size everywhere
TXT_TAG <- 9                         # panel tag (a/b/c/d) — the only allowed exception
TXT_GG <- TXT_PT / ggplot2::.pt      # SAME size for geom_text/annotate (mm under the hood)

theme_qw_pub <- function(base_pt = TXT_PT, lw = LW) {
  theme_classic(base_size = base_pt, base_family = "Arial") +
    theme(
      text         = element_text(family = "Arial", size = base_pt, colour = "black"),
      axis.text    = element_text(family = "Arial", size = base_pt, colour = "black"),
      axis.title   = element_text(family = "Arial", size = base_pt, colour = "black"),
      legend.text  = element_text(family = "Arial", size = base_pt, colour = "black"),
      legend.title = element_text(family = "Arial", size = base_pt, colour = "black"),
      strip.text   = element_text(family = "Arial", size = base_pt, colour = "black"),
      panel.border = element_rect(colour = "black", fill = NA, linewidth = lw),
      axis.line    = element_blank(),
      axis.ticks   = element_line(colour = "black", linewidth = lw),
      panel.grid   = element_blank(),
      plot.background  = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA),
      # Inside-panel legends need an opaque background or they bleed into data:
      legend.background = element_rect(fill = "white", colour = NA),
      legend.key        = element_rect(fill = "white", colour = NA),
      legend.margin     = margin(1, 2, 1, 2, "mm"),
      legend.key.size   = unit(3, "mm"),
      plot.margin  = ggplot2::margin(2, 2, 2, 2, "mm")
    )
}
```

**Critical text-size trap.** `element_text(size = 8)` is points; `geom_text(size = 8)` and `annotate("text", size = 8)` are millimetres (≈ 22.6 pt). Always pass `size = TXT_GG` (= `8 / ggplot2::.pt`) to in-panel text, never the bare `8`. This single mistake produces axis-text-vs-annotation size mismatches in roughly every first attempt.

For maps or matrices, axes/gridlines may be hidden or softened, but font, white background, black panel border, and 1 pt frame still anchor the figure.

## Engine And Fonts

Default R devices on macOS cannot find "Arial" in the PostScript font database, producing dozens of `font family 'Arial' not found` warnings and silently broken PDFs. Use a font-aware engine:

```r
# Once per session, before any ggsave():
options(warn = 1)                                # surface warnings immediately
suppressPackageStartupMessages({
  # Required for every figure that uses this style:
  library(ggplot2)        # ≥ 3.5; under 4.0 geom_errorbarh() emits deprecation warnings
  library(systemfonts)    # font discovery
  library(ragg)           # font-aware raster devices
})
# Load only when the figure actually uses them:
# library(patchwork)    # multi-panel layouts (|, /, plot_layout, plot_annotation)
# library(svglite)      # SVG export
# library(ggpp)         # geom_text_npc() for NPC-coordinate annotations
# library(ggrastr)      # rasterise heavy point layers (n ≳ 1e5)
# library(ggsignif)     # pairwise significance brackets

# Detect → register fallback → assert (not assert-then-register, which makes
# the fallback unreachable):
have_arial <- "Arial" %in% systemfonts::system_fonts()$family
if (!have_arial) {
  # Linux/CI: alias a metrics-compatible font (Liberation Sans ≈ Arial)
  # Chinese labels: also alias a CJK font, otherwise Arial drops glyphs.
  liberation <- Sys.glob("/usr/share/fonts/**/LiberationSans-Regular.ttf")
  if (length(liberation)) systemfonts::register_font("Arial", plain = liberation[[1]])
  have_arial <- "Arial" %in% systemfonts::system_fonts()$family
}
stopifnot(have_arial)
```

Export rules:

- **Raster (PNG/TIFF/JPEG)**: `ggsave(..., device = ragg::agg_png)` / `agg_tiff`. This is the default. 600 dpi at the final physical size is acceptable for nearly every journal.
- **Vector (SVG)**: `ggsave(..., device = svglite::svglite)`. SVG is the safest font-aware vector format on macOS without XQuartz.
- **Vector (PDF)** is awkward on macOS:
  - `cairo_pdf` requires XQuartz (`/opt/X11/lib/libXrender.1.dylib`); without it, R silently falls back to the non-font-aware `pdf()` device and produces hundreds of `Arial' not found` warnings + a broken PDF.
  - If you need PDF, install XQuartz (`brew install --cask xquartz`) and then use `cairo_pdf`, **or** export SVG via `svglite` and convert with `rsvg-convert -f pdf` / Inkscape.
  - `ragg` does **not** ship a PDF device.
- Fallback when `systemfonts`/`ragg` is unavailable: `showtext::showtext_auto()`. With `showtext`, prefer `units = "in"` because `dpi` is silently ignored on some downstream devices.
- Linux/CI: install `ttf-mscorefonts-installer` (or alias Liberation Sans as Arial via `systemfonts::register_font(name = "Arial", plain = "<path-to-LiberationSans-Regular.ttf>")`).

Treat any `font family 'Arial' not found` warning as a hard failure, not a cosmetic notice.

**Chinese / CJK labels.** Arial has no CJK glyphs; mixing Chinese text in an Arial-family figure produces tofu boxes (`☐`). Either keep all in-figure text English (axis titles, legend labels) and put Chinese only in the caption, or set the family to a CJK-capable font that also renders Latin cleanly:

```r
# Pick a CJK font available on the system; fall back to PingFang on macOS.
cjk <- intersect(c("Source Han Sans SC", "Noto Sans SC", "PingFang SC"),
                 systemfonts::system_fonts()$family)[1]
theme_qw_pub_cjk <- function() theme_qw_pub() +
  theme(text = element_text(family = cjk),
        axis.text = element_text(family = cjk),
        axis.title = element_text(family = cjk))
```

## Layout And Legends

Design the final physical layout before writing plot code. Decide the single-panel size, combined-figure size, panel arrangement, legend placement, and relative panel widths/heights as part of the figure design.

Rules:

- Match the panel arrangement to the comparison. If panels are meant to be compared side by side, use a horizontal layout; use vertical layouts only when the evidence reads naturally from top to bottom or one panel needs more vertical space.
- Preserve panel proportions in multi-panel figures. Do not stretch one panel or compress another just because it fills a `patchwork` layout.
- Place legends in unused data-area whitespace when possible. Keep them away from fitted lines, intervals, points, and statistical annotations.
- **Positively-sloped scatter is a special case**: top-right is taken by the statistical annotation, bottom-right by the rising data tail, top-left by the y-axis tail, and bottom-left by the x-axis tail. There is rarely an inside-panel slot that doesn't overlap data. For these figures, prefer one of: (a) `legend.position = "right"` (outside, narrow, `legend.key.width = unit(2.5, "mm")`); (b) **direct labels at line ends** via `ggrepel::geom_text_repel(direction = "x", hjust = 0)`; (c) drop the legend entirely if axis title or caption already names the groups.
- ggplot2 ≥ 4.0 syntax for in-panel legends: `theme(legend.position = "inside", legend.position.inside = c(x, y))`. The deprecated `legend.position = c(x, y)` still works but emits warnings.
- Prefer one-row or one-column legends. Avoid wrapped, multi-line legends that consume plot area or change panel proportions.
- In combined figures, remove repeated legends and keep only the legend needed to decode each panel.
- If direct labels already explain color meaning, omit the legend rather than duplicating the explanation.
- **Matrix / heatmap colorbars default to outside the panel**, not inside. The empty triangle of a triangular correlation matrix is *not* safe whitespace — a vertical colorbar will visually cross data rows. Use `theme(legend.position = "right", legend.key.width = unit(2.5, "mm"))` and only move it inside if you have measured the empty area against the legend bbox.
- Panels with `coord_fixed()` / `coord_equal()` refuse to stretch and break `patchwork`'s default equal-size layout. **`plot_layout(widths = c(1, 1))` does NOT equalize panel sizes** when both panels have `coord_fixed` but different scale types (continuous vs discrete) or different data ranges; the resulting widths depend on data range and font extent. Two reliable workarounds:

    **Recipe A — wrap each fixed panel in `wrap_elements()` so its slot can centre it:**
    ```r
    p_a_wrapped <- patchwork::wrap_elements(full = panel_a)
    p_b_wrapped <- patchwork::wrap_elements(full = panel_b)
    combined <- p_a_wrapped + p_b_wrapped + plot_layout(widths = c(1, 1))
    ```
    Each fixed panel keeps its data aspect; surrounding whitespace soaks up the slack.

    **Recipe B — pre-compute the data aspect and pass it to `widths`:**
    ```r
    a_aspect <- diff(range(d$y_var)) / diff(range(d$x_var))
    combined <- panel_a + panel_b + plot_layout(widths = c(a_aspect, 1))
    ```

    If neither produces an acceptable balance, render each panel to its own grob with known mm dimensions and composite via `gridExtra::grid.arrange(grobs = ..., widths = grid::unit(c(85, 85), "mm"))`.

Standard panel tag (`a`, `b`, ...): place via `labs(tag = "a")` plus `theme(plot.tag = element_text(face = "bold", size = TXT_TAG), plot.tag.position = c(0.02, 0.98))`. Prefer `patchwork::plot_annotation(tag_levels = "a")` for multi-panel figures so tags are consistent automatically.

## Color System

Color is semantic, not decorative. Across one paper, the same meaning must keep the same color. Do not choose a new palette for each figure.

### Structural Colors

Use black and grey for structure so data colors carry meaning.

```r
col_text <- "black"
col_border <- "black"
col_ref <- "grey40"
col_light_ref <- "grey70"
col_land <- "#EFEFEF"
col_map_border <- "#CCCCCC"
```

Black: text, panel borders, axis ticks, point outlines, significance brackets.  
Grey: reference lines, 1:1 lines, map outlines, non-focal guides, missing or background classes.

### Data Colors

Do not hard-code a universal meaning for a specific hue. Define a paper-level palette for the current project, then reuse it consistently.

Rules for choosing data colors:

- Assign colors by semantic role within the paper, not by chart type or analysis method.
- If the paper already has a palette, preserve it.
- If the paper introduces a new semantic group, choose colors that are visually distinct, printable, and not easily confused in grayscale.
- Ordered groups should use an ordered sequence; unordered categories should use distinct categorical colors.
- Continuous magnitudes should use sequential gradients unless the scale has a meaningful midpoint.
- Signed effects, correlations, residuals, or anomalies should use diverging gradients centered at zero.
- Large categorical systems, such as land-cover or biome classes, may use a fixed palette, but the palette belongs to that category system rather than to this skill.

Write project colors near the top of each script. Use concrete hex values, not placeholder symbols, and name entries by *scientific meaning*:

```r
# Replace the hexes with the real paper palette. Names should be the role,
# not "color1"/"groupA" — these names appear in legends and aes(values=).
paper_palette <- c(
  "Forest"     = "#3B8686",
  "Grassland"  = "#E08214",
  "Cropland"   = "#7A4FB7"
)

# Apply with `breaks = names(paper_palette)` so legend order follows your
# declared role order, not alphabetical:
# scale_colour_manual(values = paper_palette, breaks = names(paper_palette))
# scale_fill_manual(values   = paper_palette, breaks = names(paper_palette))
#
# Or pin the order at the data level:
# dat$group <- factor(dat$group, levels = names(paper_palette))
```

The skill enforces consistency and restraint, not a universal set of data hues.

### Palette Helpers

External palette tools such as [ColorSpace](https://mycolor.space/) may be used to generate candidate palettes, but they do not decide the scientific mapping.

Use this workflow when no manuscript palette already exists:

1. List the color roles first: variable classes, treatments, model families, vegetation types, mechanisms, response groups, time periods, or effect signs.
2. Choose one anchor color from the research theme, object, or existing manuscript style.
3. Generate candidate palettes from that anchor color using ColorSpace or a similar tool.
4. Select candidates by data structure: distinct colors for unordered categories, ordered sequences for ordered groups, sequential gradients for continuous magnitudes, and diverging palettes centered at zero for signed effects.
5. Check that one hue does not carry two different meanings in the same paper or combined figure.
6. Write the final hex values into the script as a named palette so the figure is reproducible.

### Palette Construction

Build the palette before drawing the figures. Treat it as part of the paper design:

1. List the recurring semantic roles in the manuscript: treatments, models, vegetation types, mechanisms, response groups, time periods, or effect signs.
2. Decide which roles must be compared directly. Give directly compared roles the clearest separation.
3. Decide which role is primary. Make the primary role visually stronger than secondary roles through saturation, darkness, or line weight, not by adding extra colors.
4. Reuse the same named palette in every script. The palette names should be scientific meanings, not temporary labels like `color1`.

Pairing rules:

- Two groups: use two clearly separated hues with similar visual weight, unless one is explicitly the reference. If one is the reference, make the reference quieter and the focal group stronger.
- Three groups: use a balanced triad or an ordered light-middle-dark sequence depending on whether the groups are unordered or ordered.
- Four to eight groups: use a categorical palette with moderate saturation and similar brightness; avoid one category accidentally dominating.
- More than eight groups: reduce the number of shown categories, facet, direct-label, or use a recognized category palette for that classification system.
- Ordered categories: vary lightness or hue in a perceptual order; do not use arbitrary categorical colors.
- Continuous values: use a sequential gradient with monotonic lightness.
- Values with a meaningful center, especially zero: use a diverging gradient with the neutral color at the center.

Layering rules:

- Points and bars carry the main data color.
- Fitted/model lines should be darker or more saturated than their uncertainty bands.
- Uncertainty bands should use the same hue family as the fitted line, with lower opacity or lighter color.
- Reference lines, null lines, brackets, and borders stay black/grey.
- Large filled areas need calmer, lighter colors than small points or thin lines.
- If multiple geoms encode the same group in one panel, keep them in the same hue family rather than assigning unrelated colors.

Avoid:

- Default rainbow palettes.
- High-saturation colors over large areas.
- A different palette for each figure.
- Using color to decorate non-data elements.
- Reusing the same hue for different meanings in different panels of the same paper.

### Color Discipline

- One ordinary panel should usually use 1 to 3 meaningful colors.
- Use more colors only for true categorical sets such as land-cover classes.
- Uncertainty bands should be lighter and quieter than the fitted line (`alpha` about 0.15-0.35).
- Do not reuse a color for two different meanings in the same paper.
- Do not color titles, axes, borders, or decorative elements.
- Keep legends only when color meaning is not self-evident from labels or direct annotations.
- **Colour-blind / B/W parity:** when group identity matters, also map `shape` (points), `linetype` (lines), or fill pattern. Verify the palette with `colorBlindness::cvdPlot()` or `dichromat::dichromat()` before final export.

## Choose the Plot by Evidence Type

Think in statistical roles, not method names.

### Distribution Or Group Differences

Use boxplots, violins, jittered points, beeswarms, mean/median points, or intervals depending on sample size and message. Show raw points when they help reveal spread or sample size. Add `n`, median/mean labels, Tukey letters, or p-value brackets only when they answer the comparison question.

For pairwise significance brackets, use `ggsignif::geom_signif()` and pass `textsize = TXT_GG` (not the default ~3.88) plus `size = LW` to keep them in the skill's typography:

```r
ggsignif::geom_signif(comparisons = list(c("setosa", "versicolor")),
                      map_signif_level = TRUE,
                      family = "Arial", textsize = TXT_GG, size = LW,
                      tip_length = 0.01)
```

### Relationship Or Association

Use scatter points plus a fitted curve or line when inference is about association. Add confidence bands if model uncertainty matters. Report `italic(R)^2`, p-values, slopes, or thresholds only when they support the claim. For predicted vs observed or baseline vs final comparisons, use a 1:1 reference line and fixed aspect ratio.

### Model Effects Or Coefficients

Use coefficient plots, forest plots, marginal-effect curves, or interval plots. Always show the null/reference line when relevant, usually at 0 or 1. Prefer estimates with 95% CI over decorative bars.

Forest-plot geom (ggplot2 ≥ 4.0): `geom_errorbarh()` is deprecated; use the horizontal orientation of `geom_errorbar()`:

```r
ggplot(co_df, aes(est, term)) +
  geom_vline(xintercept = 0, color = col_ref, linewidth = LW, linetype = "22") +
  geom_errorbar(aes(xmin = lo, xmax = hi),
                orientation = "y",
                width = 0, linewidth = LW_DAT) +
  geom_point(size = 1.6)
```

### Ranking Or Importance

Use horizontal bars, dot plots, or lollipop plots sorted by magnitude. This applies to any model-derived or statistical importance measure. The y-axis label should name the metric, not the analysis method. Add values only when they remain readable at final figure size.

### Composition Or Proportion

Use stacked bars, grouped bars, or proportional displays only when parts-of-whole are the message. Keep category order stable across panels and use direct labels when legends become heavy.

### Spatial Evidence

Use neutral basemaps and let points, rasters, or regions carry the data. For site maps, use black-bordered filled points. Hide lat/lon labels when they do not help interpretation; keep panel border and clean map extent.

#### China Maps And Site Distributions

For China maps, use **Rimagination/ggmapcn** rather than `maps::map_data("world")` when administrative boundaries, coastlines, and the South China Sea line matter. The package gives China-specific layers through `ggmapcn::geom_mapcn()` and `ggmapcn::geom_boundary_cn()`.

Recommended dependencies:

```r
library(sf)
library(ggmapcn)    # install from: remotes::install_github("Rimagination/ggmapcn")
library(patchwork)  # for South China Sea inset placement
```

Use one projected CRS for map polygons, boundary lines, points, and labels. Convert site coordinates to `sf` before plotting; do not mix raw lon/lat points with projected `geom_sf()` layers.

```r
china_crs <- "+proj=aea +lat_1=25 +lat_2=47 +lat_0=0 +lon_0=105 +datum=WGS84 +units=m +no_defs"

sites_sf <- sites |>
  sf::st_as_sf(coords = c("lon", "lat"), crs = 4326, remove = FALSE) |>
  sf::st_transform(china_crs)

ggplot() +
  ggmapcn::geom_mapcn(admin_level = "province", crs = china_crs,
                      fill = "#F2F2F2", color = "#B8B8B8", linewidth = LW * 0.7) +
  ggmapcn::geom_boundary_cn(
    crs = china_crs,
    mainland_color = "grey35", mainland_size = LW,
    coastline_color = "#78A6C8", coastline_size = LW * 0.8,
    ten_segment_line_color = "grey35", ten_segment_line_size = LW,
    province_color = "#D0D0D0", province_size = LW * 0.55
  ) +
  geom_sf(data = sites_sf, aes(fill = group), shape = 21,
          size = 2.8, stroke = LW_DAT, colour = "black") +
  coord_sf(crs = china_crs, xlim = c(72, 142), ylim = c(12, 56),
           default_crs = sf::st_crs(4326), expand = FALSE) +
  theme_qw_pub()
```

**South China Sea / nine-dash-line rule.** If the main map focuses on mainland/site locations, do not stretch the whole map to the equator just to show the full South China Sea line. Keep the main map readable and add a South China Sea inset in the lower-right corner.

`patchwork::inset_element()` alone can misalign the inset: `coord_sf()` preserves aspect ratio and can letterbox the actual panel inside the inset slot. Avoid hand-tuned offsets. Compute the inset slot from projected aspect ratios, turn off the inset map's own panel border, then overlay a separate border-only frame. The frame is not constrained by `coord_sf()`, so its right and bottom edges can align exactly to the main panel.

```r
projected_extent_ratio <- function(xlim, ylim, crs) {
  pts <- expand.grid(lon = xlim, lat = ylim)
  pts_sf <- sf::st_as_sf(pts, coords = c("lon", "lat"), crs = 4326) |>
    sf::st_transform(crs)
  b <- sf::st_bbox(pts_sf)
  as.numeric((b[["xmax"]] - b[["xmin"]]) / (b[["ymax"]] - b[["ymin"]]))
}

main_xlim <- c(72, 142); main_ylim <- c(12, 56)
inset_xlim <- c(105, 125); inset_ylim <- c(0, 25)

main_ratio <- projected_extent_ratio(main_xlim, main_ylim, china_crs)
inset_ratio <- projected_extent_ratio(inset_xlim, inset_ylim, china_crs)
inset_height <- 0.28
inset_width <- inset_height * inset_ratio / main_ratio

p_inset_map <- p_south_china_sea +
  theme(panel.border = element_blank(),
        axis.text = element_blank(), axis.title = element_blank(),
        axis.ticks = element_blank(), legend.position = "none",
        plot.margin = margin(0, 0, 0, 0, "mm"))

p_inset_frame <- ggplot() +
  theme_void() +
  theme(plot.background = element_rect(fill = NA, colour = "black", linewidth = LW),
        plot.margin = margin(0, 0, 0, 0, "mm"))

left <- 1 - inset_width; bottom <- 0; right <- 1; top <- inset_height

p_main +
  patchwork::inset_element(p_inset_map, left, bottom, right, top, align_to = "panel") +
  patchwork::inset_element(p_inset_frame, left, bottom, right, top, align_to = "panel")
```

Use this two-layer inset pattern whenever a fixed-aspect `coord_sf()` inset must have edges flush with the parent panel. Otherwise one edge may look aligned while the other drifts.

### Matrix Evidence

Use heatmaps for correlations, confusion matrices, distance matrices, or pairwise summaries. Signed matrices should use diverging colors centered at zero. Put coefficients or significance marks inside cells only if still readable at output size.

Anchor the diagonal in the **top-left to bottom-right** direction (matrix-style indexing) so the figure reads like the printed `cor()` output: row 1 at the top, column 1 at the left. ggplot's y-axis defaults to factor level 1 at the bottom, which produces a vertically flipped matrix; pin the order with:

```r
scale_y_discrete(limits = rev(vars_order))
# or, equivalently, set: factor(y_var, levels = rev(vars_order))
```

Use explicit row/column names in long data so orientation stays unambiguous:

```r
vars_order <- c("GPP", "NEE", "LAI", "VPD", "Tair")
cor_mat <- cor(dat[, vars_order], use = "complete.obs")
cor_df <- as.data.frame(as.table(cor_mat))
names(cor_df) <- c("row_var", "col_var", "r")  # as.table(): row first, column second
cor_df$row_id <- match(cor_df$row_var, vars_order)
cor_df$col_id <- match(cor_df$col_var, vars_order)

lower_df <- subset(cor_df, row_id >= col_id)   # lower triangle
lower_df$row_var <- factor(lower_df$row_var, levels = rev(vars_order))
lower_df$col_var <- factor(lower_df$col_var, levels = vars_order)

ggplot(lower_df, aes(x = col_var, y = row_var, fill = r))
```

For a lower-triangular display this puts the empty triangle in the upper-right; for upper-triangular use `row_id <= col_id` instead. Never swap `x = row_var` and `y = col_var`: that produces a mirror-image triangle even if `scale_y_discrete(limits = rev(vars_order))` is present.
Without anchoring, two readers of the same skill produce mirror-image figures of the same data.

For dual-state in-cell text colour (white over saturated cells, black over light), map a literal hex column with `scale_color_identity()` so ggplot does not try to legend-map it:

```r
geom_text(aes(label = sprintf("%.2f", r),
              colour = ifelse(abs(r) > 0.6, "white", "black")),
          family = "Arial", size = TXT_GG, show.legend = FALSE) +
  scale_color_identity()
```

### Time Or Ordered Sequences

Use lines and ribbons for trends, points/intervals for sparse repeated estimates, and consistent colors for repeated groups. Avoid smoothing if the statistical claim is about observed seasonality or discrete time steps.

### Multi-Panel Figures

All panels in a figure must share the same font, border, line weight, color semantics, and export DPI. Use common scales when panels are being compared; use free scales only when the caption or axis labels make that choice clear.

### Faceting

`facet_wrap` / `facet_grid` is the right tool when every panel encodes the *same* variables and only the data subset changes; reach for `patchwork` when panels show different geometries, axes, or legends.

- Default to `scales = "fixed"`. Switch to `"free_x"` / `"free_y"` only when an outlier subgroup forces it; never silently use `"free"` (it changes both axes and breaks visual comparison).
- Strip text inherits from `theme_qw_pub()` and is already Arial 8 pt — do not override.
- For ordered facets (year, treatment level), set the factor order before plotting; `facet_wrap(..., dir = "v")` does not sort.
- Many small facets: shrink internal margins via `theme(panel.spacing = unit(2, "mm"))` before reducing font.

### Large Data (n ≳ 10⁵)

Plain `geom_point()` saves every overdrawn point as a separate vector path; an SVG/PDF can balloon to hundreds of MB and crash Acrobat.

- Rasterise the heavy layer only: `ggrastr::rasterise(geom_point(...), dpi = 600)` keeps the rest of the figure as vector.
- For density of points, `geom_hex()` or `geom_bin2d()` reads better than overplotted points anyway.
- For random subsamples, fix the seed (`set.seed(...)` + `dplyr::slice_sample(n = ...)`) and report the subsample size in the caption.

## Statistical Annotation

Use annotations as evidence, not decoration.

```r
p_label <- function(p) {
  if (p < 0.001) "italic(p) < 0.001"
  else if (p < 0.01) "italic(p) < 0.01"
  else if (p < 0.05) "italic(p) < 0.05"
  else sprintf("italic(p) == %.3f", p)
}

r2_label <- function(r2) sprintf("italic(R)^2 == %.3f", r2)
```

Rules:

- Use `parse = TRUE` for `italic(p)`, `italic(R)^2`, and mathematical notation.
- Use `expression()` for subscripts, superscripts, and units.
- Put annotations in stable positions: top-right, bottom-right, above groups, or directly beside estimates. Prefer NPC coordinates over `Inf` + `hjust`/`vjust` magic numbers; `ggpp::geom_text_npc()` (or a small wrapper using `grid::unit(..., "npc")`) is more robust than `annotate("text", x = Inf, ...)`.
- **Always pass `size = TXT_GG`** to `geom_text` / `annotate("text")` — bare `size = 8` renders ≈ 22.6 pt.
- Do not overcrowd a panel with every available statistic. Show the statistic that supports the figure's purpose.
- Report sample size when the figure summarizes groups or site-level data.

Preferred form (NPC, no `Inf` magic):

```r
ann_df <- data.frame(
  x = 0.97, y = c(0.97, 0.91, 0.85),
  label = c(r2_label(r2_v), p_label(p_v), sprintf("italic(n) == %d", n_obs))
)

ggpp::geom_text_npc(
  data = ann_df,
  aes(npcx = x, npcy = y, label = label),
  inherit.aes = FALSE,                                  # ann_df has no group/colour columns
  parse = TRUE, hjust = 1, vjust = 1,
  family = "Arial", size = TXT_GG, colour = "black"
)
```

`inherit.aes = FALSE` is required when the parent ggplot has any grouping aes (`aes(colour = group)`, `aes(shape = group)`, `aes(linetype = group)`) and the annotation data lacks that column. Today `ggpp::geom_text_npc` tolerates missing inherited colour/fill, but discrete `shape`/`linetype` mappings (which the skill recommends elsewhere for B/W parity) error under ggplot2 ≥ 4.0.

Avoid `annotate("text", x = Inf, y = Inf, hjust = 1.1, vjust = 1.6)` — the magic `hjust/vjust` overshoots clip with small panels.

## Dimensions And Export

Always design for the final physical size. Do not tune a figure only in the RStudio viewer.

Common starting points:

| Use | Size |
|---|---|
| Small single panel | `70 x 75 mm` |
| Square comparison panel | `100 x 100 mm` or `10/2.54 x 10/2.54 in` |
| Wide group comparison | `200 x 80-100 mm` |
| Multi-panel figure | `20 x 13 cm` via `width = 20/2.54`, `height = 13/2.54` |
| Map | choose by extent, usually wide; keep `dpi = 600` for fine borders |

```r
out_dir <- "figures"            # define before any ggsave()
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

ggsave(
  file.path(out_dir, "figure.png"),
  plot   = p,
  width  = 70,
  height = 75,
  units  = "mm",
  dpi    = 600,
  bg     = "white",
  device = ragg::agg_png        # font-aware, see "Engine and Fonts"
)

if (requireNamespace("svglite", quietly = TRUE)) {
  ggsave(
    file.path(out_dir, "figure.svg"),
    plot   = p,
    width  = 70,
    height = 75,
    units  = "mm",
    bg     = "white",
    device = svglite::svglite   # font-aware vector, no XQuartz needed
  )
}
```

## Workflow For A New Figure

1. State the evidence type: distribution, association, model effect, ranking, composition, spatial, matrix, time, or multi-panel synthesis.
2. Pick geometry that matches that evidence type.
3. Decide the final physical layout, including panel arrangement, legend position, and relative panel sizes.
4. Apply `theme_qw_pub()` and the hard base rules.
5. Choose colors by semantic role and reuse the paper palette.
6. Add only the statistical annotations needed to support the claim.
7. Export at final physical size. If visual inspection is available, check text, labels, legends, and panel proportions before delivery; otherwise use conservative spacing and do not claim visual QA was performed.

## Common Mistakes

| Mistake | Correction |
|---|---|
| Writing method-specific recipes as universal rules | Use evidence type first, then choose geometry |
| Changing colors from figure to figure | Define a paper palette and reuse semantic colors |
| Using colorful axes, borders, or titles | Keep structure black/grey; reserve color for data |
| Hiding legends automatically | Hide only when direct labels or axes already explain color |
| Putting every legend outside the panel | Use unused in-panel whitespace when it does not cover evidence |
| Putting a colorbar inside a triangular matrix | Matrix colorbars default outside (`legend.position = "right"`) |
| Swapping x/y in a correlation matrix long table | Use `aes(x = col_var, y = row_var)`; for lower triangle filter `row_id >= col_id` and reverse only the y-axis levels |
| Distorting panels during patchwork assembly | Set `plot_layout(widths/heights)`; render `coord_fixed` panels separately |
| `coord_fixed` panel inside `(p1\|p2)/(p3\|p4)` shrinks unexpectedly | `plot_layout(widths = c(1,1))` does NOT equalize sizes — use `wrap_elements()` or pre-compute data aspect (see Recipe A/B in Layout And Legends) |
| Using default ggplot fonts | Force Arial 8 pt in theme and annotations; register with `systemfonts` |
| `geom_text(size = 8)` looks huge | Pass `size = TXT_GG` (= `8 / .pt`) — ggplot text size is in mm, not pt |
| `font family 'Arial' not found` warnings | Install `systemfonts` + `ragg`; export via `ragg::agg_png` / `cairo_pdf` |
| `legend.position = c(x,y)` warning | Use `"inside"` + `legend.position.inside = c(x,y)` |
| `geom_errorbarh()` deprecated | Use `geom_errorbar(orientation = "y")` |
| Boxplot/fitted lines look as thin as panel border | Data lines should be `LW * 1.7`–`LW * 2.0` so data > structure (lower factors sit below the perceptual threshold) |
| Drawing axis lines plus panel border | Blank `axis.line`; keep the four-sided border |
| Exporting by pixels or viewer size | Use `ggsave()` with physical units and DPI |
| `Inf` + `hjust = 1.1` annotations clip on small panels | Use NPC coordinates / `ggpp::geom_text_npc()` |
| Adding all possible statistics | Add only the evidence needed for the figure's claim |
