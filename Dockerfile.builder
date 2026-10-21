# syntax=docker/dockerfile:1.9
ARG PYTHON_VERSION=3.12

FROM python:${PYTHON_VERSION}-slim-trixie

SHELL ["sh", "-exc"]
ENV DEBIAN_FRONTEND=noninteractive
RUN <<EOT
    buildDeps="build-essential busybox ca-certificates curl git gosu libbz2-dev libffi-dev libjpeg62-turbo-dev libmagic1 libsasl2-dev libldap2-dev libopenjp2-7-dev libpq-dev libssl-dev libtiff6 libtiff5-dev libxml2-dev libxslt1-dev wget zlib1g-dev"
    apt-get update -qy
    apt-get install -qyy \
        -o APT::Install-Recommends=false \
        -o APT::Install-Suggests=false \
        $buildDeps
    apt-get -y upgrade
    python -m pip install "pip @ https://files.pythonhosted.org/packages/3f/06/3e4420302363fbb71be3c7f35ce042f54bfca330e3e66b3a2e3c4cca579f/pip-26.2.2-py3-none-any.whl#sha256=fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70"
    busybox --install -s
EOT

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PYTHON_DOWNLOADS=never \
    UV_PYTHON=python$PYTHON_VERSION \
    UV_PROJECT_ENVIRONMENT=/app

# Script used for pre-compilation of po files
COPY /helpers/compile_mo.py /compile_mo.py

# Copy default structure for a Plone Project
COPY /skeleton /app_skeleton

LABEL maintainer="Plone Community <dev@plone.org>" \
      org.label-schema.name="server-builder" \
      org.label-schema.description="Plone builder image with Python $PYTHON_VERSION and UV" \
      org.label-schema.vendor="Plone Foundation"
