#!/bin/bash

for x in `seq 1 254`; do echo 10.0.0.$x h$x h$x.local; done
for x in `seq 1 254`; do echo 10.0.1.$x b$x b$x.local; done
for x in `seq 1 254`; do echo 10.0.2.$x c$x c$x.local; done
