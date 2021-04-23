FROM python:3.6

ENV SCANCODE_VERSION=21.3.31


RUN apt-get update && apt-get install bzip2 xz-utils zlib1g libxml2-dev libxslt1-dev

ADD "https://github.com/nexB/scancode-toolkit/releases/download/v${SCANCODE_VERSION}/scancode-toolkit-${SCANCODE_VERSION}_py36-linux.tar.xz" scancode-toolkit.tar.xz

RUN \
    xz -d scancode-toolkit.tar.xz && \
    tar xvf scancode-toolkit.tar
    
WORKDIR scancode-toolkit-${SCANCODE_VERSION}

RUN ./configure

ENV PATH=$HOME/scancode-toolkit:$PATH
