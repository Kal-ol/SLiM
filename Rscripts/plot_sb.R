library(tidyverse)

results_dir <- "~/slim_runs/results"

# Read sb sweep folders
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

# Keep only the last 100 generations within each run
sb_last100 <- sb_data |>
  group_by(run_id) |>
  filter(gen > max(gen) - 100) |>
  ungroup()

# Summarize mean and SD for each parameter value
summary_last100 <- sb_last100 |>
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

# Long format for plotting
summary_long <- summary_last100 |>
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

# Faceted plot
p_mean_sd <- ggplot(summary_long, aes(x = sb, y = mean)) +
  geom_ribbon(aes(ymin = mean - sd, ymax = mean + sd, fill = population), alpha = 0.25) +
  geom_line(aes(color = population), linewidth = 1) +
  facet_wrap(~ population, scales = "free_y", ncol = 1) +
  labs(
    title = "Mean ± SD of offspring over the last 100 generations",
    subtitle = "Across BDMI strength (sb)",
    x = "BDMI strength (sb)",
    y = "Mean offspring count"
  ) +
  theme_bw()

print(p_mean_sd)

ggsave(
  "~/slim_runs/results/sb_last100_mean_sd.png",
  p_mean_sd,
  width = 10,
  height = 10,
  dpi = 300
)

# Combined plot
p_combined <- ggplot(summary_long, aes(x = sb, y = mean, color = population, fill = population)) +
  geom_ribbon(aes(ymin = mean - sd, ymax = mean + sd), alpha = 0.15, color = NA) +
  geom_line(linewidth = 1) +
  labs(
    title = "Mean ± SD over the last 100 generations",
    subtitle = "Across BDMI strength (sb)",
    x = "BDMI strength (sb)",
    y = "Mean offspring count",
    color = "Population",
    fill = "Population"
  ) +
  theme_bw()

print(p_combined)

ggsave(
  "~/slim_runs/results/sb_last100_mean_sd_combined.png",
  p_combined,
  width = 10,
  height = 6,
  dpi = 300
)
