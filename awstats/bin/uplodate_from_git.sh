#!/bin/bash 

#preparation for update 
rm -rf ${HOME}/bin
rm -rf ${HOME}/etc
rm -rf ${HOME}/database
rm -rf ${HOME}/docs

mkdir $HOME/install
cd $HOME/install

git clone https://github.com/mantonik/awstat.git

cp -Rf awstat/awstats/* $HOME/

chmod 700 $HOME/bin/*.sh

