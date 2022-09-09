#!/usr/bin/env bash

KAT_HOST=${KAT_HOST-yukari}

nix eval --json github:kittywitch/nixfiles#nixosConfigurations.$KAT_HOST.users.users.kat |
	jq 'del(.packages, .shell)' \
	> userdata.json
