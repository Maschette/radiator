# Detect if markers are biallelic

#' @name detect_biallelic_markers

#' @title Detect biallelic data

#' @description Detect if markers in tidy dataset are biallelic.
#' Used internally in \href{https://github.com/thierrygosselin/radiator}{radiator}
#' and might be of interest for users.

#' @param data A tidy data frame object in the global environment or
#' a tidy data frame in wide or long format in the working directory.
#' \emph{How to get a tidy data frame ?}
#' Look into \pkg{radiator} \code{\link{tidy_genomic_data}}.

#' @param verbose (optional, logical) \code{verbose = TRUE} to be chatty
#' during execution.
#' Default: \code{verbose = FALSE}.

#' @param parallel.core (optional) The number of core used for parallel
#' execution.
#' Default: \code{parallel.core = parallel::detectCores() - 1}.

#' @return A logical character string (TRUE/FALSE). That answer the question if
#' the data set is biallelic or not.

#' @export
#' @rdname detect_biallelic_markers
#' @importFrom dplyr select mutate group_by ungroup rename tally filter
#' @importFrom stringi stri_replace_all_fixed stri_sub
#' @importFrom tibble has_name
#' @importFrom tidyr gather
#' @importFrom purrr flatten_chr

#' @author Thierry Gosselin \email{thierrygosselin@@icloud.com}

detect_biallelic_markers <- function(data, verbose = FALSE, parallel.core = parallel::detectCores() - 1) {

  # Checking for missing and/or default arguments ------------------------------
  if (missing(data)) stop("Input file missing")

  # Import data ---------------------------------------------------------------
  if (is.vector(data)) {
    data <- radiator::tidy_wide(data = data, import.metadata = TRUE)
  }

  if (tibble::has_name(data, "GT_BIN")) {
    data <- TRUE
    if (verbose) message("    Data is bi-allelic")
  } else {
    # necessary steps to make sure we work with unique markers and not duplicated LOCUS
    if (tibble::has_name(data, "LOCUS") && !tibble::has_name(data, "MARKERS")) {
      data <- dplyr::rename(.data = data, MARKERS = LOCUS)
    }

    # markers with all missing... yes I've seen it... breaks code...
    # data <- detect_all_missing(data = data)
    marker.problem <- radiator::detect_all_missing(data = data)
    if (marker.problem$marker.problem) {
      data <- marker.problem$data
    }
    marker.problem <- NULL

    # Detecting biallelic markers-------------------------------------------------
    if (verbose) message("Scanning for number of alleles per marker...")
    if (tibble::has_name(data, "ALT")) {
      alt.num <- max(unique(
        stringi::stri_count_fixed(str = unique(data$ALT), pattern = ","))) + 1

      if (alt.num > 1) {
        data <- FALSE
        if (verbose) message("    Data is multi-allelic")
      } else {
        data <- TRUE
        if (verbose) message("    Data is bi-allelic")
      }
      alt.num <- NULL
    } else {
      # If there are less than 100 markers, sample all of them
      sampled.markers <- unique(data$MARKERS)
      n.markers <- length(sampled.markers)
      if (!n.markers < 100) {
        # otherwise 30% of the markers are randomly sampled
        # small.panel <- FALSE
        sampled.markers <- sample(x = sampled.markers,
                                  size = length(sampled.markers) * 0.30,
                                  replace = FALSE)
        n.markers <- length(sampled.markers)
      }

      # Allows to have either GT, GT_VCF_NUC, GT_VCF or GT_BIN
      # If more than 1 is discovered in data, keep 1 randomly.
      detect.gt <- purrr::keep(.x = colnames(data), .p = colnames(data) %in% c("GT", "GT_VCF_NUC", "GT_VCF","GT_BIN"))
      if (length(detect.gt) > 1) detect.gt <- sample(x = detect.gt, size = 1)
      want <- c("MARKERS", detect.gt)
      data <- suppressWarnings(dplyr::select(data, dplyr::one_of(want)))

      if (tibble::has_name(data, "GT")) {
        data <- dplyr::filter(data, GT != "000000") %>%
          dplyr::filter(MARKERS %in% sampled.markers) %>%
          dplyr::distinct(MARKERS, GT) %>%
          separate_gt(x = ., gt = "GT", sep = 3, exclude = "MARKERS", parallel.core = parallel.core) %>%
          # dplyr::mutate(A1 = stringi::stri_sub(GT, 1, 3), A2 = stringi::stri_sub(GT, 4,6)) %>%
          # dplyr::select(-GT) %>%
          # tidyr::gather(data = ., key = ALLELES_GROUP, value = ALLELES, -MARKERS) %>%
          dplyr::distinct(MARKERS, HAPLOTYPES) %>%
          dplyr::count(x = ., MARKERS) #%>% dplyr::select(n)
      }

      if (tibble::has_name(data, "GT_VCF")) {
        data <- dplyr::filter(data, GT_VCF != "./.") %>%
          dplyr::filter(MARKERS %in% sampled.markers) %>%
          dplyr::distinct(MARKERS, GT_VCF) %>%
          # tidyr::separate(data = ., col = GT_VCF, into = c("A1", "A2"), sep = "/") %>%
          # tidyr::gather(data = ., key = ALLELES_GROUP, value = ALLELES, -MARKERS) %>%
          separate_gt(x = ., gt = "GT_VCF", exclude = "MARKERS", parallel.core = parallel.core) %>%
          dplyr::distinct(MARKERS, HAPLOTYPES) %>% # Here read alleles, not haplotypes
          dplyr::count(x = ., MARKERS) #%>% dplyr::select(n)
      }

      if (tibble::has_name(data, "GT_VCF_NUC")) {
        data <- dplyr::filter(data, GT_VCF_NUC != "./.") %>%
          dplyr::filter(MARKERS %in% sampled.markers) %>%
          dplyr::distinct(MARKERS, GT_VCF_NUC) %>%
          # tidyr::separate(data = ., col = GT_VCF_NUC, into = c("A1", "A2"), sep = "/") %>%
          # tidyr::gather(data = ., key = ALLELES_GROUP, value = ALLELES, -MARKERS) %>%
          separate_gt(x = ., exclude = "MARKERS", parallel.core = parallel.core) %>%
          dplyr::distinct(MARKERS, HAPLOTYPES) %>%
          dplyr::count(x = ., MARKERS)
      }

      # if (small.panel) {
      n.allele <- dplyr::filter(data, n > 2)
      if (nrow(n.allele) == n.markers) {
        data <- FALSE
        if (verbose) message("    Data is multi-allelic")
      } else {
        if (verbose) message("    Data is bi-allelic")
        if (max(data$n) > 2) {
          message("\nNote: more than 2 types of alleles/nucleotides detected")
          message("artifact/biological ? run radiator::detect_biallelic_problem for more details")
        }
        data <- TRUE
      }
      # #} else {
      #   if (max(biallelic$n) > 4) {
      #     biallelic <- FALSE
      #     if (verbose) message("    Data is multi-allelic")
      #   } else {
      #     biallelic <- TRUE
      #     if (verbose) message("    Data is bi-allelic")
      #     if (max(biallelic$n) > 2) {
      #       message("\nNote: more than 2 types of alleles/nucleotides detected")
      #       message("artifact/biological ? run radiator::detect_biallelic_problem for more details")
      #     }
      #   }
      # }#
    }
  }
  return(data)
} # End detect_biallelic_markers
