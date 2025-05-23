################################################################################
#                       Survival IntegratedHessian
################################################################################

surv_inthess<- function(exp, target = "survival", instance = 1,
                        times_input = TRUE, batch_size = 50,
                        n = 10, x_ref = NULL, dtype = "float", include_time = FALSE) {
  UseMethod("surv_inthess")
}

# DeepSurv ----------------------------------------------------------------------
surv_inthess.explainer_deepsurv <- function(exp, target = "survival", instance = 1,
                                            times_input = TRUE, batch_size = 50,
                                            n = 10, x_ref = NULL,
                                            dtype = "float", ...) {

  # Check arguments
  assertClass(exp, "explainer_deepsurv")
  assertChoice(target, c("survival", "cum_hazard", "hazard"))
  assertIntegerish(instance, lower = 1, upper = dim(exp$input_data[[1]])[1])
  assertIntegerish(n, lower = 1)
  assertIntegerish(batch_size, lower = 1)
  assertArgData(x_ref, null.ok = TRUE)
  assertChoice(dtype, c("float", "double"))

  # Set dtype of all tensors
  dtype_name <- dtype
  dtype <- switch(dtype_name,
                  "float" = torch::torch_float(),
                  "double" = torch::torch_double())

  # Set reference value
  if (is.null(x_ref)) {
    x_ref <- lapply(exp$input_data,
                    function(x) {
                      res <- apply(x, seq_along(dim(x))[-1], mean, simplify = TRUE)
                      if (is.null(dim(res))) dim(res) <- c(1, length(res))
                      res
                    })
  }

  # Repeat reference value
  if (!is.list(x_ref)) x_ref <- list(x_ref)
  x_ref <- lapply(x_ref, function(x) {
    x[rep(seq_len(dim(x)[1]), each = n * n * length(instance)), , drop = FALSE]
  })

  # Get scale tensor
  scale_fun <- function(n, ...) {
    scale_n <- as.integer(sqrt(n))
    torch::torch_tensor((rep(seq(1/scale_n, 1, length.out = scale_n), each = scale_n) *
                           rep(seq(1/scale_n, 1, length.out = scale_n), times = scale_n)),
                        dtype = dtype)
  }

  result <- base_method(exp = exp,
                        instance = instance,
                        n = n * n,
                        model_class = "DeepSurv",
                        inputs_ref = x_ref,
                        method_pre_fun = NULL,
                        scale_fun = scale_fun,
                        n_timepoints = 1,
                        return_out = TRUE,
                        remove_time = FALSE,
                        batch_size = batch_size,
                        times_input = times_input,
                        target = target,
                        dtype = dtype,
                        second_order = TRUE)

  result <- append(result, list(
    model_class = "DeepSurv",
    method = "Surv_IntHessian",
    method_args = list(
      target = target, instance = instance, times_input = times_input,
      n = n, dtype = dtype_name
    )
  ))
  class(result) <- c("surv_result", class(result))

  result
}


# CoxTime ----------------------------------------------------------------------
surv_inthess.explainer_coxtime <- function(exp, target = "survival", instance = 1,
                                           times_input = TRUE, batch_size = 50,
                                           n = 10, x_ref = NULL,
                                           dtype = "float", include_time = FALSE) {

  # Check arguments
  assertClass(exp, "explainer_coxtime")
  assertChoice(target, c("survival", "cum_hazard", "hazard"))
  assertIntegerish(instance, lower = 1, upper = dim(exp$input_data[[1]])[1])
  assertIntegerish(n, lower = 1)
  assertLogical(include_time)
  assertIntegerish(batch_size, lower = 1)
  assertArgData(x_ref, null.ok = TRUE)
  assertChoice(dtype, c("float", "double"))

  # Set dtype of all tensors
  dtype_name <- dtype
  dtype <- switch(dtype_name,
                  "float" = torch::torch_float(),
                  "double" = torch::torch_double())


  # Set reference value
  if (is.null(x_ref)) {
    x_ref <- lapply(exp$input_data,
                    function(x) {
                      res <- apply(x, seq_along(dim(x))[-1], mean, simplify = TRUE)
                      if (is.null(dim(res))) dim(res) <- c(1, length(res))
                      res
                    })
  }

  # Repeat reference value
  if (!is.list(x_ref)) x_ref <- list(x_ref)
  x_ref <- lapply(x_ref, function(x) {
    x[rep(seq_len(dim(x)[1]), each = n*n * length(instance)), , drop = FALSE]
  })

  # Get scale tensor
  scale_fun <- function(n, ...) {
    scale_n <- as.integer(sqrt(n))
    torch::torch_tensor((rep(seq(1/scale_n, 1, length.out = scale_n), each = scale_n) *
                           rep(seq(1/scale_n, 1, length.out = scale_n), times = scale_n)),
                        dtype = dtype)
  }

  result <- base_method(exp = exp,
                        instance = instance,
                        n = n * n,
                        model_class = "CoxTime",
                        inputs_ref = x_ref,
                        method_pre_fun = NULL,
                        scale_fun = scale_fun,
                        n_timepoints = length(exp$model$t_orig),
                        return_out = TRUE,
                        remove_time = !include_time,
                        batch_size = batch_size,
                        times_input = times_input,
                        target = target,
                        dtype = dtype,
                        second_order = TRUE)


  result <- append(result, list(
    model_class = "CoxTime",
    method = "Surv_IntHessian",
    method_args = list(
      target = target, instance = instance, times_input = times_input,
      n = n, include_time = include_time, dtype = dtype_name
    )
  ))
  class(result) <- c("surv_result", class(result))

  result
}

# DeepHit ----------------------------------------------------------------------
surv_inthess.explainer_deephit <- function(exp, target = "survival", instance = 1,
                                           times_input = TRUE, batch_size = 50,
                                           n = 10, x_ref = NULL,
                                           dtype = "float", ...) {

  # Check arguments
  assertClass(exp, "explainer_deephit")
  assertChoice(target, c("survival", "cif", "pmf"))
  assertIntegerish(instance, lower = 1, upper = dim(exp$input_data[[1]])[1])
  assertIntegerish(n, lower = 1)
  assertIntegerish(batch_size, lower = 1)
  assertArgData(x_ref, null.ok = TRUE)
  assertChoice(dtype, c("float", "double"))

  # Set dtype of all tensors
  dtype_name <- dtype
  dtype <- switch(dtype_name,
                  "float" = torch::torch_float(),
                  "double" = torch::torch_double())

  # Set reference value
  if (is.null(x_ref)) {
    x_ref <- lapply(exp$input_data,
                    function(x) {
                      res <- apply(x, seq_along(dim(x))[-1], mean, simplify = TRUE)
                      if (is.null(dim(res))) dim(res) <- c(1, length(res))
                      res
                    })
  }
  # Repeat reference value
  if (!is.list(x_ref)) x_ref <- list(x_ref)
  x_ref <- lapply(x_ref, function(x) {
    x[rep(seq_len(dim(x)[1]), each = n * n * length(instance)), , drop = FALSE]
  })

  # Get scale tensor
  scale_fun <- function(n, ...) {
    scale_n <- as.integer(sqrt(n))
    torch::torch_tensor((rep(seq(1/scale_n, 1, length.out = scale_n), each = scale_n) *
                           rep(seq(1/scale_n, 1, length.out = scale_n), times = scale_n)),
                        dtype = dtype)
  }

  result <- base_method(exp = exp,
                        instance = instance,
                        n = n * n,
                        model_class = "DeepHit",
                        inputs_ref = x_ref,
                        method_pre_fun = NULL,
                        scale_fun = scale_fun,
                        n_timepoints = 1,
                        return_out = TRUE,
                        remove_time = FALSE,
                        batch_size = batch_size,
                        times_input = times_input,
                        target = target,
                        dtype = dtype,
                        second_order = TRUE)

  result <- append(result, list(
    model_class = "DeepHit",
    method = "Surv_IntHessian",
    method_args = list(
      target = target, instance = instance, times_input = times_input,
      n = n, dtype = dtype_name
    )
  ))
  class(result) <- c("surv_result", class(result))

  result
}

