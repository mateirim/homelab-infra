class profile::motd {

  # Ensure fortune and cowsay are installed
  package { ['fortune-mod', 'cowsay']:
    ensure => installed,
  }

  # Clear /etc/motd so static MOTD does not appear (dynamic script handles output)
  file { '/etc/motd':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => '',
  }

  # Deploy the dynamic MOTD script into profile.d so it runs on every login shell
  file { '/etc/profile.d/motd.sh':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => file('profile/motd.sh'),
    require => Package['fortune-mod', 'cowsay'],
  }

  # On Debian/Ubuntu systems, disable the update-motd framework scripts that
  # may produce duplicate or unwanted output (10-uname, 50-landscape-sysinfo, etc.)
  # We keep /etc/update-motd.d/00-header absent so our profile.d script is sole source.
  if $facts['os']['family'] == 'Debian' {
    # Disable the default header script so it doesn't emit its own banner
    file { '/etc/update-motd.d/00-header':
      ensure => absent,
    }

    # Optionally silence the "last login" duplicate line from pam_motd
    # by pointing /run/motd.dynamic to nothing — done via clearing /etc/motd above.
    # Make sure /etc/pam.d/sshd has pam_motd enabled (usually default on Debian/Ubuntu).
  }
}
