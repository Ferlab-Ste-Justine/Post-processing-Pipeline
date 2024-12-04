ARG EXOMISER_VERSION=13.1.0

# -------------------------------------------------------------------------- #
# Stage 1: using the distroless image to obtain exomiser distribution files  #
#                                                                            #
# We are using this image to guarantee the same packaging strategy as        #
# in other exomiser-cli images                                               #
# -------------------------------------------------------------------------- #
FROM exomiser/exomiser-cli:${EXOMISER_VERSION} AS builder


# -------------------------------------------------------------- #
# Stage 2: Create an image similar to exomiser cli bash images   #
#                                                                #
# We replicate only the necessary logic to launch the same java  #
# command as in other Exomiser images.                           #
# -------------------------------------------------------------- #

FROM eclipse-temurin:17.0.6_10-jre AS exomiser-cli-bash

COPY --from=builder /app /app


# ---------------------------------- #
# Stage 3: Add nextflow requirements #
# ---------------------------------- #

FROM exomiser-cli-bash

ARG EXOMISER_VERSION

# Adding ps to the container (required by nextflow)
RUN apt-get update && \
    apt-get install -y procps=2:3.3.17-6ubuntu2.1 && \
    rm -rf /var/lib/apt/lists/*


# Create a file containing the exomiser version, as there is no way to retrieve it from the exomiser-cli.
RUN echo ${EXOMISER_VERSION} > EXOMISER_VERSION.txt

# Required to execute exomiser docker with nextflow
ENTRYPOINT [  ]