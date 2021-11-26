FROM docker.io/puppet/puppetserver:6.14.1

RUN puppetserver gem install vault --no-document

RUN puppetserver gem install debouncer --no-document

RUN /opt/puppetlabs/puppet/bin/gem install vault --no-document

RUN /opt/puppetlabs/puppet/bin/gem install debouncer --no-document