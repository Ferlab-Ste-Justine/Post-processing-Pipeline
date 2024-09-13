FROM exomiser/exomiser-cli:14.0.0-bash

# Adding ps to the container (required by nextflow)
RUN apt-get update && \
    apt-get install -y procps=2:3.3.17-6ubuntu2.1 && \
    rm -rf /var/lib/apt/lists/*

# Required to execute exomiser docker with nextflow
ENTRYPOINT [  ]