""" EEA Faceted Navigation Installer
"""
import os
from os.path import join
from setuptools import setup, find_packages

setup(name="helloworld",
      version="0.1",
      description="Hello World",
      author='Plone',
      url='https://github.com/plone/container-backend',
      license='GPL version 2',
      packages=['helloworld'],
      include_package_data=True,
      zip_safe=False,
      install_requires=[
          'setuptools',
      ],
      extras_require={
          'test': [
              'plone.app.testing',
          ],
      },
      entry_points="""
      [z3c.autoinclude.plugin]
      target = plone
      """
      )
