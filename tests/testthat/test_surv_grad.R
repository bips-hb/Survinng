
################################################################################
#                             surv_grad: CoxTime                               #
################################################################################

test_that("Method 'surv_grad' with CoxTime (1D model)", {

  # Preparation ----------------------------------------------------------------
  model_1d <- seq_model_1D(6)
  data <- torch_randn(10, 5)
  base_hazard <- get_base_hazard(20)
  exp_1d <- explain(model_1d, data = data, model_type = "coxtime",
                    baseline_hazard = base_hazard)

  # Test arguments -------------------------------------------------------------
  expect_error(surv_grad("no explainer"))
  res <- surv_grad(exp_1d)
  expect_error(surv_grad(exp_1d, target = "wrong target"))
  expect_error(surv_grad(exp_1d, instance = "wrong instance"))
  expect_error(surv_grad(exp_1d, times_input = list("not boolean")))
  expect_error(surv_grad(exp_1d, use_base_hazard = list("not boolean")))
  expect_error(surv_grad(exp_1d, batch_size = "not integer"))
  expect_error(surv_grad(exp_1d, include_time = "not boolean"))
  expect_error(surv_grad(exp_1d, dtype = "wrong dtype"))

  # Test sequential 1D model ---------------------------------------------------
  res <- surv_grad(exp_1d, instance = c(1, 3, 4))
  expect_s3_class(res, "surv_result")
  checkmate::expect_names(names(res), subset.of = c("res", "pred", "time", "method", "method_args", "competing_risks", "model_class"))
  expect_equal(res$method, "Surv_Gradient")
  expect_equal(res$model_class, "CoxTime")
  expect_equal(res$competing_risks, FALSE)
  expect_equal(res$method_args$target, "survival")
  expect_equal(res$method_args$dtype, "float")
  expect_equal(res$method_args$times_input, FALSE)
  expect_equal(dim(res$res[[1]]), c(3, 5, 20))
  expect_equal(dim(res$pred), c(3, 20))
  expect_equal(length(res$time), 20)
  checkmate::expect_array(res$res[[1]])
  checkmate::expect_array(res$pred)
  expect_vector(res$time)

  # Test sequential 1D model with times_input = TRUE ---------------------------
  res <- surv_grad(exp_1d, instance = c(1, 3, 4), times_input = TRUE)
  expect_equal(res$method_args$times_input, TRUE)
  expect_equal(res$competing_risks, FALSE)
  expect_equal(res$method_args$target, "survival")
  expect_equal(res$method_args$dtype, "float")
  expect_equal(dim(res$res[[1]]), c(3, 5, 20))
  expect_equal(dim(res$pred), c(3, 20))
  expect_equal(length(res$time), 20)
  checkmate::expect_array(res$res[[1]])
  checkmate::expect_array(res$pred)
  expect_vector(res$time)

  # Test sequential 1D model with other targets --------------------------------
  res <- surv_grad(exp_1d, instance = c(1, 3), target = "hazard")
  expect_equal(res$method_args$target, "hazard")
  expect_equal(res$method_args$dtype, "float")
  expect_equal(dim(res$res[[1]]), c(2, 5, 20))
  expect_equal(dim(res$pred), c(2, 20))
  expect_equal(length(res$time), 20)
  res <- surv_grad(exp_1d, instance = c(1, 3), target = "cum_hazard")
  expect_equal(res$method_args$target, "cum_hazard")
  expect_equal(res$method_args$dtype, "float")
  expect_equal(dim(res$res[[1]]), c(2, 5, 20))
  expect_equal(dim(res$pred), c(2, 20))
  expect_equal(length(res$time), 20)
  res <- surv_grad(exp_1d, instance = c(1, 3), target = "survival")
  expect_equal(res$method_args$target, "survival")
  expect_equal(res$method_args$dtype, "float")
  expect_equal(dim(res$res[[1]]), c(2, 5, 20))
  expect_equal(dim(res$pred), c(2, 20))
  expect_equal(length(res$time), 20)

  # Test sequential 1D model with other dtype ----------------------------------
  res <- surv_grad(exp_1d, instance = c(1, 3), dtype = "double")
  expect_equal(res$method_args$dtype, "double")
  expect_equal(dim(res$res[[1]]), c(2, 5, 20))
  expect_equal(dim(res$pred), c(2, 20))
  expect_equal(length(res$time), 20)
  res <- surv_grad(exp_1d, instance = c(1, 3), times_input = TRUE, dtype = "double")
  expect_equal(res$method_args$dtype, "double")
  expect_equal(dim(res$res[[1]]), c(2, 5, 20))
  expect_equal(dim(res$pred), c(2, 20))
  expect_equal(length(res$time), 20)


  # Other Checks ---------------------------------------------------------------
  # Test array as 'data' argument
  exp_1d <- explain(model_1d, data = as.array(data), model_type = "coxtime",
                    baseline_hazard = base_hazard)
  res <- surv_grad(exp_1d, instance = c(1, 3, 4))

  # Test as.data.frame and as.data.table
  df_res <- as.data.frame(res)
  dt_res <- data.table::as.data.table(res)

  # Test data.frame as 'data' argument
  exp_1d <- explain(model_1d, data = as.data.frame(as.array(data)), model_type = "coxtime",
                    baseline_hazard = base_hazard)
  res <- surv_grad(exp_1d, instance = c(1, 3, 4))

  # Test as.data.frame and as.data.table
  df_res <- as.data.frame(res)
  dt_res <- data.table::as.data.table(res)


})


test_that("Method 'surv_grad' with CoxTime (Multi-modal model)", {
  # Preparation ----------------------------------------------------------------
  model_mm <- multi_modal_model(num_tabular_inputs = 4, num_outputs = 1, add_time = TRUE)
  data <- list(torch_randn(4, 3, 10, 10), torch_randn(4, 4))
  base_hazard <- get_base_hazard(12)

  # Define preprocess function to handle the time axis
  preprocess_fun <- function(x) {
    # x is a list with two tensors: image data and tabular data
    batch_size <- x[[1]]$size(1)

    # Input (batch_size, in_features) -> (batch_size * t, in_features) (replicate each row t times)
    res <- lapply(x, function(a) a$repeat_interleave(12L, dim = 1))

    # Add time to tabular input
    time <- torch::torch_vstack(replicate(batch_size, torch_tensor(base_hazard$time)$unsqueeze(-1)))
    list(res[[1]], torch::torch_cat(list(res[[2]], time), dim = -1))
  }

  exp_mm <- explain(model_mm, data = data, model_type = "coxtime",
                    baseline_hazard = base_hazard, preprocess_fun = preprocess_fun)

  # Check ----------------------------------------------------------------------
  expect_warning(expect_warning(expect_warning(res <- surv_grad(exp_mm))))
  expect_warning(expect_warning(expect_warning(
    res <- surv_grad(exp_mm, instance = c(1, 3))
  )))
  expect_s3_class(res, "surv_result")

  # Test multi-modal model with times_input = TRUE ------------------------------
  expect_warning(expect_warning(expect_warning(
    res <- surv_grad(exp_mm, instance = c(1, 3), times_input = TRUE)
  )))
  expect_s3_class(res, "surv_result")

  # Other Checks ---------------------------------------------------------------
  # Test array as 'data' argument
  exp_mm <- explain(model_mm, data = lapply(data, as.array), model_type = "coxtime",
                    baseline_hazard = base_hazard, preprocess_fun = preprocess_fun)
  expect_warning(expect_warning(expect_warning(
    res <- surv_grad(exp_mm, instance = c(1, 3, 4))
  )))

  # Test as.data.frame and as.data.table
  df_res <- as.data.frame(res)
  dt_res <- data.table::as.data.table(res)

  # Test data.frame as 'data' argument
  # Test array as 'data' argument
  exp_mm <- explain(model_mm, data = list(data[[1]], as.data.frame(as.matrix(data[[2]]))),
                    model_type = "coxtime",
                    baseline_hazard = base_hazard, preprocess_fun = preprocess_fun)
  expect_warning(expect_warning(expect_warning(
    res <- surv_grad(exp_mm, instance = c(1, 3, 4))
  )))

  # Test as.data.frame and as.data.table
  df_res <- as.data.frame(res)
  dt_res <- data.table::as.data.table(res)
})



################################################################################
#                             surv_grad: DeepSurv                              #
################################################################################

test_that("Method 'surv_grad' with DeepSurv (1D model)", {

  # Preparation ----------------------------------------------------------------
  model_1d <- seq_model_1D(5)
  data <- torch_randn(10, 5)
  base_hazard <- get_base_hazard(20)
  exp_1d <- explain(model_1d, data = data, baseline_hazard = base_hazard,
                    model_type = "deepsurv")

  # Test arguments -------------------------------------------------------------
  expect_error(surv_grad("no explainer"))
  res <- surv_grad(exp_1d)
  expect_error(surv_grad(exp_1d, target = "wrong target"))
  expect_error(surv_grad(exp_1d, instance = "wrong instance"))
  expect_error(surv_grad(exp_1d, times_input = list("not boolean")))
  expect_error(surv_grad(exp_1d, use_base_hazard = list("not boolean")))
  expect_error(surv_grad(exp_1d, batch_size = "not integer"))
  expect_error(surv_grad(exp_1d, dtype = "wrong dtype"))

  # Test sequential 1D model ---------------------------------------------------
  res <- surv_grad(exp_1d, instance = c(1, 3, 4))
  expect_s3_class(res, "surv_result")
  checkmate::expect_names(names(res), subset.of = c("res", "pred", "time", "method", "method_args", "competing_risks", "model_class"))
  expect_equal(res$method, "Surv_Gradient")
  expect_equal(res$model_class, "DeepSurv")
  expect_equal(res$competing_risks, FALSE)
  expect_equal(res$method_args$target, "survival")
  expect_equal(res$method_args$dtype, "float")
  expect_equal(res$method_args$times_input, FALSE)
  expect_equal(dim(res$res[[1]]), c(3, 5, 20))
  expect_equal(dim(res$pred), c(3, 20))
  expect_equal(length(res$time), 20)
  checkmate::expect_array(res$res[[1]])
  checkmate::expect_array(res$pred)
  expect_vector(res$time)

  # Test sequential 1D model with times_input = TRUE ---------------------------
  res <- surv_grad(exp_1d, instance = c(1, 3), times_input = TRUE)
  expect_equal(res$method_args$times_input, TRUE)
  expect_equal(res$competing_risks, FALSE)
  expect_equal(res$method_args$target, "survival")
  expect_equal(res$method_args$dtype, "float")
  expect_equal(dim(res$res[[1]]), c(2, 5, 20))
  expect_equal(dim(res$pred), c(2, 20))
  expect_equal(length(res$time), 20)
  checkmate::expect_array(res$res[[1]])
  checkmate::expect_array(res$pred)
  expect_vector(res$time)

  # Test sequential 1D model with other targets --------------------------------
  res <- surv_grad(exp_1d, instance = c(1, 3), target = "hazard")
  expect_equal(res$method_args$target, "hazard")
  expect_equal(res$method_args$dtype, "float")
  expect_equal(dim(res$res[[1]]), c(2, 5, 20))
  expect_equal(dim(res$pred), c(2, 20))
  expect_equal(length(res$time), 20)
  res <- surv_grad(exp_1d, instance = c(1, 3), target = "cum_hazard")
  expect_equal(res$method_args$target, "cum_hazard")
  expect_equal(res$method_args$dtype, "float")
  expect_equal(dim(res$res[[1]]), c(2, 5, 20))
  expect_equal(dim(res$pred), c(2, 20))
  expect_equal(length(res$time), 20)
  res <- surv_grad(exp_1d, instance = c(1, 3), target = "survival")
  expect_equal(res$method_args$target, "survival")
  expect_equal(res$method_args$dtype, "float")
  expect_equal(dim(res$res[[1]]), c(2, 5, 20))
  expect_equal(dim(res$pred), c(2, 20))
  expect_equal(length(res$time), 20)

  # Test sequential 1D model with other dtype ----------------------------------
  res <- surv_grad(exp_1d, instance = c(1, 3), dtype = "double")
  expect_equal(res$method_args$dtype, "double")
  expect_equal(dim(res$res[[1]]), c(2, 5, 20))
  expect_equal(dim(res$pred), c(2, 20))
  expect_equal(length(res$time), 20)
  res <- surv_grad(exp_1d, instance = c(1, 3), times_input = TRUE, dtype = "double")
  expect_equal(res$method_args$dtype, "double")
  expect_equal(dim(res$res[[1]]), c(2, 5, 20))
  expect_equal(dim(res$pred), c(2, 20))
  expect_equal(length(res$time), 20)
})



test_that("Method 'surv_grad' with DeepSurv (Multi-modal model)", {
  # Preparation ----------------------------------------------------------------
  model_mm <- multi_modal_model(num_tabular_inputs = 5, num_outputs = 1)
  data <- list(torch_randn(4, 3, 10, 10), torch_randn(4, 5))
  base_hazard <- get_base_hazard(12)
  exp_mm <- explain(model_mm, data = data, model_type = "deepsurv",
                    baseline_hazard = base_hazard)

  # Check ----------------------------------------------------------------------
  res <- surv_grad(exp_mm)
  res <- surv_grad(exp_mm, instance = c(1, 3))
  expect_s3_class(res, "surv_result")

  # Test multi-modal model with times_input = TRUE ------------------------------
  res <- surv_grad(exp_mm, instance = c(1, 3), times_input = TRUE)
  expect_s3_class(res, "surv_result")
})


################################################################################
#                             surv_grad: DeepHit                               #
################################################################################

test_that("Method 'surv_grad' with DeepHit (1D model)", {

  # Preparation ----------------------------------------------------------------
  time_bins <- seq(0, 10, length.out = 20)
  model_1d <- seq_model_1D(5, num_outputs = length(time_bins))
  data <- torch_randn(10, 5)
  exp_1d <- explain(model_1d, data = data, model_type = "deephit",
                    time_bins = time_bins)

  # Test arguments -------------------------------------------------------------
  expect_error(surv_grad("no explainer"))
  res <- surv_grad(exp_1d)
  expect_error(surv_grad(exp_1d, target = "wrong target"))
  expect_error(surv_grad(exp_1d, instance = "wrong instance"))
  expect_error(surv_grad(exp_1d, times_input = list("not boolean")))
  expect_error(surv_grad(exp_1d, batch_size = "not integer"))
  expect_error(surv_grad(exp_1d, dtype = "wrong dtype"))

  # Test sequential 1D model ---------------------------------------------------
  res <- surv_grad(exp_1d, instance = c(1, 3))
  expect_s3_class(res, "surv_result")
  checkmate::expect_names(names(res), subset.of = c("res", "pred", "time", "method", "method_args", "competing_risks", "model_class"))
  expect_equal(res$method, "Surv_Gradient")
  expect_equal(res$model_class, "DeepHit")
  expect_equal(res$competing_risks, FALSE)
  expect_equal(res$method_args$target, "survival")
  expect_equal(res$method_args$dtype, "float")
  expect_equal(res$method_args$times_input, FALSE)
  expect_equal(dim(res$res[[1]]), c(2, 5, 20))
  expect_equal(dim(res$pred), c(2, 20))
  expect_equal(length(res$time), 20)
  checkmate::expect_array(res$res[[1]])
  checkmate::expect_array(res$pred)
  expect_vector(res$time)

  # Test sequential 1D model with times_input = TRUE ---------------------------
  res <- surv_grad(exp_1d, instance = c(1, 3), times_input = TRUE)
  expect_equal(res$method_args$times_input, TRUE)
  expect_equal(res$competing_risks, FALSE)
  expect_equal(res$method_args$target, "survival")
  expect_equal(res$method_args$dtype, "float")
  expect_equal(dim(res$res[[1]]), c(2, 5, 20))
  expect_equal(dim(res$pred), c(2, 20))
  expect_equal(length(res$time), 20)
  checkmate::expect_array(res$res[[1]])
  checkmate::expect_array(res$pred)
  expect_vector(res$time)

  # Test sequential 1D model with other targets --------------------------------
  res <- surv_grad(exp_1d, instance = c(1, 3), target = "pmf")
  expect_equal(res$method_args$target, "pmf")
  expect_equal(res$method_args$dtype, "float")
  expect_equal(dim(res$res[[1]]), c(2, 5, 20))
  expect_equal(dim(res$pred), c(2, 20))
  expect_equal(length(res$time), 20)
  res <- surv_grad(exp_1d, instance = c(1, 3), target = "cif")
  expect_equal(res$method_args$target, "cif")
  expect_equal(res$method_args$dtype, "float")
  expect_equal(dim(res$res[[1]]), c(2, 5, 20))
  expect_equal(dim(res$pred), c(2, 20))
  expect_equal(length(res$time), 20)
  res <- surv_grad(exp_1d, instance = c(1, 3), target = "survival")
  expect_equal(res$method_args$target, "survival")
  expect_equal(res$method_args$dtype, "float")
  expect_equal(dim(res$res[[1]]), c(2, 5, 20))
  expect_equal(dim(res$pred), c(2, 20))
  expect_equal(length(res$time), 20)

  # Test sequential 1D model with other dtype ----------------------------------
  res <- surv_grad(exp_1d, instance = c(1, 3), dtype = "double")
  expect_equal(res$method_args$dtype, "double")
  expect_equal(dim(res$res[[1]]), c(2, 5, 20))
  expect_equal(dim(res$pred), c(2, 20))
  expect_equal(length(res$time), 20)
  res <- surv_grad(exp_1d, instance = c(1, 3), times_input = TRUE, dtype = "double")
  expect_equal(res$method_args$dtype, "double")
  expect_equal(dim(res$res[[1]]), c(2, 5, 20))
  expect_equal(dim(res$pred), c(2, 20))
  expect_equal(length(res$time), 20)
})



test_that("Method 'surv_grad' with DeepHit (Multi-modal model)", {
  # Preparation ----------------------------------------------------------------
  model_mm <- multi_modal_model(num_tabular_inputs = 5, num_outputs = 10)
  data <- list(torch_randn(4, 3, 10, 10), torch_randn(4, 5))
  exp_mm <- explain(model_mm, data = data, model_type = "deephit",
                    time_bins = seq(0, 15, length.out = 10))

  # Check ----------------------------------------------------------------------
  res <- surv_grad(exp_mm)
  res <- surv_grad(exp_mm, instance = c(1, 3))
  expect_s3_class(res, "surv_result")

  # Test multi-modal model with times_input = TRUE ------------------------------
  res <- surv_grad(exp_mm, instance = c(1, 3), times_input = TRUE)
  expect_s3_class(res, "surv_result")
})

