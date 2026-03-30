# Install packages if needed
if (!require("tidyverse")) install.packages("tidyverse")

library(tidyverse)

results_dir <- "~/slim_runs/results"

# -------------------------------
# Read SIGMA sweep folders
# -------------------------------
sigma_dirs <- list.dirs(results_dir, recursive = FALSE, full.names = TRUE) |>
  keep(~ grepl("/sigma_idx", .x))

sigma_data <- map_dfr(sigma_dirs, function(d) {
  folder <- basename(d)
  
  sigma_val <- sub(".*_val", "", folder)
  
  f <- file.path(d, "output.txt")
  if (!file.exists(f)) return(NULL)
  
  dat <- read_tsv(f, show_col_types = FALSE)
  
  dat |>
    mutate(
      sigma = as.numeric(sigma_val),
      run_id = folder
    )
})

# -------------------------------
# Keep last 100 generations
# -------------------------------
sigma_last100 <- sigma_data |>
  group_by(run_id) |>
  filter(gen > max(gen) - 100) |>
  ungroup()

# -------------------------------
# Compute mean + SD per run
# -------------------------------
summary_last100 <- sigma_last100 |>
  group_by(sigma, run_id) |>
  summarise(
    mean_p1 = mean(offspring_p1, na.rm = TRUE),
    sd_p1   = sd(offspring_p1, na.rm = TRUE),
    mean_p2 = mean(offspring_p2, na.rm = TRUE),
    sd_p2   = sd(offspring_p2, na.rm = TRUE),
    mean_p3 = mean(offspring_p3, na.rm = TRUE),
    sd_p3   = sd(offspring_p3, na.rm = TRUE),
    .groups = "drop"
  )

# -------------------------------
# Average across replicates
# -------------------------------
summary_across_runs <- summary_last100 |>
  group_by(sigma) |>
  summarise(
    mean_p1 = mean(mean_p1),
    sd_p1   = sd(mean_p1),
    mean_p2 = mean(mean_p2),
    sd_p2   = sd(mean_p2),
    mean_p3 = mean(mean_p3),
    sd_p3   = sd(mean_p3),
    .groups = "drop"
  )

# -------------------------------
# Long format
# -------------------------------
summary_long <- summary_across_runs |>
  pivot_longer(
    cols = -sigma,
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

# -------------------------------
# Plot
# -------------------------------
p_sigma <- ggplot(summary_long, aes(x = sigma, y = mean, color = population, fill = population)) +
  geom_ribbon(aes(ymin = mean - sd, ymax = mean + sd), alpha = 0.2, color = NA) +
  geom_line(linewidth = 1) +
  labs(
    title = "Population size vs assortative mating (sigma)",
    x = "Sigma (assortative mating strength)",
    y = "Mean population (last 100 generations)"
  ) +
  theme_bw()

print(p_sigma)

ggsave(
  "~/slim_runs/results/sigma_last100_mean_sd.png",
  p_sigma,
  width = 10,
  height = 6,
  dpi = 300
)
