#!/bin/bash
sudo yum -y update
sudo yum -y install httpd
sudo amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2
sudo service httpd start
cd ~
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
cp wordpress/wp-config-sample.php wordpress/wp-config.php
SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
STRING='put your unique phrase here'
printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s wp-config.php
sed -i "s/define( 'DB_NAME', 'database_name_here' );/define( 'DB_NAME', '${db_name}' );/" wordpress/wp-config.php
sed -i "s/define( 'DB_USER', 'username_here' );/define( 'DB_USER', '${db_user}' );/" wordpress/wp-config.php
sed -i "s/define( 'DB_PASSWORD', 'password_here' );/define( 'DB_PASSWORD', '${db_password}' );/" wordpress/wp-config.php
sed -i "s/define( 'DB_HOST', 'localhost' );/define( 'DB_HOST', '${db_hostname}' );/" wordpress/wp-config.php
sudo mv wordpress/* /var/www/html/
sudo service httpd restart
