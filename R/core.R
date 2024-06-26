form_play_request <-
  function(play = NULL,
           corpus = NULL,
           type = NULL) {
    stopifnot(is.character(corpus) && length(corpus) == 1)
    stopifnot(is.character(play) && length(play) == 1)
    request <-
      paste0(get_dracor_api_url(), "/corpora/", corpus, "/plays/", play)
    if (!is.null(type)) {
      return(paste(request, type, sep = "/"))
    } else {
      return(request)
    }
  }

#' @import httr
dracor_error <- function(resp) {
  if (resp$status_code == 404) {
    stop(
      sprintf(
        "Status code - %i: Wrong Dracor API request - data were not found",
        resp$status_code
      )
    )
  } else if (resp$status_code == 400) {
    stop(
      sprintf(
        "Status code - %i: Wrong Dracor API request - invalid request",
        resp$status_code
      )
    )
  } else if (resp$status_code >= 500) {
    stop(sprintf(
      "Status code - %i: Internal Dracor server problem",
      resp$status_code
    ))
  } else if (resp$status_code != 200) {
    stop(sprintf("Status code - %i: Unknown problem", resp$status_code))
  }
}

#' Send a GET request to DraCor API and parse the results
#'
#' Function \code{dracor_api()} sends a GET request to DraCor API with a
#' specified expected type and parses results depending on selected expected
#' type.
#'
#' There are four different 'MIME' types (aka internet media type) that can be
#' retrieved for DraCor API, the specific combination of possible 'MIME' types
#' depends on API command. When \code{parse = TRUE} is used, the content is
#' parsed depending on selected 'MIME' type in \code{expected_type}:
#' \describe{
#'   \item{\code{application/json}}{\code{
#'   \link[jsonlite:fromJSON]{jsonlite::fromJSON()}}}
#'   \item{\code{application/xml}}{\code{\link[xml2:read_xml]{xml2::read_xml()}}}
#'   \item{\code{text/csv}}{\code{\link[data.table:fread]{data.table::fread()}}}
#'   \item{\code{text/plain}}{No need for additional preprocessing}}
#'
#' @param request Character, valid GET request.
#' @param expected_type Character, 'MIME' type: one of
#' \code{"application/json"},  \code{"application/xml"}, \code{"text/csv"},
#' \code{"text/plain"}.
#' @param parse Logical, if \code{TRUE} (default value), then a response is
#'   parsed depending on \code{expected_type}. See details below.
#' @param default_type Logical, if \code{TRUE}, default response data type is
#'   returned. Therefore, a response is not parsed and \code{parse} is ignored.
#'   The default value is \code{FALSE}.
#' @param split_text Logical, if \code{TRUE}, plain text lines are read as
#'   different values in a vector instead of returning one character value.
#'   Default value is \code{TRUE}.
#' @param as_tibble Logical, if \code{TRUE}, data frame will be returned as a
#'   tidyverse tibble (\code{tbl_df}). The default value is \code{TRUE}.
#' @param ... Other arguments passed to a parser function.
#' @return A content of a response to GET method to the 'DraCor' API. If
#' \code{parse = FALSE} or \code{default_type = TRUE}, a single character value
#' is returned. Otherwise, the resulting value is parsed according to a value of
#' \code{default_type} parameter. The resulting structure of the output depends
#' on the selected \code{default_type} value, the respective function for
#' parsing (see \code{default_type}) and additional parameters that are passed
#' to the function for parsing.
#' @examples
#' dracor_api("https://dracor.org/api/v1/info", expected_type = "application/json")
#' @seealso \code{\link{dracor_sparql}}
#' @import httr
#' @importFrom jsonlite fromJSON
#' @importFrom tibble as_tibble
#' @import xml2
#' @import data.table
#' @export
dracor_api <- function(request,
                       expected_type =
                         c(
                           "application/json",
                           "application/xml",
                           "text/csv",
                           "text/plain"
                         ),
                       parse = TRUE,
                       default_type = FALSE,
                       split_text = TRUE,
                       as_tibble = TRUE,
                       ...) {
  expected_type <- match.arg(expected_type)
  if (isTRUE(default_type)) {
    resp <- tryCatch(httr::GET(request,
                               config = httr::config(ssl_verifypeer = FALSE)),
                     error = function(e) message("Problem with server occured:\n
                                                 improper data returned:\n", e))
    return(httr::content(resp, as = "text", encoding = "UTF-8"))
  } else {
    resp <- tryCatch(httr::GET(request,
                      httr::accept(expected_type),
                      httr::config(ssl_verifypeer = FALSE)),
                     error = function(e) message("Problem with server occured:\n
                                                 improper data returned:\n", e))
  }
  dracor_error(resp)
  cont <- httr::content(resp, as = "text", encoding = "UTF-8")
  if (!isTRUE(parse)) {
    return(cont)
  }
  switch(expected_type,
    "application/json" = if (as_tibble) {
      return(tibble::as_tibble(jsonlite::fromJSON(cont, ...)))
    } else {
      return(jsonlite::fromJSON(cont, ...))
    },
    "application/xml" = return(xml2::read_xml(cont, ...)),
    "text/csv" = if (as_tibble) {
      return(tibble::as_tibble(data.table::fread(cont, ...)))
    } else {
      return(data.table::fread(cont, ...))
    },
    "text/plain" = if (split_text) {
      return(unlist(strsplit(cont, "\n")))
    } else {
      return(cont)
    }
  )
}

#' Submit SPARQL queries to DraCor API
#'
#' \code{dracor_sparql()} submits SPARQL queries and parses the result.
#'
#' @return SPARQL xml parsed.
#' @param sparql_query Character, SPARQL query.
#' @param parse Logical, if \code{TRUE} the result is parsed by
#' {\code{\link[xml2:read_xml]{xml2::read_xml()}}}, otherwise character value is
#' returned. Default value is \code{TRUE}.
#' @inheritParams get_play_metadata
#' @examples
#' dracor_sparql("SELECT * WHERE {?s ?p ?o} LIMIT 10")
#' # If you want to avoid parsing by xml2::read_xml():
#' dracor_sparql("SELECT * WHERE {?s ?p ?o} LIMIT 10", parse = FALSE)
#' @seealso \code{\link{get_dracor}}
#' @importFrom utils URLencode
#' @export
dracor_sparql <- function(sparql_query = NULL, parse = TRUE, ...) {
  if (is.null(sparql_query)) {
    stop("SPARQL query must be provided")
  }
  query <- paste0(
    "https://dracor.org/fuseki/sparql?query=",
    URLencode(sparql_query, reserved = TRUE)
  )
  dracor_api(query, expected_type = "application/xml", parse = parse, ...)
}

#' Retrieve 'DraCor' API info
#'
#' \code{dracor_api_info()} returns information about 'DraCor' API: name of
#' the API, status, existdb version, API version etc.
#'
#' @param dracor_api_url Character, 'DraCor' API URL. If NULL (default), the
#' current 'DraCor' API URL is used.
#' @param new_dracor_api_url Character, 'DraCor' API URL that will replace
#' the current 'DraCor' API URL.
#'
#' @return NULL
#' @examples
#' dracor_api_info()
#' dracor_api_info("https://staging.dracor.org/api")
#' get_dracor_api_url()
#' @seealso \code{\link{dracor_api}}
#' @importFrom jsonlite fromJSON
#' @importFrom tibble as_tibble
#' @export
dracor_api_info <- function(dracor_api_url = NULL) {
  if (is.null(dracor_api_url)) dracor_api_url = get_dracor_api_url()
  tryCatch(
    api_info_list <- dracor_api(paste0(dracor_api_url, "/info"),
                                as_tibble = FALSE),
    error = function(e) cat("DraCor API was not found:\n", e),
    finally = cat("DraCor API URL: ", dracor_api_url, "\n",
                  paste(names(api_info_list),
                        unlist(api_info_list),
                        sep = ": ",
                        collapse = "\n"))
  )
  invisible(NULL)
}

#' @export
#' @describeIn dracor_api_info Returns 'DraCor' API URL in use
get_dracor_api_url <- function() {
  the$dracor_api_url
}


#' @export
#' @describeIn dracor_api_info Set new 'DraCor' API URL (globally), returns NULL
set_dracor_api_url <- function(new_dracor_api_url) {
  cat("Working DraCor repository was changed from", get_dracor_api_url(), "\n")
  the$dracor_api_url <- new_dracor_api_url
  dracor_api_info()
}
