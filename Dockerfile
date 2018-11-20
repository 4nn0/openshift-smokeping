FROM debian:jessie
MAINTAINER David Personette <dperson@gmail.com>

# Install lighttpd and smokeping
RUN set -x \
    export DEBIAN_FRONTEND='noninteractive' && \
    apt-get update -qq && \
    apt-get install -qqy --no-install-recommends smokeping ssmtp dnsutils \
                fonts-dejavu-core echoping ca-certificates curl lighttpd wget \
                $(apt-get -s dist-upgrade|awk '/^Inst.*ecurity/ {print $2}') &&\
    apt-get clean && \
    /bin/echo '@include /etc/smokeping/config.d/Config' > /etc/smokeping/config && \
    /bin/rm /etc/smokeping/config.d/* && \
    conf=/etc/lighttpd/lighttpd.conf dir=/etc/lighttpd/conf-available \
                header=setenv.add-response-header && \
    sed -i '/server.errorlog/s|^|#|' $conf && \
    sed -i 's/server.port                 = 80/server.port                 = 8080/' $conf && \
    sed -i 's/server.groupname            = "www-data"/server.groupname            = "root"/' $conf && \
    sed -i '/server.document-root/s|/html||' $conf && \
    sed -i '/mod_rewrite/a\ \t"mod_setenv",' $conf && \
    echo "\\n$header"' += ( "X-XSS-Protection" => "1; mode=block" )' >>$conf &&\
    echo "$header"' += ( "X-Content-Type-Options" => "nosniff" )' >>$conf && \
    echo "$header"' += ( "X-Robots-Tag" => "none" )' >>$conf&& \
    echo "$header"' += ( "X-Frame-Options" => "SAMEORIGIN" )' >>$conf && \
    echo '\n$HTTP["url"] =~ "^/smokeping($|/)" {' >>$conf && \
    echo '\tdir-listing.activate = "disable"\n}' >>$conf && \
    echo '\n# redirect to the right Smokeping URI' >>$conf && \
    echo 'url.redirect  = ("^/$" => "/smokeping/smokeping.cgi",' >>$conf && \
    echo '\t\t\t"^/smokeping/?$" => "/smokeping/smokeping.cgi")' >>$conf && \
    sed -i 's|var/log/lighttpd/access.log|tmp/log|' $dir/10-accesslog.conf && \
    sed -i '/^#cgi\.assign/,$s/^#//; /"\.pl"/i\ \t".cgi"  => "/usr/bin/perl",' \
                $dir/10-cgi.conf && \
    echo '\nfastcgi.server += ( ".cgi" =>\n\t((' >>$dir/10-fastcgi.conf && \
    sed -i -e '/CHILDREN/s/[0-9][0-9]*/16/' \
                -e '/max-procs/a\ \t\t"idle-timeout" => 20,' \
                $dir/15-fastcgi-php.conf && \
    grep -q 'allow-x-send-file' $dir/15-fastcgi-php.conf || { \
        sed -i '/idle-timeout/a\ \t\t"allow-x-send-file" => "enable",' \
                    $dir/15-fastcgi-php.conf && \
        sed -i '/"bin-environment"/a\ \t\t\t"MOD_X_SENDFILE2_ENABLED" => "1",' \
                    $dir/15-fastcgi-php.conf; } && \
    echo '\t\t"socket" => "/tmp/perl.socket" + var.PID,' \
                >>$dir/10-fastcgi.conf && \
    echo '\t\t"bin-path" => "/usr/share/smokeping/www/smokeping.fcgi",'\
                >>$dir/10-fastcgi.conf && \
    echo '\t\t"docroot" => "/var/www",' >>$dir/10-fastcgi.conf && \
    echo '\t\t"check-local"     => "disable",\n\t))\n)' \
                >>$dir/10-fastcgi.conf && \
    unset conf dir header && \
    sed -i 's|/usr/bin/smokeping_cgi|/usr/lib/cgi-bin/smokeping.cgi|' \
                /usr/share/smokeping/www/smokeping.fcgi.dist && \
    mv /usr/share/smokeping/www/smokeping.fcgi.dist \
                /usr/share/smokeping/www/smokeping.fcgi && \
    lighttpd-enable-mod cgi && \
    lighttpd-enable-mod fastcgi && \
    [ -d /var/cache/smokeping ] || mkdir -p /var/cache/smokeping && \
    [ -d /var/lib/smokeping ] || mkdir -p /var/lib/smokeping && \
    [ -d /run/smokeping ] || mkdir -p /run/smokeping && \
    ln -s /usr/share/smokeping/www /var/www/smokeping && \
    ln -s /usr/lib/cgi-bin /var/www/ && \
    ln -s /usr/lib/cgi-bin/smokeping.cgi /var/www/smokeping/ && \
    chmod u+s /usr/bin/fping && \
    rm -rf /var/lib/apt/lists/* /tmp/* && \
    mkdir -p /run && \
    mkdir -p /var/cache/smokeping/images && \
    mkdir -p /var/lib/smokeping/Local && \
    chmod g+rw -R /run && \
    chmod g+rw -R /var/cache && \
    chmod g+rw -R /var/lib/smokeping && \
    chown root:root -R /var/lib/smokeping
COPY smokeping.sh /usr/bin/

EXPOSE 8080

ENTRYPOINT ["/usr/bin/smokeping.sh"]
