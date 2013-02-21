#
# class mysql::server::galera_monitor provides in-depth monitoring of a MySQL Galera Node. 
# The class is meant to be used in conjunction with HAProxy.
# The class  has only been tested on Ubuntu 12.04 and HAProxy 1.4.18-0ubuntu1
#
# Requires augeas puppet module
#
# Here is an example HAProxy configuration that implements Galera health checking
#listen galera 192.168.220.40:3306
#  balance  leastconn
#  mode  tcp
#  option  tcpka
#  option  httpchk
#  server  control01 192.168.220.41:3306 check port 9200 inter 2000 rise 2 fall 5
#  server  control02 192.168.220.42:3306 check port 9200 inter 2000 rise 2 fall 5
#  server  control03 192.168.220.43:3306 check port 9200 inter 2000 rise 2 fall 5
#
# Example Usage:
#
# class {'mysql::server::galera_monitor': }
#
class mysql::server::galera_monitor(
  $mysql_monitor_hostname = $mysql::params::bind_address,
  $mysql_port             = $mysql::params::port,
  $mysql_bin_dir          = '/usr/bin/mysql',
  $mysqlchk_script_dir    = '/usr/local/bin',
  $xinetd_dir 	          = '/etc/xinetd.d',
  $mysql_monitor_username = 'mysqlchk_user',
  $mysql_monitor_password = 'mysqlchk_password',
  $enabled                = true,
) inherits mysql::params {

  # Needed to manage /etc/services
  include augeas

  Class['mysql::server'] -> Class['mysql::server::galera_monitor']

  if $enabled {
    $service_ensure = 'running'
   } else {
    $service_ensure = 'stopped'
  }

  service { 'xinetd' :
    ensure      => $service_ensure,
    enable      => $enabled,
    require     => [Package['xinetd'],File["${xinetd_dir}/mysqlchk"]],
    subscribe   => File["${xinetd_dir}/mysqlchk"],
  }

  package { 'xinetd':
    ensure  => present,
    require => Package['wsrep','galera'],
  }

  file { $mysqlchk_script_dir:
    ensure  => directory,
    mode    => '0755',
    require => Package['xinetd'],
    owner   => 'root',
    group   => 'root',
  }

  file { $xinetd_dir:
    ensure  => directory,
    mode    => '0755',
    require => Package['xinetd'],
    owner   => 'root',
    group   => 'root',
  }

  file { "${mysqlchk_script_dir}/galera_chk":
    mode    => '0755',
    require => File[$mysqlchk_script_dir],
    content => template("mysql/galera_chk"),
    owner   => 'root',
    group   => 'root',
  }

  file { "${xinetd_dir}/mysqlchk":
    mode    => '0644',
    require => File[$xinetd_dir],
    content => template("galera/mysqlchk"),
    owner   => 'root',
    group   => 'root',  
  }

  # Manage mysqlchk service in /etc/services
  augeas { "mysqlchk":
    require => File["${xinetd_dir}/mysqlchk"],
    context =>  "/files/etc/services",
    changes => [
      "ins service-name after service-name[last()]",
      "set service-name[last()] mysqlchk",
      "set service-name[. = 'mysqlchk']/port 9200",
      "set service-name[. = 'mysqlchk']/protocol tcp",
    ],  
    onlyif => "match service-name[port = '9200'] size == 0",
  }

  # Create a user for MySQL Galera health check script.
  database_user{ "${mysql_monitor_username}@${mysql_monitor_hostname}":
    ensure        => present,
    password_hash => mysql_password($mysql_monitor_password),
  }

  database_grant { "${mysql_monitor_username}@${mysql_monitor_hostname}":
    privileges => [ 'process_priv', 'super_priv' ],
    require    => Database_user["${mysql_monitor_username}@${mysql_monitor_hostname}"],
  }
}
