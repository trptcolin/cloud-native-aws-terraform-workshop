#!/usr/bin/env bash

echo "Host $(terraform state show aws_instance.bastion | grep '^public_ip' | sed -e 's/.*= //')
  ForwardAgent yes
"
