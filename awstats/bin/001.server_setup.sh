#!/bin/bash
#Install awstats from repository

#Download awstats from website 
#https://www.awstats.org/#DOWNLOAD

mkdir $HOME/install
cd $HOME/install
wget https://www.awstats.org/files/awstats-8.0.tar.gz
tar -xzf awstats-8.0.tar.gz
cp -R awstats /usr/local/

# as root user 
# one time setup 

cd /home/appawstats/
p -R awstats-8.0/ /usr/local/
ln -s /usr/local/awstats-8 .0 /usr/local/awstats


#sudo yum install awstats


#git clone https://github.com/mantonik/awstat.git

