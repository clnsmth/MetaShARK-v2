#' @title Data Package files
#'
#' @description UI part of the DataFiles module.
#'
#' @importFrom shiny NS fluidPage column tags HTML icon actionButton uiOutput tagList textOutput
#' @importFrom shinyFiles shinyFilesButton
DataFilesUI <- function(id, title, dev = FALSE, server = FALSE) {
  ns <- NS(id)
  
  return(
    fluidPage(
      # main panel
      column(
        10,
        tags$h4("Data files"),
        HTML("When selecting your files, you can't select
                    folders. You can delete file(s) from your
                    selection by ticking their box and clicking
                    the 'Remove' button.<br>"),
        tags$div(
          if(isTRUE(server))
            tagList(
              "DISCLAIMER: any selected file will be immediately downloaded.",
              fileInput(
                ns("add_data_files"),
                "Select data file(s) from your dataset",
                buttonLabel = span("Load files", icon("plus-circle")),
                multiple = TRUE
              )
            )
          else
            shinyFilesButton(
              ns("add_data_files"),
              "Load files",
              "Select data file(s) from your dataset",
              multiple = TRUE,
              icon = icon("plus-circle")
            ),
          style = "display: inline-block; vertical-align: top;"
        ),
        uiOutput(ns("data_files")),
        actionButton(ns("remove_data_files"), "Remove",
          icon = icon("minus-circle"),
          class = "redButton"
        )
      ), # end of column 1
      column(
        2,
        navSidebar(ns("nav"),
          .prev = FALSE,
          ... = tagList(
            textOutput(ns("warning_data_size")),
            textOutput(ns("overwrite"))
          )
        ),
        if (dev) actionButton(ns("checkDataFiles"), "Dev")
      )
    ) # end fluidPage
  ) # end return
}

#' @title Data Package files
#'
#' @description server part of the DataFiles module.
#'
#' @importFrom shiny observeEvent reactiveValues callModule req checkboxGroupInput renderUI renderText
#' @importFrom shinyFiles getVolumes shinyFileChoose parseFilePaths
#' @importFrom shinyjs enable disable
#' @importFrom EMLassemblyline template_table_attributes
DataFiles <- function(input, output, session, savevar, globals, server) {
  ns <- session$ns
  
  if (globals$dev) {
    observeEvent(input$checkDataFiles, {
      browser()
    })
  }
  
  # Variable initialization ----
  rv <- reactiveValues(
    data_files = data.frame()
  )
  if(isTRUE(server))
    rv$tmpPaths <- character()
  if(!isTRUE(server))
    volumes <- c(Home = globals$HOME, getVolumes()())
  updateFileListTrigger <- makeReactiveTrigger()
  
  # On arrival on screen
  observeEvent(globals$EMLAL$HISTORY, {
    # dev: might evolve in `switch` if needed furtherly
    rv$data_files <- if (all(dim(savevar$emlal$DataFiles$dp_data_files) == c(0,0))) { # from create button in SelectDP
      data.frame()
    } else {
      savevar$emlal$DataFiles$dp_data_files
    }
    
    updateFileListTrigger$trigger()
  })
  
  # Navigation buttons ----
  callModule(
    onQuit, "nav",
    # additional arguments
    globals, savevar,
    savevar$emlal$SelectDP$dp_path,
    savevar$emlal$SelectDP$dp_name
  )
  callModule(
    onSave, "nav",
    # additional arguments
    savevar,
    savevar$emlal$SelectDP$dp_path,
    savevar$emlal$SelectDP$dp_name
  )
  callModule(
    nextTab, "nav",
    globals, "DataFiles"
  )
  
  # Data file upload ----
  # Add data files
  if(!isTRUE(server)) {
    shinyFileChoose(
      input,
      "add_data_files",
      roots = volumes,
      session = session
    )
  }

  observeEvent(input$add_data_files, {
    # validity checks
    req(input$add_data_files)
    
    # actions
    if(isTRUE(server))
      loadedFiles <- input$add_data_files
    else
      loadedFiles <- as.data.frame(
        parseFilePaths(volumes, input$add_data_files)
      )

    if (identical(rv$data_files, data.frame())) {
      rv$data_files <- loadedFiles
    } else {
      for (filename in loadedFiles$name) {
        if (!grepl("\\.", filename)) {
          message(filename, " is a folder.")
        } else {
          rv$data_files <- unique(rbind(
            rv$data_files,
            loadedFiles[loadedFiles$name == filename, ]
          ))
        }
      }
    }
    
    # copies on the server
    if(isTRUE(server)){
      withProgress({
        file.copy(rv$data_files$datapath, paste0(globals$TEMP.PATH, rv$data_files$name))
        incProgress(1)
      },
      message = "Downloading data files")
      
      rv$data_files$datapath <- paste0(globals$TEMP.PATH, rv$data_files$name)
    }
    
    # variable modifications
    savevar$emlal$DataFiles$dp_data_files <- rv$data_files
  })
  
  # Remove data files
  observeEvent(input$remove_data_files, {
    
    # validity check
    req(input$select_data_files)
    
    # actions
    rv$data_files <- rv$data_files[
      rv$data_files$name != input$select_data_files,
      ]
  })
  
  # Display data files
  output$data_files <- renderUI({
    updateFileListTrigger$depend()
    
    # actions
    if (!any(dim(rv$data_files) == 0) &&
        !is.null(rv$data_files)) {
      enable("nav-nextTab")
      checkboxGroupInput(ns("select_data_files"),
        "Select files to delete (all files here will be kept otherwise)",
        # choices = rv$data_files$name
        choiceNames = lapply(
          rv$data_files$name,
          function(label){
            id = match(label, rv$data_files$name)
            collapsibleUI(
              id = ns(id),
              label = label,
              hidden = FALSE,
              textAreaInput(
                ns(paste0(id,"-dataDesc")),
                "Data File Description",
                value = label
              )
            )
          }
        ),
        choiceValues = rv$data_files$name
      )
    }
    else {
      disable("nav-nextTab")
      return(NULL)
    }
  })
  
  observeEvent(names(input), {
    req(any(grep("dataDesc", names(input))))
    sapply(rv$data_files$name, function(id){
      callModule(collapsible, id)
      print(ns(id))
      ind <- match(id, rv$data_files$name)
      id <- paste0(id,"-dataDesc")
      observeEvent(input$id, {
        rv$data_file[ind, "description"] <- input$id
      })
    })
  })
  
  # Warnings ----
  # data size
  output$warning_data_size <- renderText({
    if (sum(rv$data_files$size) > globals$THRESHOLDS$data_files_size_max) {
      paste(
        "WARNING:", sum(rv$data_files$size),
        "bytes are about to be duplicated for data package assembly"
      )
    } else {
      ""
    }
  })
  
  # overwrite files
  output$warning_overwrite <- renderText({
    if (identical(
      dir(paste0(path, "/", dp, "/data_objects/")),
      character(0)
    )
    ) {
      paste("WARNING:", "Selected files will overwrite
            already loaded ones.")
    } else {
      ""
    }
  })
  
  # Process files ----
  # Template table
  observeEvent(input[["nav-nextTab"]],
    {
      # variable initialization
      dp <- savevar$emlal$SelectDP$dp_name
      path <- savevar$emlal$SelectDP$dp_path
      
      # actions
      # -- copy files to <dp>_emldp/<dp>/data_objects
      sapply(rv$data_files$datapath,
        file.copy,
        to = paste0(path, "/", dp, "/data_objects/"),
        recursive = TRUE
      )
      cmd <- paste(
        paste0("cd ", path, "/", dp, "/data_objects/"),
        paste(
          sapply(rv$data_files$name, function(fn){
            paste0("head -n 6 ", fn, " > preview_", fn)
          }),
          collapse = "; "
        ),
        sep = "; "
      )
      system(cmd)
      
      # -- modify paths in save variable
      tmp <- savevar$emlal$DataFiles$dp_data_files
      tmp$datapath <- sapply(
        rv$data_files$name,
        function(dpname) {
          force(dpname)
          paste0(path, "/", dp, "/data_objects/", dpname)
        }
      )
      tmp$metadatapath <- sapply(
        rv$data_files$name,
        function(dpname) {
          force(dpname)
          paste0(
            path, "/", dp, "/metadata_templates/",
            sub(
              "(.*)\\.[a-zA-Z0-9]*$",
              "attributes_\\1.txt",
              dpname
            )
          )
        }
      )
      savevar$emlal$DataFiles$dp_data_files <- tmp
      
      # EMLAL templating function
      template_table_attributes(
        path = paste0(path, "/", dp, "/metadata_templates"),
        data.path = paste0(path, "/", dp, "/data_objects"),
        data.table = rv$data_files$name
      )
      
      message(ns(": Done!"))
    },
    priority = 1
  )
  
  # Output ----
  return(savevar)
}
