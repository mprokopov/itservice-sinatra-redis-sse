FROM debian:latest
MAINTAINER Max Prokopov <mprokopov@gmail.com>
RUN apt-get update -qq && apt-get install -y build-essential nodejs ruby2.1 libssl1.0.0 libcurl3 git-core ruby2.1-dev \
libxml2-dev libmysqlclient-dev rubygems
#zlib1g-dev \
RUN gem install --no-document bundler
WORKDIR /app
ADD app/ .

RUN bundle install --jobs 20 --retry 5 --deployment --no-cache --without=development test --clean

EXPOSE 9292
#CMD ["foreman", "start", "-d", "/app"]
CMD ["bundle","exec", "rackup", "-p", "9292"]
