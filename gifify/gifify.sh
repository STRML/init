#!/bin/bash -e

if ! docker images | grep -q "gifify"; then
  echo "Gifify docker image not found, building..."
  docker build -t gifify:v1 .
fi

[ $# -lt 1 ] && {
  echo "This is a utility for converting .mov files to optimized gifs."
  echo "Usage: $0 <movfile>";
  exit 1;
}

FILENAME="${1%.*}"
echo "Creating $FILENAME.gif..."
docker run -it --rm -v "$(pwd):/data" gifify:v1 "$FILENAME.mov" -o "$FILENAME.gif"
