
user <- ""
password <- ""

# Install the required packages
# install.packages("DBI")
# install.packages("RPostgreSQL")
# install.packages("tidyverse")
# install.packages("lubridate")

# Load Them
require("DBI")
require("RPostgreSQL")
require("tidyverse")
require("lubridate")

# The types of cases (for reference)
# DSCIVIL - district civil system (DONE)
# DSTRAF - district traffic court
# DSCR - district criminal system (DONE)
# DSCP - district civil citations
# DSK8 - circuit criminal system (DONE)
# DV - district domestic violence (civil system)
# CC - circuit civil system (DONE)
# K - circuit criminal (seems to all be child support cases?)

# create an PostgreSQL instance and create a connection
drv <- dbDriver("PostgreSQL")

# open the connection using user, passsword, etc., as
con <- dbConnect(drv, dbname = "mjcs",
                 port=5432,
                 user=user,
                 password=password,
                 host="mjcs.c7q0zmxhx4uo.us-east-1.rds.amazonaws.com")

# query colnames
db.colnames<-dbGetQuery(con, 
                        statement ="
           SELECT
           TABLE_NAME,
           COLUMN_NAME
           FROM
           INFORMATION_SCHEMA.COLUMNS
           ")

#################
# Bail and Bond #
#################
# dbGetQuery(con, statement = '
#    
#                    select * from dsk8_bail_and_bond limit 10')
dsk8.source<-dbGetQuery(con, statement = '
   
                   select
         c.filing_date,
         c.court,
         bb.*
                   from
                   cases c
                   inner join dsk8  on dsk8.case_number=c.case_number
                   inner join dsk8_bail_and_bond bb on bb.case_number=c.case_number
where 1=1 and c.filing_date>\'2016-12-01\'
                   ')

dscr.source<-dbGetQuery(con, statement = '
                   select
         c.filing_date,
         c.court,
         bb.*
         
                   from
                   cases c
                   inner join dscr  on dscr.case_number=c.case_number
                   inner join dscr_bail_events bb on bb.case_number=c.case_number
where 1=1 
and c.filing_date>\'2016-12-01\'
                   ')

demo.source<-dbGetQuery(con, statement = '
                   select 
                   c.case_number,
                   sex, race, "DOB" 
                   from
                   cases c 
                   inner join dscr_defendants def on c.case_number=def.case_number 
                   where 1=1 
                   and c.filing_date>\'2016-12-01\'
                        ') %>% unique()


cases <- rbind(select(dscr.source,
                    case_number,
                    filing_date,
                    court),
               select(dsk8.source,
                      case_number,
                      filing_date,
                      court)) %>% unique()

bond <- rbind(select(dsk8.source,
               case_number,
               bail_amount),
select(dscr.source,
               case_number,
               bail_amount)) %>%
  group_by(case_number) %>%
  summarise(bail_amount=sum(bail_amount, na.rm=T))

cases.bond <- left_join(left_join(cases,bond),demo.source) 

bond.summary <- cases.bond %>%
  group_by(race) %>%
  summarise(bond=sum(bail_amount,na.rm=T),
            cases=n())
n.cases <- bond.summary$cases
names(n.cases) <- bond.summary$race
bonds<-bond.summary$bond
names(bonds) <- bond.summary$race
pie(bonds[order(bonds)])
pie(n.cases[order(n.cases)])
