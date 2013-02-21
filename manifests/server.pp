# Class: mysql::server
#
# manages the installation of the mysql server.  manages the package, service,
# my.cnf
#
# Parameters:
#   [*package_name*] - name of package
#   [*service_name*] - name of service
#   [*config_hash*]  - hash of config parameters that need to be set.
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
class mysql::server (
  $package_ensure      = 'present',
  $service_name        = $mysql::params::service_name,
  $service_provider    = $mysql::params::service_provider,
  $galera	       = false,
  $wsrep_package_name  = $mysql::params::wsrep_package_name,
  $wsrep_source_name   = $mysql::params::wsrep_source_name,
  $galera_source_name  = $mysql::params::galera_source_name,
  $libaio_package_name = $mysql::params::libaio_package_name,
  $libssl_package_name = $mysql::params::libssl_package_name,
  $config_hash         = {},
  $enabled             = true,
  $manage_service      = true
) inherits mysql::params {

  Class['mysql::server'] -> Class['mysql::config']

  $config_class = { 'mysql::config' => $config_hash }

  create_resources( 'class', $config_class )

  if $galera {
    
    $package_name = $mysql::params::galera_package_name

    class { 'mysql':
      package_name => 'mysql-client-5.5'
    }
      
    exec { 'download-wsrep':
      command => "wget -O /tmp/${wsrep_deb_name} ${wsrep_deb_source} --no-check-certificate",
      path    => '/usr/bin:/usr/sbin:/bin:/sbin',
      creates => "/tmp/${wsrep_deb_name}",
    }
    exec { 'download-galera':
      command => "wget -O /tmp/${galera_deb_name} ${galera_deb_source} --no-check-certificate",
      path    => '/usr/bin:/usr/sbin:/bin:/sbin',
      creates => "/tmp/${galera_deb_name}",
    }
    package { 'wsrep':
      ensure   => $package_ensure,
      name     => $wsrep_package_name,
      provider => 'dpkg',
      require  => [Exec['download-wsrep'],Class['mysql'],Package['libaio','libssl']],
      source   => "/tmp/${wsrep_deb_name}",
    }
    package { 'galera':
      ensure   => $package_ensure,
      name     => $galera_package_name,
      provider => 'dpkg',
      require  => [Exec['download-galera'],Package['wsrep']],
      source   => "/tmp/${galera_deb_name}",
    }
    package { 'libaio' :
      ensure   => $package_ensure,
      name     => $libaio_package_name 
    }
    package { 'libssl' :
      ensure   => $package_ensure,
      name     => $libssl_package_name
    }
  } else {

    $package_name = $mysql::params::server_package_name
    
    package { 'mysql-server':
      ensure => $package_ensure,
      name   => $package_name,
    }
  }

  if $enabled {
    $service_ensure = 'running'
  } else {
    $service_ensure = 'stopped'
  }

  if $manage_service {
    service { 'mysqld':
      ensure   => $service_ensure,
      name     => $service_name,
      enable   => $enabled,
      require  => Package[$package_name], 
      provider => $service_provider,
    }
  }
}
