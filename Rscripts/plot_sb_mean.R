library(tidyverse)

results_dir <- "~/slim_runs/results"

sb_dirs <- list.dirs(results_dir, recursive = FALSE, full.names = TRUE) |>
  keep(~ grepl("/sb_idx", .x))

sb_data <- map_dfr(sb_dirs, function(d) {
  folder <- basename(d)
  sb_val <- sub(".*_val", "", folder)

  f <- file.path(d, "output.txt")
  if (!file.exists(f)) return(NULL)

  dat <- read_tsv(f, show_col_types = FALSE)

  dat |>
    mutate(
      sb = as.numeric(sb_val),
      run_id = folder
    )
})

sb_summary <- sb_data |>
  group_by(sb, run_id) |>
  summarise(
    mean_p1 = mean(offspring_p1, na.rm = TRUE),
    sd_p1   = sd(offspring_p1, na.rm = TRUE),
    mean_p2 = mean(offspring_p2, na.rm = TRUE),
    sd_p2   = sd(offspring_p2, na.rm = TRUE),
    mean_p3 = mean(offspring_p3, na.rm = TRUE),
    sd_p3   = sd(offspring_p3, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(sb)

sb_long <- sb_summary |>
  pivot_longer(
    cols = -c(sb, run_id),
    names_to = "metric",
    values_to = "value"
  ) |>
  separate(metric, into = c("stat", "population"), sep = "_") |>
  pivot_wider(names_from = stat, values_from = value) |>
  mutate(
    population = recode(
      population,
      "p1" = "Parent 1",
      "p2" = "Parent 2",
      "p3" = "Hybrid"
    )
  )

p_sb <- ggplot(sb_long, aes(x = sb, y = mean)) +
  geom_ribbon(aes(ymin = mean - sd, ymax = mean + sd, fill = population), alpha = 0.25) +
  geom_line(aes(color = population), linewidth = 1) +
  facet_wrap(~ population, scales = "free_y", ncol = 1) +
  labs(
    title = "Mean ± SD across all generations",
    subtitle = "Across BDMI strength (sb)",
    x = "BDMI strength (sb)",
    y = "Mean offspring count"
  ) +
  theme_bw()

print(p_sb)

ggsave(
  "~/slim_runs/results/sb_mean_allgens.png",
  p_sb,
  width = 10,
  height = 10,
  dpi = 300
)
