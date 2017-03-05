#!/bin/bash
set -e

exec 200>~/deploy.lock || exit 1

#Create deploy lock
flock -n 200 || { echo "RUNNING" >&2; exit 1; }

#Settings
PROJECT="$1"
ENVIRONMENT="$2"
S3_DIST_REPO="$3"
S3_DIST_REGION="$4"
HEALTH_CHK_FILE="elb-healthcheck-app-298fvd78.php"

#Get deploy config
aws s3 cp s3://${S3_DIST_REPO}/${PROJECT}/${ENVIRONMENT}/deploy.conf /home/centos/deploy.conf --region ${S3_DIST_REGION}
source /home/centos/deploy.conf

#Get dist
aws s3 cp s3://${S3_DIST_REPO}/${PROJECT}/${ENVIRONMENT}/dist/${TAG}.tar.gz /home/centos/ --region ${S3_DIST_REGION}
mkdir -p /var/www/html/${PROJECT}-${TAG}
tar -zxf /home/centos/${TAG}.tar.gz -C /var/www/html/${PROJECT}-${TAG}
cd /var/www/html/${PROJECT}-${TAG}

#Update wp-config.php
sed -i "/DB_HOST/s/'[^']*'/'${DB_HOST}'/2" wp-config.php
sed -i "/DB_NAME/s/'[^']*'/'${DB_NAME}'/2" wp-config.php
sed -i "/DB_USER/s/'[^']*'/'${DB_USER}'/2" wp-config.php
sed -i "/DB_PASSWORD/s/'[^']*'/'${DB_PASSWORD}'/2" wp-config.php

#Create upload folder if is missing and setup upload permission
mkdir -p wp-content/uploads
sudo chown nginx:nginx wp-content/uploads -R

#Create ELB check file
touch $HEALTH_CHK_FILE

#Update file permissions
find -type d -exec chmod 755 {} \;
find -type f -exec chmod 644 {} \;

#Create symlink
ln -sf /var/www/html/${PROJECT}-${TAG} /var/www/html/${PROJECT}

#Reload nginx and restart php-fpm
sudo systemctl restart php71-php-fpm
sudo systemctl reload nginx

#Release lock
flock -u 200
