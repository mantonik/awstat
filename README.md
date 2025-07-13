# AWStats-Based Log Analysis and Reporting System

## Overview

This document outlines the initial requirements for developing a portable log analysis and reporting application using AWStats. The application is intended to process internal web server logs, generate summary reports, and make them accessible via a PHP-based web interface. The system will be deployed under a single user (e.g., `support`) but must be flexible enough to adapt to varying usernames and installation environments.

## Objectives

* Use AWStats to process web server logs in a standardized format.
* Store AWStats outputs and a traffic summary into a SQLite3 database.
* Use PHP to display reports based on stored data.
* Maintain portability and configurability across environments.

## System Architecture

### Log Processing and Storage

1. **Log Directory Structure**:

   * All server logs are stored in a centralized location.
   * Folder structure: `/path/to/logs/<server_name>/`

2. **AWStats Processing**:

   * Use AWStats to analyze the logs.
   * The AWStats output HTML file must be stored in a configurable `domain folder` location for each webserver.
   * AWStats binary path must be configurable via a configuration file.
   * Logs are in AWStats-compatible format (Type 4) and include `X-Forwarded-For` headers for identifying the real client IP.

3. **AWStats Configuration**:

   * One central configuration file will be used for AWStats.
   * The file will contain sections for each URL pattern and include a list of servers, log file names, and their naming patterns.

4. **Data Summary Storage**:

   * After processing logs with AWStats, extract the following:

     * API Name (e.g., `/SOMetkOnline/check`, `/SOMetckOnline/isalive`)
     * Server
     * Day/Month
     * Count
   * Store summary data in a SQLite3 database.

### PHP Reporting Interface

1. **Index and Report Pages**:

   * A PHP-based index page will provide access to reports.
   * Reports will include:

     * Daily summary report.
     * Monthly summary report for a selected year.
     * Monthly traffic summary per server (for comparison).
     * Monthly total summary (complete API overview).

2. **Report Data Source**:

   * Reports will query the SQLite3 database created from the AWStats summaries.

3. **Access Control**:

   * Reports will be publicly accessible (no authentication required).

## Configuration

* All configurations should be read from:

  * `$HOME/etc/awstats/` (user's home directory)
  * Config files must specify:

    * AWStats binary location
    * Log base directory
    * Output directory for HTML reports (domain folder)
    * SQLite database file location

## Deployment Structure

* Scripts will reside in `$HOME/bin/awstats/`
* AWStats executable must be installed system-wide but referenced through config for flexibility.
* System must support changing usernames or environments with minimal changes.

## Output Management

* AWStats-generated HTML files must be placed into a user-defined domain folder for web access.
* SQLite3 DB files should be stored in a designated data directory under the user home (e.g., `$HOME/data/awstats.db`).
* Old HTML files will be retained in the output folders for future reference (no automatic cleanup or archiving).

## Additional Notes

* Scripts must be designed to run as cron jobs or on-demand by the `support` user (or equivalent).
* All output must be web-accessible via the PHP interface.

## Development Notes
We already had some base for this project and we ware working on it. 
Rebuild scripts in format 

* generate awstats data and base reports, reports per month for api calls, this is most important report for analize - one script
* init script - base on awstats_master_workflow.sh script - extract init and set it as awstats_init.sh, here build a db - I think separation of the tasks will be easier to makage tomorrow
* script to extract data from awstats database and insert to sqllite db 
* Desing php files for reports, 
* primary index.php will have a refernce to each domain folder in htdocs folder, it can have also a links to key reports in that folder like current month for awstats, yearly summary, yearly server break ( this way it will be not too overhelming when we will have several URLs and logs in this reporting system)
* second page is awstats_reprots.php?domain=domain.com - this page will show the list of all reports available in selected folder 
* css, js - those put into js,css folder those are separate files, not include in php/html codes
* once each log file is processed, move this to processed folder and compress with gz

Current tree of the folder structure 

/home/awstats$ tree
.
├── bin
│   └── awstats.txt
├── database
│   └── database_info.txt
├── etc
│   ├── awstats.conf
│   └── servers.conf
├── htdocs
│   └── htdocs.info
└── logs
    ├── info.txt
    ├── logs-sample.tar.gz
    ├── pnjt1sweb1
    │   ├── access-2025-04-05.log
    │   ├── access-2025-04-15.log
    │   ├── access-2025-05-05.log
    │   ├── access-2025-05-25.log
    │   ├── access-2025-06-05.log
    │   ├── access-2025-06-25.log
    │   ├── access-2025-07-01.log
    │   ├── access-2025-07-03.log
    │   └── processed
    └── pnjt1sweb2
        ├── access-2025-04-05.log
        ├── access-2025-04-15.log
        ├── access-2025-04-25.log
        ├── access-2025-05-05.log
        ├── access-2025-05-15.log
        ├── access-2025-05-25.log
        ├── access-2025-06-05.log
        ├── access-2025-06-15.log
        ├── access-2025-06-25.log
        ├── access-2025-07-01.log
        ├── access-2025-07-02.log
        ├── access-2025-07-03.log
        └── processed


## Deploymnet to server script 

yum install git
useradd appawstats

# clone repository
cd ${HOME}/git_repo/
rm -rf awstat
git clone https://github.com/mantonik/awstat.git

#move files to home folder 
cp -r awstat/awstats/* ${HOME}
chmod 755 bin/*.sh


mkdir git_repo
cd git_repo
wget https://github.com/mantonik/awstat/archive/refs/heads/main.zip
unzip main.zip 

https://devawstats.dmcloudarchitect.com/
