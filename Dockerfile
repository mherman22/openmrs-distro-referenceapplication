# syntax=docker/dockerfile:1

### Dev Stage
FROM openmrs/openmrs-core:2.8.x-dev-amazoncorretto-21 AS dev

# Set up the local Maven repository
VOLUME /root/.m2/repository

WORKDIR /openmrs_distro

ARG MVN_ARGS_SETTINGS="-s /usr/share/maven/ref/settings-docker.xml -U -P distro,no-demo"
ARG MVN_ARGS="install"

# Create directory for the ICRC content package Maven artifact in both possible locations
RUN mkdir -p /root/.m2/repository/org/openmrs/content/icrc/ && \
    mkdir -p /usr/share/maven/ref/repository/org/openmrs/content/icrc/

# Copy the entire ICRC content package Maven artifact (including POM) from local Maven repo to both locations
COPY maven-repo/org/openmrs/content/icrc/ /root/.m2/repository/org/openmrs/content/icrc/
COPY maven-repo/org/openmrs/content/icrc/ /usr/share/maven/ref/repository/org/openmrs/content/icrc/

# Copy build files
COPY pom.xml ./
COPY distro ./distro/

ARG CACHE_BUST
# Build the distro, but only deploy from the amd64 build
RUN --mount=type=secret,id=m2settings,target=/usr/share/maven/ref/settings-docker.xml if [[ "$MVN_ARGS" != "deploy" || "$(arch)" = "x86_64" ]]; then mvn $MVN_ARGS_SETTINGS $MVN_ARGS; else mvn $MVN_ARGS_SETTINGS install; fi

RUN cp /openmrs_distro/distro/target/sdk-distro/web/openmrs_core/openmrs.war /openmrs/distribution/openmrs_core/

RUN cp /openmrs_distro/distro/target/sdk-distro/web/openmrs-distro.properties /openmrs/distribution/
RUN cp -R /openmrs_distro/distro/target/sdk-distro/web/openmrs_modules /openmrs/distribution/openmrs_modules/
RUN cp /openmrs_distro/distro/dataimport-1.0.0-SNAPSHOT.omod /openmrs/distribution/openmrs_modules/
RUN cp -R /openmrs_distro/distro/target/sdk-distro/web/openmrs_owas /openmrs/distribution/openmrs_owas/
RUN cp -R /openmrs_distro/distro/target/sdk-distro/web/openmrs_config /openmrs/distribution/openmrs_config/

# Clean up after copying needed artifacts
RUN mvn $MVN_ARGS_SETTINGS clean

### Run Stage
# Replace '2.7.x' with the exact version of openmrs-core built for production (if available)
FROM openmrs/openmrs-core:2.8.x-amazoncorretto-21

# Do not copy the war if using the correct openmrs-core image version
COPY --from=dev /openmrs/distribution/openmrs_core/openmrs.war /openmrs/distribution/openmrs_core/

COPY --from=dev /openmrs/distribution/openmrs-distro.properties /openmrs/distribution/
COPY --from=dev /openmrs/distribution/openmrs_modules /openmrs/distribution/openmrs_modules
COPY --from=dev /openmrs/distribution/openmrs_owas /openmrs/distribution/openmrs_owas
COPY --from=dev  /openmrs/distribution/openmrs_config /openmrs/distribution/openmrs_config
