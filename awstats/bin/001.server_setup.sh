#!/bin/bash
#Install awstats from repository

#Download awstats from website 
#https://www.awstats.org/#DOWNLOAD

mkdir $HOME/install
cd $HOME/instal
wget https://www.awstats.org/files/awstats-8.0.tar.gz
tar -xzf awstats-8.0.tar.gz
cp -R awstats /usr/local/



sudo yum install awstats