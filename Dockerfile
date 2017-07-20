FROM golang:1.7-alpine

## Install script dependencies
RUN apk update && apk upgrade && apk add --no-cache bash jq

# Intall protobuf
ENV PROTOBUF_BRANCH 3.4.x
ADD build-protobuf.sh /root/build-protobuf.sh
RUN /root/build-protobuf.sh

# Install grpc-gateway and grpc-gateway-generator
RUN apk update && apk upgrade && apk add --no-cache git && \
  go-wrapper download google.golang.org/grpc && \
  go-wrapper download github.com/golang/protobuf/protoc-gen-go && \
  go-wrapper download github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway && \
  go-wrapper download github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger && \
  go-wrapper install google.golang.org/grpc && \
  go-wrapper install github.com/golang/protobuf/protoc-gen-go && \
  go-wrapper install github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway && \
  go-wrapper install github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger && \
  git clone https://github.com/devsu/grpc-gateway-generator --depth 1 /opt/generator && \
  apk del git

RUN mkdir -p /opt/generator/config
RUN mkdir -p /opt/generator/protos

VOLUME ["/opt/generator/config"]
VOLUME ["/opt/generator/protos"]


# Configuration environment variables.
# useful if container will be linked to another container
ENV EXTERNAL_PROTOBUFFER_DIRECTORY ''
ENV GRPC_GATEWAY_CONF '/opt/generator/config/config.json'
ENV GATEWAY_HOST ''
ENV GATEWAY_PORT 8080
ENV GRPC_PACKAGE 'packageName'
ENV GRPC_BACKEND_HOST 'example.com'
ENV GRPC_BACKEND_PORT 5555
ENV GRPC_SERVICE 'ExampleService'
ENV GRPC_SERVICE_PATH 'servicePath'
ENV PROTOBUFFER_DIR '/opt/generator/protos/'

ADD start.sh /root/start.sh

CMD ["/bin/bash", "/root/start.sh"]
