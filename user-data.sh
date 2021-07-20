#!/bin/bash
# Download and install necessary packages
yum update -y
amazon-linux-extras install vim python3.8 -y
pip3 install virtualenv
mkdir app
cd app
python3 -m virtualenv venv
. venv/bin/activate
pip3 install flask psycopg2 configparser redis
amazon-linux-extras install postgresql11 -y
yum install -y postgresql-server postgresql-devel
/usr/bin/postgresql-setup --initdb
systemctl enable postgresql
systemctl start postgresql


# Download source code from GitHub
wget https://github.com/johnmichaelbutler/elastic-cache-challenge/archive/refs/heads/master.zip
unzip master.zip
rm master.zip
