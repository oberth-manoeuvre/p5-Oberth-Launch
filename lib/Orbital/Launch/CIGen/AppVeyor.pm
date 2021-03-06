package Orbital::Launch::CIGen::AppVeyor;
# ABSTRACT: Generate AppVeyor configuration

use Moo;
use Data::Section -setup;

1;
__DATA__
__[ appveyor.yml ]__
version: 1.0.{build}

cache:
  # cache local::lib
  - C:\msys64\mingw64\lib\perl5\site_perl -> appveyor.yml
  - C:\msys64\mingw64\bin\site_perl -> appveyor.yml
  - C:\msys64\home\%Username%\perl5 -> appveyor.yml
  - maint/cpanfile-git-log -> appveyor.yml
  # cache for devops helper.pl
  - C:\Perl\site -> appveyor.yml

install:
  - ps: . { iwr -useb https://raw.githubusercontent.com/orbital-transfer/launch-site/master/script/ci/appveyor-orbital.ps1 } | iex
  - ps: appveyor-orbital install

build_script:
  - ps: appveyor-orbital build-script
test_script:
  - ps: appveyor-orbital test-script
