# private_alleles

#' @name private_alleles
#' @title Find private alleles
#' @description The function uses a tidy genomic data frame

#' @param data A tidy data frame object in the global environment or
#' a tidy data frame in wide or long format in the working directory.
#' \emph{How to get a tidy data frame ?}
#' Look into \pkg{radiator} \code{\link{tidy_genomic_data}}.

#' @param strata (optional)
#' The strata file is a tab delimited file (in directory or global environment)
#' with 2 columns headers:
#' \code{INDIVIDUALS} and \code{STRATA}.
#' The \code{STRATA} column can be any hierarchical grouping.
#' The default uses the grouping in the dataset.
#' Default: \code{strata = NULL}.

#' @return A list with an object highlighting private alleles by markers and strata and
#' a second object with private alleles summary by strata.

#' @examples
#' \dontrun{
#' corals.private.alleles.by.pop <- radiator::private_alleles(data = tidy, strata = strata.pop)
#' }



#' @rdname private_alleles
#' @export
#'
#' @importFrom stringi stri_replace_all_regex stri_join stri_replace_all_fixed
#' @importFrom dplyr n_distinct select left_join distinct mutate group_by ungroup filter tally arrange rename one_of
#' @importFrom tidyr gather separate
#' @importFrom readr write_tsv read_tsv cols col_character


#' @author Thierry Gosselin \email{thierrygosselin@@icloud.com}

private_alleles <- function(data, strata = NULL) {
  cat("#######################################################################\n")
  cat("####################### radiator::private_alleles #####################\n")
  cat("#######################################################################\n")
  timing <- proc.time()
  opt.change <- getOption("width")
  options(width = 70)

  # Import data ---------------------------------------------------------------
  if (missing(data)) stop("Input file missing")
  if (missing(strata)) stop("Strata file missing")

  if (is.vector(data)) {
    data <- radiator::tidy_wide(data = data, import.metadata = TRUE)
  }

  if (!is.null(strata)) {
    if (is.vector(strata)) {
      strata <- readr::read_tsv(file = strata,  col_types = readr::cols(.default = readr::col_character()))
    }

    colnames(strata) <- stringi::stri_replace_all_fixed(
      str = colnames(strata),
      pattern = "POP_ID",
      replacement = "STRATA",
      vectorize_all = FALSE)

    # Remove potential whitespace in pop_id
    strata$STRATA <- radiator::clean_pop_names(strata$STRATA)

    # clean ids
    strata$INDIVIDUALS <- radiator::clean_ind_names(strata$INDIVIDUALS)

    data <- suppressWarnings(
      dplyr::ungroup(data) %>%
        dplyr::select(-dplyr::one_of(c("POP_ID", "STRATA"))) %>%
        dplyr::left_join(strata, by = "INDIVIDUALS")
    )
  } else {
    colnames(data) <- stringi::stri_replace_all_fixed(
      str = colnames(data),
      pattern = "POP_ID",
      replacement = "STRATA",
      vectorize_all = FALSE)
  }


 data <- dplyr::filter(data, GT != "000000") %>%
    dplyr::distinct(STRATA, MARKERS, GT, .keep_all = TRUE)

  if (tibble::has_name(data, "GT_VCF_NUC")) {
    private <- dplyr::distinct(data, STRATA, MARKERS, GT_VCF_NUC) %>%
      tidyr::separate(data = ., col = GT_VCF_NUC, into = c("A1", "A2"), sep = "/") %>%
      tidyr::gather(data = ., key = GROUP, value = ALLELE, -c(MARKERS, STRATA)) %>%
      dplyr::select(-GROUP) %>%
      dplyr::distinct(MARKERS, STRATA, ALLELE)
  } else {
    private <- dplyr::distinct(data, STRATA, MARKERS, GT) %>%
      dplyr::mutate(
        A1 = stringi::stri_sub(GT, 1, 3),
        A2 = stringi::stri_sub(GT, 4, 6)) %>%
      dplyr::select(-GT) %>%
      tidyr::gather(data = ., key = GROUP, value = ALLELE, -c(MARKERS, STRATA)) %>%
      dplyr::select(-GROUP) %>%
      dplyr::distinct(MARKERS, STRATA, ALLELE)
  }
  data <- NULL
  private.search <- private %>%
    dplyr::group_by(MARKERS, ALLELE) %>%
    dplyr::tally(.) %>%
    dplyr::filter(n == 1) %>%
    dplyr::distinct(MARKERS, ALLELE) %>%
    dplyr::left_join(private, by = c("MARKERS", "ALLELE")) %>%
    dplyr::ungroup(.) %>%
    dplyr::select(STRATA, MARKERS, ALLELE) %>%
    dplyr::arrange(STRATA, MARKERS, ALLELE) %>%
    readr::write_tsv(x = ., path = "private.alleles.tsv")

  private.summary <- private.search %>%
    dplyr::group_by(STRATA) %>%
    dplyr::tally(.) %>%
    dplyr::ungroup(.) %>%
    tibble::add_row(.data = ., STRATA = "OVERALL", n = sum(.$n)) %>%
    dplyr::rename(PRIVATE_ALLELES = n) %>%
    readr::write_tsv(x = ., path = "private.alleles.summary.tsv")

 if(nrow(private.summary) > 0) {
   message("Number of private alleles per strata:")
   priv.message <- dplyr::mutate(private.summary, PRIVATE = stringi::stri_join(STRATA, PRIVATE_ALLELES, sep = " = "))
   message(stringi::stri_join(priv.message$PRIVATE, collapse = "\n"))
   res <- list(private.alleles = private.search, private.alleles.summary = private.summary)
 } else {
   message("Private allele(s) found: 0")
   res <- "0 private allele"
 }

  message("\nComputation time: ", round((proc.time() - timing)[[3]]), " sec")
  cat("############################## completed ##############################\n")
  options(width = opt.change)
  return(res)
}#End private_alleles
