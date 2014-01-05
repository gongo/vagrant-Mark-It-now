$user = 'vagrant'
$markitnow = '/home/vagrant/Mark-It-now'

Exec {
  path => '/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin'
}

# Dependency packages

$dependency_packages = [
  'build-essential',
  'curl',
  'git',
  'libmysqld-dev',
  'libsqlite3-dev',
  'mysql-client',
  'mysql-server',
  'nodejs',
  'libmagickcore-dev',
  'libmagickwand-dev',
  'ruby2.0',
  'ruby2.0-dev',
  'wget'
]

$delete_ruby_versions = ['ruby1.8', 'ruby1.9.1']

# Install dependency packages

exec { 'apt-get update':
}

exec { 'apt-get upgrade':
  command => 'apt-get upgrade -y',
  require => Exec['apt-get update']
}

package { $dependency_packages:
  ensure  => latest,
  require => Exec['apt-get upgrade']
}

# Use ruby 2.0

package { $delete_ruby_versions:
  ensure  => absent,
  require => Package[$dependency_packages]
}

exec { 'update-alternatives --set ruby /usr/bin/ruby2.0':
  require => Package[$delete_ruby_versions],
  unless  => 'test /etc/alternatives/ruby -ef /usr/bin/ruby2.0'
}

exec { 'gem install bundler':
  require => Exec['update-alternatives --set ruby /usr/bin/ruby2.0'],
  unless  => 'gem list | grep -q bundler'
}

# Install groonga

file { '/etc/apt/sources.list.d/groonga.list':
  ensure  => present,
  content => template('groonga.list'),
  owner   => 'root',
  group   => 'root',
  mode    => '0644',
  require => Package[$dependency_packages]
}

exec { 'install groonga':
  command => 'apt-get update && apt-get -y --allow-unauthenticated install groonga-keyring && apt-get update && apt-get -y install libgroonga-dev',
  require => File['/etc/apt/sources.list.d/groonga.list'],
  unless  => 'dpkg -l | grep libgroonga-dev'
}


# Setup Mark-It-now

exec { 'git clone':
  command => "git clone https://github.com/ssig33/Mark-It-now.git ${markitnow}",
  user    => $user,
  unless  => "test -d ${markitnow}",
  require => Package[$dependency_packages]
}

file { "${markitnow}/config/database.yml":
  ensure  => present,
  content => template('database.yml'),
  owner   => $user,
  mode    => '0644',
  require => Exec['git clone']
}

file { "${markitnow}/config/config.yml":
  ensure  => present,
  content => template('config.yml'),
  owner   => $user,
  mode    => '0644',
  require => Exec['git clone']
}

file { '/tmp/mark-it-now.patch':
  ensure  => present,
  content => template('mark-it-now.patch'),
  mode    => '0644'
}

exec { 'patch':
  command => 'patch -p1 < /tmp/mark-it-now.patch',
  cwd     => $markitnow,
  require => [Exec['git clone'], File['/tmp/mark-it-now.patch']],
  unless  => 'git status | grep -q modified'
}

