#' @title .headerScript
#'
#' @description Misc preparations commands
.headerScript <- function() {
  rm(list = ls())
  options(shiny.reactlog = TRUE)
}

#' @title .globalScript
#'
#' @description script to generate `globals` reactiveValues
#'
#' @importFrom fs path_home
#' @importFrom dataone listFormats CNode
#' @importFrom shiny reactiveValues
#' @importFrom EML get_unitList
#' @importFrom data.table fread
.globalScript <- function(dev = FALSE, reactive = TRUE) {
  if (!is.logical(dev) || is.null(dev)) dev <- FALSE

  HOME <- path_home()
  DP.PATH <- paste0(HOME, "/dataPackagesOutput/emlAssemblyLine/")
  dir.create(DP.PATH, recursive = TRUE, showWarnings = FALSE)
  TMP.PATH <-  paste0(HOME, "/EMLAL_tmp/")
  # clear the temp
  unlink(TMP.PATH, recursive = TRUE) 
  dir.create(TMP.PATH, recursive = TRUE, showWarnings = FALSE)

  THRESHOLD <- list(
    dp_data_files = 500000
  )

  # Date time format strings
  # TODO better !
  DATE.FORMAT <- c(
    "YYYY", "YYYY-MM", "YYYY-MM-DD",
    "hh", "hh:mm", "hh:mm:ss",
    "YYYY-MM-DD hh", "YYYY-MM-DD hh:mm", "YYYY-MM-DD hh:mm:ss",
    "YYYY hh", "YYYY hh:mm", "YYYY hh:mm:ss"
  )
  
  # Unit types
  UNIT.LIST <- c("custom", get_unitList()$units$name)
  
  # Paths
  wwwPaths <- system.file("resources", package="MetaShARK") %>% 
    paste(., dir(.), sep = "/") %>%
    as.list
  names(wwwPaths) <- basename(unlist(wwwPaths))
  
  # DataONE nodes
  # DATAONE.LIST <- dataone::listFormats(dataone::CNode())$MediaType
  DATAONE.LIST <- unlist(fread(wwwPaths$dataoneCNodesList.txt))
  
  # Taxa authorities
  # TAXA.AUTHORITIES <-  taxonomyCleanr::view_taxa_authorities()
  TAXA.AUTHORITIES <- fread(wwwPaths$taxaAuthorities.txt)
  
  # Build global variable
  if(reactive)
    globals <- reactiveValues(
      dev = dev,
      THRESHOLDS = reactiveValues(data_files_size_max = 500000),
      DEFAULT.PATH = DP.PATH,
      TEMP.PATH = TMP.PATH,
      HOME = HOME,
      PATHS = wwwPaths,
      # Formats lists
      FORMAT = list(
        DATE = DATE.FORMAT,
        UNIT = UNIT.LIST,
        DATAONE = DATAONE.LIST,
        AUTHORITIES = TAXA.AUTHORITIES
      ),
      # Regex patterns
      PATTERNS = list(
        # match one expression for latitude or longitude
        LATLON = "[+-]?[[:digit:]]+[.,]*[[:digit:]]*",
        NAME = "^[[:alpha:] \\'\\.\\-]+$",
        EMAIL = "^[^@]+@[^@]+\\.[[:alpha:]]",
        ORCID = "^\\d{4}-\\d{4}-\\d{4}-(\\d{4}|\\d{3}X)$"
      ),
      # navigation variable in EMLAL module
      EMLAL = reactiveValues(
        HISTORY = character(),
        NAVIGATE = 1
      )
    )
  else
    globals <- list(
      dev = dev,
      THRESHOLDS = reactiveValues(data_files_size_max = 500000),
      DEFAULT.PATH = DP.PATH,
      HOME = HOME,
      PATHS = wwwPaths,
      # Formats lists
      FORMAT = list(
        DATE = DATE.FORMAT,
        UNIT = UNIT.LIST,
        DATAONE = DATAONE.LIST,
        AUTHORITIES = TAXA.AUTHORITIES
      )
    )
  # output
  return(globals)
}
