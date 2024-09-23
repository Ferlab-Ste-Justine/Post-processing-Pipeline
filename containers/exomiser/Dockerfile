FROM exomiser/exomiser-cli:14.0.0-bash

# Adding ps to the container (required by nextflow)
RUN apt-get update && \
    apt-get install -y procps=2:3.3.17-6ubuntu2.1 && \
    rm -rf /var/lib/apt/lists/*


# Create a file containing the exomiser version, as there is no way to retrieve it from the exomiser-cli.
# Ensure to update this file whenever you update the base exomiser image.
RUN echo "14.0.0" > EXOMISER_VERSION.txt

# Required to execute exomiser docker with nextflow
ENTRYPOINT [  ]