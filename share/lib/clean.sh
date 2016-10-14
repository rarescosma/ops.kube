#!/bin/bash

clean::binaries() {
  rm -rf $DOT/bin/*
}

clean::tls() {
  rm -rf $DOT/etc/tls/*
}
