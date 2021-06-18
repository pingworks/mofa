FROM docker.io/chef/chefdk:1.6.11

RUN apt update && apt upgrade --yes && \
  apt install build-essential rsync --yes && \
  gem install mofa

RUN mkdir /root/.mofa

COPY config.docker.yml /root/.mofa/config.yml

ENV PATH="/root/.chefdk/gem/ruby/2.3.0/bin:${PATH}"

