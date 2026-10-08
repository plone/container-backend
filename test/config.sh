#!/usr/bin/env bash
globalTests+=(
        utc
        no-hard-coded-passwords
        override-cmd
)

imageTests_main_set='
plone-basics
plone-develop
plone-site
plone-addons
plone-cors
plone-arbitrary-user
plone-listenport
plone-zeoclient
plone-relstorage
plone-shared-blob-dir
plone-basics-chown
'

imageTests+=(
	[plone/plone-backend]=$imageTests_main_set
	[ghcr.io/plone/plone-backend]=$imageTests_main_set
)

globalExcludeTests+=(

)
