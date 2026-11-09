# syntax=docker/dockerfile:1
ARG PYTHON_VERSION=3.12
ARG PLONE_VERSION
FROM plone/server-builder:${PLONE_VERSION} AS builder

ARG PLONE_VERSION

FROM plone/server-prod-config:${PLONE_VERSION}

ARG PYTHON_VERSION
ARG PLONE_VERSION

LABEL maintainer="Plone Community <dev@plone.org>" \
      org.label-schema.name="plone-backend" \
      org.label-schema.description="Plone $PLONE_VERSION backend image using Python $PYTHON_VERSION" \
      org.label-schema.vendor="Plone Foundation"

# Use /app as the workdir
WORKDIR /app

# Copy /app from builder
COPY --from=builder --chown=500:500 /app /app

# Enable compilation of po files into mo files (This is added here for backward compatibility)

ENV zope_i18n_compile_mo_files=true

# Link /data (the exposed volume) into /app/var
RUN ln -s /data /app/var
