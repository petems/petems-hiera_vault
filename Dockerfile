FROM ruby:2.7.3

RUN apt-get update -yqq
RUN apt-get install -yqq --no-install-recommends build-essential zip unzip libpq-dev libaio1 libaio-dev nodejs

ENV APP_HOME=/usr/src/module
ENV BUNDLE_PATH /gems
ENV VAULT_VERSION=1.3.0

COPY . $APP_HOME

RUN curl -sLo vault.zip https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip \
  && unzip vault.zip \
  && mkdir -p /usr/local/bin \
  && mv vault /usr/local/bin

RUN echo "gem: --no-rdoc --no-ri" >> ~/.gemrc

WORKDIR $APP_HOME
RUN gem update --system
RUN gem install bundler
RUN bundle install

CMD ["sleep 1"]