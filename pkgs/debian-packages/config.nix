{ pkgs}:
{
  vrouterPostinst = pkgs.writeTextFile {
    name = "postinst";
    text = ''
      #!/bin/sh
      # OpenContrail developers <dev@lists.opencontrail.org>

      set -e

      if [ "$1" = "configure" ]; then

        # Create the "contrail" user
        if ! getent passwd contrail > /dev/null 2>&1
        then
          adduser --quiet --system --group --home /var/lib/contrail \
            --no-create-home \
            --shell /bin/false \
            --gecos "OpenContrail daemon" contrail
        fi

        # Create the "contrail" group if it is missing and set the primary group
        # of the "contrail" user to this group.
        if ! getent group contrail > /dev/null 2>&1
        then
          addgroup --quiet --system contrail
          usermod -g contrail contrail
        fi

      fi
    '';
  };

  vrouterPostrm = pkgs.writeTextFile {
    name = "postrm";
    text = ''
      #!/bin/sh

      set -e

      if [ "''${1}" = "purge" ] ; then

        # Del user contrail (and backup home)
        if (which deluser && getent passwd contrail) > /dev/null 2>&1; then
          deluser --system --quiet --backup-to /var/lib contrail || true
        fi

        # Del group contrail
        if (which delgroup && getent group contrail) > /dev/null 2>&1; then
          delgroup --system --quiet contrail || true
        fi

        rm -rf /var/log/contrail /var/lib/contrail

      fi
    '';
  };
  vrouterUpstart = pkgs.writeTextFile {
    name = "contrail-vrouter-agent.conf";
    text = ''
      description "Contrail Vrouter Agent"
      author "OpenContrail developers <dev@lists.opencontrail.org>"

      start on (local-filesystems and net-device-up IFACE!=lo)
      stop on runlevel [!2345]

      chdir /var/run
      respawn

      script
        COMMAND="/usr/bin/contrail-vrouter-agent"
        CONF="/etc/contrail/contrail-vrouter-agent.conf"
        USER="contrail"
        OPTS="--config_file ''${CONF}"

        # Allow override of command/conf and opts by /etc/default/daemon-name
        if [ -f /etc/default/$UPSTART_JOB ]; then
          . /etc/default/$UPSTART_JOB
        fi

        if ! [ -r "$CONF" ] ; then
          echo "Could not read ''${CONF}: exiting"
          exit 0
        fi

        exec start-stop-daemon --start \
              --pidfile /var/run/''${UPSTART_JOB}.pid \
              --exec $COMMAND -- $OPTS

      end script
    '';
  };

}
