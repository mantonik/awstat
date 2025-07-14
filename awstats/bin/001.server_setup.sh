#!/bin/bash
#Install awstats from repository

#Download awstats from website 
#https://www.awstats.org/#DOWNLOAD

sudo yum install -y perl-JSON-XS perl-Time-HiRes perl-DBI perl-Digest-MD5 perl-Net-DNS

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

chmod 755 /usr/local/awstats

cd /usr/local/awstats
find /usr/local/awstats/ -type d -exec chmod 755 {} \;
find /usr/local/awstats/ -type f -exec chmod 644 {} \;
find /usr/local/awstats/ -type f -name "*.pl" -exec chmod 755 {} \;


#sudo yum install awstats


#git clone https://github.com/mantonik/awstat.git

#Install perl packages if needed 
sudo yum install -y perl-CPAN
sudo cpan JSON::XS
sudo cpan Time::HiRes  
sudo cpan DBI
sudo cpan strict


