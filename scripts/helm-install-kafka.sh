#!/bin/bash

helm repo add strimzi https://strimzi.io/charts/
helm repo update
# Nebula-Platform(modules/environment/gitops.tf) 과 같은 버전. data-kafka 는 kafka.strimzi.io/v1 API 를 쓰므로 1.0 이상이 필요하다
helm upgrade --install kafka strimzi/strimzi-kafka-operator --namespace backend --version 1.2.0