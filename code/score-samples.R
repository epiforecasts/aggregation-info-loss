library(here)
library(dplyr)
library(tidyr)
library(purrr)
library(cNORM)
library(lubridate)

# ----- Score samples by MAE
score_samples <- function(results,
                          truncate_weeks = 0) {

  # Handle data truncation - remove n last data points
  if (truncate_weeks == 0) {
    truncate_weeks <- length(unique(results$target_end_date))
    last_data_point <- max(results$target_end_date)
  } else {
    last_data_point <- max(results$target_end_date) - (7 * truncate_weeks)
  }

  # ----- Score each sample
  mae <- results |>
    filter(
      # score against observations
      !is.na(obs_100k) &
        # score against sub-set of data
        target_end_date <= last_data_point) |>
    # absolute error
    mutate(ae = abs(value_100k - obs_100k)) |>
    # mean absolute error
    group_by(location, target_variable,
             model, sample, scenario_id) |>
    summarise(mae = mean(ae),
              inv_mae = 1/mae,
              n_weeks_scored = n(),
              .groups = "drop")

  # ----- Create MAE weights for each value
  # join MAE to results
  results <- left_join(results, mae,
                       by = c("location", "target_variable", "scenario_id",
                              "model", "sample")) |>
    # for each target, each sample's weight is a % relative to all models'
    group_by(target_end_date, location, target_variable) |>
    # create weights
    mutate(sum_inv_mae = sum(inv_mae, na.rm = TRUE),
           weight = inv_mae / sum_inv_mae) |>
    ungroup()

  return(results)

}
