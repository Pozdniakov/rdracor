test_that("Numeric values induce error", {
  expect_error(form_play_request(1, 3))
})

test_that("NULL values induce error", {
  expect_error(form_play_request())
})

test_that("More than one corpus induce error for a play", {
  expect_error(form_play_request("pushkin-boris-godunov", c("rus", "ger")))
})

test_that("Valid request is created", {
  expect_equal(
    form_play_request(play = "pushkin-boris-godunov", corpus = "rus"),
    "https://dracor.org/api/v1/corpora/rus/plays/pushkin-boris-godunov"
  )
})

test_that("dracor_sparql() returns xml_document by default", {
  expect_s3_class(
    dracor_sparql("SELECT * WHERE {?s ?p ?o} LIMIT 10"),
    "xml_document"
  )
})

test_that("dracor_sparql() returns character with parse = FALSE", {
  expect_type(
    dracor_sparql("SELECT * WHERE {?s ?p ?o} LIMIT 10",
      parse = FALSE
    ),
    "character"
  )
})

test_that("dracor_sparql() returns xml_document", {
  expect_s3_class(
    dracor_sparql("SELECT * WHERE {?s ?p ?o} LIMIT 10"),
    "xml_document"
  )
})

test_that("dracor_sparql() with parse = FALSE returns character", {
  expect_type(
    dracor_sparql("SELECT * WHERE {?s ?p ?o} LIMIT 10",
      parse = FALSE
    ),
    "character"
  )
})

test_that("dracor_api_info returns NULL", {
  expect_invisible(dracor_api_info())
})

test_that("get_dracor_api_info returns https://dracor.org/api/v1", {
  expect_equal(get_dracor_api_url(), "https://dracor.org/api/v1")
})
