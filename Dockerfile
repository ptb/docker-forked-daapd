FROM debian:jessie
# MAINTAINER Peter T Bosse II <ptb@ioutime.com>

RUN \
  REQUIRED_PACKAGES='avahi-daemon libantlr3c-dev libasound2-dev libavahi-client-dev libavcodec-dev libavfilter-dev libavformat-dev libavutil-dev libconfuse-dev libevent-dev libgcrypt11-dev libmxml-dev libplist-dev libsqlite3-dev libswscale-dev libtool libunistring-dev zlib1g-dev' \
  && BUILD_PACKAGES='antlr3 autoconf autotools-dev build-essential gawk gettext git gperf wget' \

  && USERID_ON_HOST=1026 \

  && useradd \
    --comment forked-daapd \
    --create-home \
    --gid users \
    --no-user-group \
    --shell /usr/sbin/nologin \
    --uid $USERID_ON_HOST \
    forked-daapd \

 && echo "debconf debconf/frontend select noninteractive" \
    | debconf-set-selections \

  && sed \
    -e "s/httpredir.debian.org/debian.mirror.constant.com/" \
    -i /etc/apt/sources.list \

  && apt-get update -qq \
  && apt-get install -qqy \
    $REQUIRED_PACKAGES \
    $BUILD_PACKAGES \

  && wget \
    --output-document - \
    --quiet \
    https://api.github.com/repos/ejurgensen/forked-daapd/tarball/master \
    | tar -xz -C /tmp/ \
  && mv /tmp/ejurgensen-forked-daapd* /tmp/forked-daapd \

  && cd /tmp/forked-daapd/ \
  && autoreconf -i \
  && ./configure --prefix=/usr/local --sysconfdir=/etc --localstatedir=/home/forked-daapd --enable-itunes \
  && make \
  && make install \
  && sed \
    -e 's/^\tname.*/\tname = "Depot"/' \
    -e 's/^\tdirectories.*/\tdirectories = \{ "\/home\/media\/Music" \}/' \
    -e 's/^#\titunes_overrides.*/\titunes_overrides = true/' \
    -e '/^# Local audio output$/,/^\}$/d' \
    -i /etc/forked-daapd.conf \
  && mkdir -p /home/forked-daapd/cache/forked-daapd/ \
  && chown -R forked-daapd:users /home/forked-daapd/ \

  && wget \
    --output-document - \
    --quiet \
    https://api.github.com/repos/just-containers/s6-overlay/releases/latest \
    | sed -n "s/^.*browser_download_url.*: \"\(.*s6-overlay-amd64.tar.gz\)\".*/\1/p" \
    | wget \
      --input-file - \
      --output-document - \
      --quiet \
    | tar -xz -C / \

  && mkdir -p /etc/services.d/dbus/ /var/run/dbus/ \
  && printf "%s\n" \
    "#!/usr/bin/env sh" \
    "set -ex" \
    "exec /usr/bin/dbus-daemon --nofork --system" \
    > /etc/services.d/dbus/run \
  && chmod +x /etc/services.d/dbus/run \

  && mkdir -p /etc/services.d/avahi/ \
  && printf "%s\n" \
    "#!/usr/bin/env sh" \
    "set -ex" \
    "while \`/bin/s6-svwait -u -a /var/run/s6/services/dbus\`; do" \
    "  sleep 5" \
    "  break" \
    "done && exec /usr/sbin/avahi-daemon" \
    > /etc/services.d/avahi/run \
  && chmod +x /etc/services.d/avahi/run \

  && mkdir -p /etc/services.d/forked-daapd/ \
  && printf "%s\n" \
    "#!/usr/bin/env sh" \
    "set -ex" \
    "while \`/bin/s6-svwait -u -a /var/run/s6/services/dbus /var/run/s6/services/avahi\`; do" \
    "  sleep 5" \
    "  break" \
    "done && exec /usr/local/sbin/forked-daapd -f" \
    > /etc/services.d/forked-daapd/run \
  && chmod +x /etc/services.d/forked-daapd/run \

  && apt-get purge -qqy --auto-remove \
    $BUILD_PACKAGES \
  && apt-get clean -qqy \
  && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

ENTRYPOINT ["/init"]
EXPOSE 3689

# docker build --rm --tag ptb2/forked-daapd .
# docker run --detach --name forked-daapd --net host \
#   --publish 3689:3689/tcp \
#   --volume /volume1/@appstore/forked-daapd/forked-daapd.conf:/etc/forked-daapd.conf \
#   --volume /volume1/Media:/home/media:ro \
#   ptb2/forked-daapd
