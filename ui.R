
library(shiny)
library(ggplot2)

# Define UI for miles per gallon application
shinyUI(pageWithSidebar(

  # Application title
  headerPanel("Food Poisoning Tweets"),
   
  sidebarPanel(
    selectInput(inputId = "category",
      label = "Select Tweet Classification",
      choices = c("All", "Good", "Junk"),
      selected = "All"),
    selectInput(inputId = "city",
      label = "Select City",
      choices = c("All", "Boston", "Houston", "Jacksonville", "Los Angeles",
          "Minneapolis", "Philadelphia", "Phoenix", "San Francisco"),
      selected = "All"),
    checkboxInput("rt", "Show Retweets", FALSE),
    br(),
    uiOutput("day.slider"),
    br(),
    textInput("search.term", "Subset Data By Search Term", "")
##    br(),
##    actionButton("refresh", "Click to Update Data (takes about a minute)")
  ),
  
  mainPanel(
    h3(textOutput("caption")),
    plotOutput("plot"),    
    tableOutput("tweet.table")
  )
))
