#!/bin/bash

echo "Which org are you going to up?"
read network


docker-compose -f docker-compose_${network}.yaml up
