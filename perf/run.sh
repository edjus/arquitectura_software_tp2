#!/bin/bash
export TARGET=http://$(cat ../node/elb_dns)
export DATADOG_API_KEY=
export DEBUG=metrics
npm run artillery run $1.yaml
