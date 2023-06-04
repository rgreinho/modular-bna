FROM postgis/postgis:13-3.1
LABEL author="PeopleForBikes"

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  ca-certificates \
  g++ \
  git \
  make \
  postgresql-13-pgrouting \
  postgresql-plpython3-13\
  postgresql-server-dev-13 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && mkdir /tmp/build/ \
  && cd /tmp/build \
  && git clone --branch master https://github.com/tvondra/quantile.git \
  && cd quantile \
  && make install
