FROM ubuntu:latest

# Install necessary packages
RUN apt update && apt full-upgrade -y && apt install -y \
    bash \
    jq \
    nano \
    openssl \
    coreutils \
    xxd

# Copy all files from build context into /root
COPY ./run.sh /app/run.sh
COPY ./res/* /app/res/

# Set working directory
WORKDIR /app

# Set execute permission for run.sh
RUN chmod +x /app/run.sh

# Run bash when container starts
CMD ["./run.sh"]