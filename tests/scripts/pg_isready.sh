#!/bin/bash
timeout 90s bash -c "until pg_isready ; do sleep 5 ; done"
