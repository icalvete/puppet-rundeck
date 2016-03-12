# Author::    Liam Bennett (mailto:lbennett@opentable.com)
# Copyright:: Copyright (c) 2013 OpenTable Inc
# License::   MIT

# == Define rundeck::config::job
#
# This definition is used to configure rundeck projects
#
# === Parameters
#
# [*file_copier_provider*]
#  The type of proivder that will be used for copying files to each of the nodes
#
# [*node_executor_provider*]
#  The type of provider that will be used to gather node resources
#
# [*resource_sources*]
#  A hash of rundeck::config::resource_source that will be used to specifiy the node
#  resources for this project
#
# [*ssh_keypath*]
#   The path the the ssh key that will be used by the ssh/scp providers
#
# [*projects_dir*]
#   The directory where rundeck is configured to store project information
#
# === Examples
#
# Create and manage a rundeck project:
#
# rundeck::config::project { 'test project':
#  ssh_keypath            => '/var/lib/rundeck/.ssh/id_rsa',
#  file_copier_provider   => 'jsch-scp',
#  node_executor_provider => 'jsch-ssh',
#  resource_sources       => $resource_hash
# }
#
define rundeck::config::job(

  $ensure               = 'present',
  $job_description_file = undef,
  $project              = undef,
  $jobs_dir             = undef,

) {

  include ::rundeck::params

  $jobs_dir_real = $jobs_dir ? {
    undef   => '/var/lib/rundeck/jobs',
    default => $jobs_dir,
  }

  validate_re($ensure, ['^present$', '^absent$'] )
  validate_re($job_description_file, ['\.yaml$', '\.xml$'] )

  if $job_description_file =~ /(.*)\/([^\/]*\.)(xml|yaml)/ {
    $job_path = $1
    $job_name = $2
    $job_type = $3
  }

  $path = "${jobs_dir_real}/${name}.${job_type}"

  file { "rdeck_job_${name}":
    ensure  => present,
    path    => $path,
    source  => "puppet:///modules/${job_description_file}",
    owner   => $user,
    group   => $group,
  }

  # TODO rundeck service doest start listening for connections inmediatelly, it takes some time to boot up
  # the platform before everything is ready (around 29 seconds according to logs) so we have to use
  # this KLUDGE (tries and try_slepp).

  if $ensure == 'present' {
    exec {"load_rdeck_job_${name}":
      command   => "/usr/bin/rd-jobs load -f ${path} -p ${project} -F ${job_type}",
      provider  => shell,
      tries     => 3,
      try_sleep => 30,
      require   => File["rdeck_job_${name}"]
    }
  } else {
    exec {"purge_rdeck_job_${name}":
      command   => "/usr/bin/rd-jobs purge -p ${project} -n ${name}",
      provider  => shell,
      tries     => 3,
      try_sleep => 30,
      require   => File["rdeck_job_${name}"]
    }
  }
}
