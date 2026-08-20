# Figure Patterns by Evidence Type

Read the section matching the scientific question. These are decision rules, not fixed templates. Code fragments assume the delivered script visibly defines `TEXT_GG`, `LINE_MM`, and `DATA_LINE_MM` as described in `style-and-export.md`.

## Contents

1. Distribution and group differences
2. Relationships and predictions
3. Model effects and rankings
4. Composition and proportions
5. Matrices
6. Time and ordered sequences
7. Facets and multi-panel figures
8. Large data
9. Statistical annotations

## 1. Distribution and Group Differences

- Show raw observations when feasible so spread, imbalance, and sample size remain visible.
- Use boxplots for robust quartile summaries, violins for distribution shape when sample size supports density estimation, and interval plots for estimated effects.
- Avoid bars of means when the raw distribution or uncertainty is the evidence.
- Distinguish biological/experimental replicates from repeated technical measurements. Do not display pseudoreplicates as independent `n`.
- State the center and interval (median/IQR, mean/SD, model estimate/95% CI, etc.).
- Use jitter/beeswarm widths that cannot move points into adjacent groups.

For pairwise brackets:

```r
ggsignif::geom_signif(
  comparisons = list(c("Control", "Treatment")),
  map_signif_level = TRUE,
  family = "Arial",
  textsize = TEXT_GG,
  size = LINE_MM,
  tip_length = 0.01
)
```

Do not add every possible comparison. Predeclare or justify the comparisons and correction method.

## 2. Relationships and Predictions

- Use scatter points for paired observations; use hex/bin/density for overplotting.
- Identify the fit (linear, GAM, mixed model, quantile, etc.) and interval meaning.
- Do not imply prediction by labeling a descriptive smoother as a predictive model.
- Add a 1:1 line only for observed-vs-predicted, method comparison, or another same-unit parity question.
- Preserve equal aspect when distance from a 1:1 line has geometric meaning.
- Inspect residuals separately; do not encode model adequacy only through a visually pleasing fit.
- For grouped trends, use color plus linetype/shape or direct labels.

Positive slopes often occupy every corner. First inspect whether a genuine interior gap remains; if so, place a compact legend there. Otherwise prefer direct line-end labels, a right-side guide, or no legend when labels already identify groups. Do not routinely put the legend above or below the panel.

## 3. Model Effects and Rankings

- Prefer estimates with intervals over bars of coefficients.
- Draw the null/reference line at 0, 1, or another scientifically defined value.
- Order terms by scientific structure or effect magnitude, and preserve a declared order across panels.
- Label transformed effect scales (odds ratio, standardized coefficient, percent change, log response ratio).
- Use horizontal intervals for long term labels:

```r
ggplot(coef_df, aes(estimate, term)) +
  geom_vline(xintercept = 0, colour = "grey40", linewidth = LINE_MM) +
  geom_errorbar(
    aes(xmin = lower, xmax = upper),
    orientation = "y",
    width = 0,
    linewidth = DATA_LINE_MM
  ) +
  geom_point(size = 1.8)
```

Use horizontal dot/bar/lollipop plots for rankings. Name the metric and do not imply causal importance from a descriptive ranking.

## 4. Composition and Proportions

- Use stacked bars/areas only when part-to-whole composition is the question.
- Keep category order and colors stable across groups and figures.
- Use a common 0–100% scale for proportion comparisons.
- Show absolute totals separately when identical proportions hide very different sample sizes.
- Avoid pie/donut charts for precise comparisons; reserve them for few categories and simple part-to-whole communication.

## 5. Matrices

Use heatmaps for correlations, distances, confusion matrices, and pairwise summaries. Choose sequential/diverging scales from the variable semantics, not from habit.

Anchor matrix row 1 at the top and column 1 at the left:

```r
vars_order <- c("GPP", "NEE", "LAI", "VPD", "Tair")
cor_mat <- cor(dat[, vars_order], use = "pairwise.complete.obs")
cor_df <- as.data.frame(as.table(cor_mat))
names(cor_df) <- c("row_var", "col_var", "value")
cor_df$row_id <- match(cor_df$row_var, vars_order)
cor_df$col_id <- match(cor_df$col_var, vars_order)

lower_df <- subset(cor_df, row_id >= col_id)
lower_df$row_var <- factor(lower_df$row_var, levels = rev(vars_order))
lower_df$col_var <- factor(lower_df$col_var, levels = vars_order)

ggplot(lower_df, aes(x = col_var, y = row_var, fill = value))
```

For an upper triangle use `row_id <= col_id`. Never swap `x = row_var` and `y = col_var`; that mirrors the matrix.

Set an explicit missing-value color. If pairwise-complete correlations use different `n`, provide the pairwise sample-size matrix or describe it. Put a colorbar outside the matrix by default.

Use readable in-cell text:

```r
geom_text(
  aes(label = sprintf("%.2f", value),
      colour = ifelse(abs(value) > 0.6, "white", "black")),
  family = "Arial", size = TEXT_GG, show.legend = FALSE
) +
scale_colour_identity()
```

## 6. Time and Ordered Sequences

- Preserve chronological/factor order explicitly.
- Leave gaps for missing observations; do not connect across them silently.
- State smoothing/window/bandwidth and edge handling.
- Use ribbons only when their uncertainty/variability meaning is named.
- Avoid spaghetti plots when group trajectories are unreadable; facet, summarize with disclosed intervals, or highlight declared focal units while keeping context.

## 7. Facets and Multi-Panel Figures

Use facets when panels share variables and geometry; use patchwork when panels have different geometries, axes, or roles.

- Default to fixed scales for comparison.
- Use `free_x` or `free_y` only for the necessary direction and disclose that cross-panel magnitude comparison is no longer direct.
- Set factor order before faceting.
- Wrap long strip labels with `label_wrap_gen()` before shrinking text.
- Collect axes/guides only when scales and meanings match.
- Keep panel tags, fonts, line hierarchy, and palette semantics consistent.
- Default multi-panel tags to lowercase `a`, `b`, `c`, ... with `plot_annotation(tag_levels = "a")`.
- For a rectangular grid, compose all panels in one flat `wrap_plots(..., ncol = ...)` call. Nested row-by-row patchworks can produce different panel-column edges.
- Apply one visible `theme(aspect.ratio = PANEL_ASPECT)` value to every ordinary panel whose black frame must have the same width and height.
- Verify the final panel viewport coordinates. Equal outer plot slots do not prove that the data rectangles align.
- Verify the rendered height/width and total panel-area share too. Equal rectangles can still be too small or too flat for the final figure.
- Prefer one shared figure caption or notes block outside the panel image over repeated prose captions beneath every subfigure. Do not remove required sample-size, uncertainty, transformation, missingness, or exclusion disclosures; relocate shared information instead.
- Preserve meaningful fixed aspect for maps and geometric comparisons; move conflicting fixed-aspect plots to a dedicated layout instead of stretching them into an equal-frame grid.
- Prefer compact legends inside verified panel whitespace. If a panel has no safe gap, use direct labels or a right/shared guide rather than sacrificing panel height to top/bottom legends.
- When several direct labels stack vertically (line ends, ranked callouts), derive their minimum gap from physical size — clearance factor × label height (mm) ÷ rendered panel height (mm) × axis span, plus a floor clamp that lifts the stack back inside the drawn range — so the same code stays readable at any panel height without per-layout tuning.
- For mixed map/statistics figures, choose side-by-side or stacked composition from the map's rendered aspect. Use fixed-aspect-aware `NA` layout units and verify the actual shared edges after export.

## 8. Large Data

Do not solve rendering performance by silently dropping observations.

- Rasterize only the heavy point layer with `ggrastr::rasterise(..., dpi = 600)`.
- Use `geom_hex()`, `geom_bin_2d()`, density, or aggregation when that representation answers the question; disclose bin size/bandwidth and aggregation rule.
- Simplify map geometry to the detail required at final physical size.
- Use alpha cautiously: it changes apparent density and can reproduce differently across devices.
- If a sampled preview is explicitly requested, fix the seed, label it as a sample, report sampled/total `n`, and never substitute it for final evidence.

## 9. Statistical Annotations

Treat annotations as evidence, not decoration.

- Format p values, R², and `n` visibly in the delivered script.
- Put test/model details, correction method, interval definition, and replication unit in the caption or figure note.
- Prefer NPC placement when the annotation belongs to panel space:

```r
p_label <- if (p_value < 0.001) {
  "italic(p) < 0.001"
} else {
  sprintf("italic(p) == %.3f", p_value)
}
r2_label <- sprintf("italic(R)^2 == %.3f", r2)

ann <- data.frame(
  x = 0.97,
  y = c(0.97, 0.91, 0.85),
  label = c(r2_label, p_label, sprintf("italic(n) == %d", n_obs))
)

ggpp::geom_text_npc(
  data = ann,
  aes(npcx = x, npcy = y, label = label),
  inherit.aes = FALSE,
  parse = TRUE,
  hjust = 1,
  vjust = 1,
  family = "Arial",
  size = TEXT_GG,
  colour = "black"
)
```

Prefer npc placement when the recipient can depend on `ggpp`; declare `ggpp` in the script's package check, because a self-contained deliverable may not add a hidden dependency. `annotate()` with `x = Inf`/`-Inf` plus tuned `hjust`/`vjust` stays acceptable and is what `scripts/five_panel_china.R` uses, but the corner offset is font- and size-dependent: verify at the final physical panel size that the label is neither clipped nor overlapping data, and re-verify after any change of panel dimensions.

With `parse = TRUE`, plotmath draws bare operators such as `==` and `<` from the Symbol font, so they silently leave the mandated family even when `family = "Arial"` is set. Keep the operator inside a quoted string, for example `italic(R)^2 * " = 0.49"`, and grep the exported SVG for `Symbol` to confirm.
