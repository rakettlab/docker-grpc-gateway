#!/usr/bin/env bash
echo "--- COPYING ---"
if [ "$EXTERNAL_PROTOBUFFER_DIRECTORY" ]; then
  echo "copying protobuffers from: $EXTERNAL_PROTOBUFFER_DIRECTORY"
  cp -rv "$EXTERNAL_PROTOBUFFER_DIRECTORY"/* "$PROTOBUFFER_DIR" || exit
fi

# Generate a config file based on the contents of the protos directory.
echo "--- CONFIGURING ---"
# Config file header.
echo "{
  \"gateway\": {
    \"listen\": \"$GATEWAY_HOST:$GATEWAY_PORT\"
  },
  \"backends\": [{" > "$GRPC_GATEWAY_CONF"
# Find all protofiles and generate backends, but exclude google.
PROTOFILES=($(find "$PROTOBUFFER_DIR" -iname '*.proto' -not -ipath '*google*'))
echo "Protofiles found: ${#PROTOFILES[@]}"
for ((i=0; i<${#PROTOFILES[@]}; i++ )); do
  echo "  -- Adding backend for ${PROTOFILES[$i]} --"
  # Get the package name.
  PACKAGE=$(grep 'package' "${PROTOFILES[$i]}" | sed 's/;//' | cut -f2 -d' ')
  # Get the path of the protofile protecting whatever path convention used for the protofiles.
  PACKAGE_PATH=$(echo "${PROTOFILES[$i]}" | rev | cut -d'/' -f2 | rev)
  echo "    - Exposing backend on path: /$PACKAGE_PATH/ -"
  echo "\
    \"package\": \"$PACKAGE\",
    \"backend\": \"$GRPC_BACKEND_HOST:$GRPC_BACKEND_PORT\",
    \"services\": {" >> "$GRPC_GATEWAY_CONF"
  # Get services and expose them under its package path.
  grep 'service' "${PROTOFILES[$i]}" | cut -f2 -d' ' | while IFS= read -r service; do
    echo "      - Exposing service $service on path /$PACKAGE_PATH/ -"
    echo "\
      \"$service\": \"/$PACKAGE_PATH/\"" >> "$GRPC_GATEWAY_CONF"
  done
  # Make sure to exclude ',' from the last "backends" object array
  if [[ $i+1 -lt "${#PROTOFILES[@]}" ]]; then
    echo "\
    }," >> "$GRPC_GATEWAY_CONF"
  else
    echo "\
    }" >> "$GRPC_GATEWAY_CONF"
  fi
  # Make sure packagename is same as its path for generator, rename if mismatch.
  if [ "$PACKAGE" != "$PACKAGE_PATH" ]; then
    NEWPATH=${PROTOFILES[$i]//$PACKAGE_PATH/$PACKAGE}
    echo "    ** Packagename not matching folder name. **
    Packagename: $PACKAGE
    Current path is: ${PROTOFILES[i]}
    New path will be: ${NEWPATH%/*}"
    # Make the new directory.
    mkdir -p "${NEWPATH%/*}"
    # Move the protofile to its new directory.
    mv "${PROTOFILES[$i]}" "${NEWPATH%/*}"
  fi
done
# Config file footer.
echo "\
  }]
}
" >> "$GRPC_GATEWAY_CONF"

echo "--- GENERATING ---"
cd /opt/generator || exit
./generate.sh "$PROTOBUFFER_DIR" "$GRPC_GATEWAY_CONF" gateway

echo "--- RUNNING ---"
cd /go/src/gateway/ || exit
go build grpc-gateway.go
go run grpc-gateway.go
