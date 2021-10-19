#!/bin/bash

nim c --threads:on -d:release --opt:speed fastx_multithreaded_utility
nim c -d:release --opt:speed fastx_utility_1
