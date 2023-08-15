#################################
#          Variables            #
#################################

# Versioning
ARG RUBY_VERSION="2.7"
ARG BUNDLER_VERSION="2.2.16"
ARG NODEJS_VERSION="16"
ARG YARN_VERSION="1.22.19"

# Packages
ARG BUILD_PACKAGES="nodejs git transifex-client sqlite3 libsqlite3-dev imagemagick build-essential default-libmysqlclient-dev"
ARG RUN_PACKAGES="imagemagick shared-mime-info pkg-config libmagickcore-dev libmagickwand-dev default-libmysqlclient-dev"

# needs to be set before the pre/post-build script, which uses the argument
ARG INTEGRATION_BUILD="0"

# Scripts
ARG PRE_INSTALL_SCRIPT="curl -sL https://deb.nodesource.com/setup_${NODEJS_VERSION}.x -o /tmp/nodesource_setup.sh && bash /tmp/nodesource_setup.sh"
ARG INSTALL_SCRIPT="node -v && npm -v && npm install -g yarn && yarn set version ${YARN_VERSION}"
ARG PRE_BUILD_SCRIPT="\
     if [[ \"$INTEGRATION_BUILD\" == 1 ]]; then git submodule update --remote; fi; \
     git submodule status | tee WAGON_VERSIONS; \
     rm -rf hitobito/.git; \
     mv hitobito/* hitobito/.tx .; \
     mkdir -p vendor/wagons; \
     for wagon_dir in hitobito_*; do if [[ -d \$wagon_dir ]]; then rm -r \$wagon_dir/.git && mv \$wagon_dir vendor/wagons/; fi; done; \
     rm -rf hitobito; \
     cp -v Wagonfile.production Wagonfile; \
"
ARG BUILD_SCRIPT="bundle exec rake assets:precompile"
ARG POST_BUILD_SCRIPT="\
     if [[ \"$INTEGRATION_BUILD\" == 1 ]]; then bundle exec rake tx:pull tx:wagon:pull tx:push tx:wagon:push -t; fi; \
     RAILS_DB_USERNAME=\"dummy\" \
        bundle exec rake db:migrate wagon:migrate ts:configure \
     && sed -i 's/\"/\`/g; s/\(  sql_\)\(host\|user\|pass\|db\)\( = \).*/\1\2\3UNSET/' config/production.sphinx.conf; \
     echo \"(built at: $(date '+%Y-%m-%d %H:%M:%S'))\" > /app-src/BUILD_INFO; \
     bundle exec bootsnap precompile app/ lib/; \
"

# Bundler specific
ARG BUNDLE_WITHOUT_GROUPS="development:metrics:test"

# App specific
ARG RAILS_ENV="production"
ARG RACK_ENV="production"
ARG NODE_ENV="production"
ARG RAILS_HOST_NAME="unused.example.net"
ARG SECRET_KEY_BASE="needs-to-be-set"

# Runtime ENV vars
ARG SENTRY_CURRENT_ENV
ARG HOME=/app-src
ARG PS1="[\$SENTRY_CURRENT_ENV] `uname -n`:\$PWD\$ "
ARG TZ="Europe/Zurich"

# Add one of these near the end of the file

# # Github specific
# ARG GITHUB_SHA
# ARG GITHUB_REPOSITORY
# ARG GITHUB_REF_NAME
# ARG BUILD_COMMIT="$GITHUB_SHA"
# ARG BUILD_REPO="$GITHUB_REPOSITORY"
# ARG BUILD_REF="$GITHUB_REF_NAME"

# # Gitlab specific
# ARG CI_COMMIT_SHA
# ARG CI_REPOSITORY_URL
# ARG CI_COMMIT_REF_NAME
# ARG BUILD_COMMIT="$CI_COMMIT_SHA"
# ARG BUILD_REPO="$CI_REPOSITORY_URL"
# ARG BUILD_REF="$CI_COMMIT_REF_NAME"

# # Openshift specific
# ARG OPENSHIFT_BUILD_COMMIT
# ARG OPENSHIFT_BUILD_SOURCE
# ARG OPENSHIFT_BUILD_REFERENCE
# ARG BUILD_COMMIT="$OPENSHIFT_BUILD_COMMIT"
# ARG BUILD_REPO="$OPENSHIFT_BUILD_SOURCE"
# ARG BUILD_REF="$OPENSHIFT_BUILD_REFERENCE"


#################################
#          Build Stage          #
#################################

FROM ruby:${RUBY_VERSION} AS build

# arguments for steps
ARG HOME
ARG PRE_INSTALL_SCRIPT
ARG BUILD_PACKAGES
ARG INSTALL_SCRIPT
ARG BUNDLER_VERSION
ARG PRE_BUILD_SCRIPT
ARG BUNDLE_WITHOUT_GROUPS
ARG BUILD_SCRIPT
ARG POST_BUILD_SCRIPT

# arguments potentially used by steps
ARG NODE_ENV
ARG RACK_ENV
ARG RAILS_ENV
ARG RAILS_HOST_NAME
ARG SECRET_KEY_BASE
ARG TZ

# Set build shell
SHELL ["/bin/bash", "-c"]

# Use root user
USER root

RUN bash -vxc "${PRE_INSTALL_SCRIPT:-"echo 'no PRE_INSTALL_SCRIPT provided'"}"

# Install dependencies
RUN    export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends ${BUILD_PACKAGES}

RUN bash -vxc "${INSTALL_SCRIPT:-"echo 'no INSTALL_SCRIPT provided'"}"

# Explicitly install specific versions of bundler
# (not required with newer bundler versions)
RUN gem install bundler:${BUNDLER_VERSION} --no-document

# TODO: Load artifacts

# set up home directory
WORKDIR $HOME
COPY Gemfile Gemfile.lock Wagonfile.production ./

RUN bash -vxc "${PRE_BUILD_SCRIPT:-"echo 'no PRE_BUILD_SCRIPT provided'"}"

# install gems and build the app
RUN    bundle config set --local deployment 'true' \
    && bundle config set --local without ${BUNDLE_WITHOUT_GROUPS} \
    && bundle install \
    && bundle clean
    # \
    # && bundle exec bootsnap precompile --gemfile

# install npms for the frontend
COPY package.json yarn.lock ./
# COPY .yarn ./.yarn/
RUN yarn install --immutable

# copy entire application code
COPY . .

RUN bash -vxc "${BUILD_SCRIPT:-"echo 'no BUILD_SCRIPT provided'"}"

RUN bash -vxc "${POST_BUILD_SCRIPT:-"echo 'no POST_BUILD_SCRIPT provided'"}"

# TODO: Save artifacts

RUN rm -rf vendor/cache/ .git spec/ node_modules/ db/production.sqlite3


#################################
#           Sphinx image        #
#################################

FROM macbre/sphinxsearch:3.1.1 AS sphinx

ARG HOME
ENV PS1="${PS1}" \
    TZ="${TZ}" \
    RAILS_HOME="${HOME}"

COPY --from=build $RAILS_HOME/config/production.sphinx.conf /opt/sphinx/conf/sphinx.conf
COPY --from=build $RAILS_HOME/bin/run-sphinx /usr/local/bin/run-sphinx

CMD ["/usr/local/bin/run-sphinx"]


#################################
#         Run/App Stage         #
#################################

# This image will be replaced by Openshift
FROM ruby:${RUBY_VERSION}-slim AS app

# arguments for steps
ARG RUN_PACKAGES
ARG BUNDLER_VERSION
ARG BUNDLE_WITHOUT_GROUPS

# arguments potentially used by steps
ARG HOME
ARG NODE_ENV
ARG PS1
ARG RACK_ENV
ARG RAILS_ENV
ARG TZ

# Set environment variables available in the image
ENV PS1="${PS1}" \
    TZ="${TZ}" \
    HOME="${HOME}" \
    PATH="${HOME}/bin:$PATH" \
    NODE_ENV="${NODE_ENV}" \
    RAILS_ENV="${RAILS_ENV}" \
    RACK_ENV="${RACK_ENV}"

# Set runtime shell
SHELL ["/bin/bash", "-c"]

# Add user
RUN adduser --disabled-password --uid 1001 --gid 0 --gecos "" app

# Install dependencies, remove apt!
RUN    export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y ${RUN_PACKAGES} vim curl less \
    && apt-get clean \
    && rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && truncate -s 0 /var/log/*log

# TODO second step: jemalloc
# ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2

# Copy deployment ready source code from build
COPY --from=build $HOME $HOME
WORKDIR $HOME

# Create pids folder for puma and
# set group permissions to folders that need write permissions.
# Beware that docker builds on OpenShift produce different permissions
# than local docker builds!
RUN mkdir -p tmp/pids \
    && chgrp 0 $HOME \
    && chgrp -R 0 $HOME/tmp \
    && chgrp -R 0 $HOME/log \
    && chmod u+w,g=u $HOME \
    && chmod -R u+w,g=u $HOME/tmp \
    && chmod -R u+w,g=u $HOME/log

# Install specific versions of dependencies
# (not required with newer bundler versions)
RUN gem install bundler:${BUNDLER_VERSION} --no-document

# Use cached gems
RUN    bundle config set --local deployment 'true' \
    && bundle config set --local without ${BUNDLE_WITHOUT_GROUPS} \
    && bundle install

# These args contain build information. Also see build stage.
# They change with each build, so only define them here for optimal layer caching.
# Also see https://docs.docker.com/engine/reference/builder/#impact-on-build-caching
ARG BUILD_REPO
ARG BUILD_REF
# ARG BUILD_DATE
ARG BUILD_COMMIT

ENV BUILD_REPO="${BUILD_REPO}" \
    BUILD_REF="${BUILD_REF}" \
    # BUILD_DATE="${BUILD_DATE}" \
    BUILD_COMMIT="${BUILD_COMMIT}"

# Set runtime user (although OpenShift uses a custom user per project instead)
USER 1001

CMD ["bundle", "exec", "puma", "-t", "8"]
