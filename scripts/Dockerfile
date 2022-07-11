FROM ubuntu:14.04

RUN set -x \
    && pythonVersions='python2.6 python2.7 python3.1 python3.2 python3.3 python3.4 python3.5' \
    && apt-get update \
    && apt-get install -y --no-install-recommends software-properties-common \
    && apt-add-repository -y ppa:fkrull/deadsnakes \
    && apt-get update \
    && apt-get install -y --no-install-recommends $pythonVersions \
    && apt-get purge -y --auto-remove software-properties-common \
    && rm -rf /var/lib/apt/lists/*

CMD bash
