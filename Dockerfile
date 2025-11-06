FROM ubuntu:latest

# Copy all files from build context into /root
COPY . /root

# Set working directory
WORKDIR /root

# Run bash when container starts
CMD ["/bin/bash -c", "./generate_new_license.sh"]