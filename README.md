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
