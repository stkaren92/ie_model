# Predicts ecological integrity based on input data and trained Bayesian network

library('gRain')

#' Function to predict ecological integrity
#' @param prior RData trained Bayesian network
#' @param input_csv Path to cases csv file to be evaluated
#' @param total_rows Number of total cases
#' @param no_of_partitions Number of partitions to split cases
#' @param i_cluster i-th partition of the dataframe
#' @param out_path Output folder path
predict_ie_bn <- function(
    prior,
    input_csv, 
    total_rows, 
    no_of_partitions=200, 
    i_cluster, 
    out_path
) {
  if (i_cluster <= 0 || i_cluster > no_of_partitions) {
    stop("Cluster number out of range")
  }
  col_names <- colnames(read.csv(input_csv, nrows = 1))
  # split data
  size <- trunc(total_rows/no_of_partitions)
  n_ini <- (i_cluster-1)*size + 1
  cat(format(Sys.time(), "%Y/%m/%e %H:%M:%S")," - Leyendo datos del cluster ", i_cluster, "\n")
  if ( i_cluster == no_of_partitions ) {
    df <- read.csv(input_csv,
                   skip = n_ini,
                   header = FALSE,
                   col.names = col_names)
  } else {
    df <- read.csv(input_csv,
                   skip = n_ini,
                   nrows = size,
                   header = FALSE,
                   col.names = col_names)
  }
  
  gc(reset = TRUE)
  
  # Prediction
  cat(format(Sys.time(), "%Y/%m/%e %H:%M:%S")," - Empieza prediccion del cluster ", i_cluster, "\n")
  prediction <- predict(prior,
                        response="hemerobia",
                        newdata=df,
                        type="distribution")
  
  probabilities <- prediction$pred$hemerobia
  
  # Raster with standardized expectancy
  expectancy <- probabilities %*%  as.numeric(colnames(probabilities))
  expectancy <- (18-expectancy)/(18)
  df_exp <- data.frame(x=df$x,y=df$y,ie=expectancy)
  
  # Raster with most probable category
  category <- colnames(probabilities)[apply(probabilities,1,which.max)]
  df_cat <- data.frame(x=df$x,y=df$y,ie=category)
  
  # Save rasters
  cat(format(Sys.time(), "%Y/%m/%e %H:%M:%S"), " - Escribiendo resultados del cluster ", i_cluster, "\n")
  write.csv(df_exp,file.path(out_path,'df_expectancy',paste0('df_exp_',i_cluster,'.csv')),
            row.names = FALSE)
  write.csv(df_cat,file.path(out_path,'df_categorical',paste0('df_cat_',i_cluster,'.csv')),
            row.names = FALSE)
}


input_csv <- 'data/model_input/discretized_df/df_input.csv'
out_path <- 'output'
prior_file <- 'data/model_input/prior/prior.RData' # Trained Bayesina network
n_parts <- 10000

total_rows <- as.numeric(system(paste("cat", input_csv, "| wc -l"), intern = TRUE)) - 1
prior <- readRDS(prior_file)

for (i in 1:n_parts) {
  predict_ie_bn(prior, 
                input_csv, 
                total_rows, 
                n_parts, 
                i, 
                out_path)
}