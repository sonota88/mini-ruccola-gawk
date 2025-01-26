FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    gawk \
    ruby \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# --------------------------------

ARG user
ARG group
ARG ARG_HOME=/home/${user}

RUN userdel -r ubuntu

RUN groupadd ${user} \
  && useradd ${user} -g ${group} -m

USER ${user}

# --------------------------------

WORKDIR ${ARG_HOME}/work

# --------------------------------

ENV IN_CONTAINER=1
ENV LANG=en_US.UTF-8

CMD ["bash", "-l"]
