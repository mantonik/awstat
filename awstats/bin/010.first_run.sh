#!/bin/bash

# After uploading files and setting up logs:

# Step 1: Initialize
$HOME/bin/awstats_init.sh

# Step 2: Validate config  
$HOME/bin/config_parser.sh validate

# Step 3: Process (recommended first run)
$HOME/bin/awstats_processor.sh --all --months 3 --parallel 2

# Step 4: Test web interface
#cd htdocs && php -S localhost:8080

