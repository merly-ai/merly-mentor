FROM node:20.18.0 AS production

# Install required packages
# Install git as a runtime dependency
RUN apt-get update && \
    apt-get install -y --no-install-recommends git ca-certificates jq unzip && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# Set working directory
WORKDIR /app

# Define a build argument with a default value of 'Test'
ARG BUILD_ENV=Test

# Copy only necessary files
COPY ./scripts/prepare-mentor-container-assets.sh /app/
COPY ./scripts/entrypoint.sh /app/
RUN chmod +x /app/prepare-mentor-container-assets.sh
RUN chmod +x /app/entrypoint.sh
RUN bash /app/prepare-mentor-container-assets.sh Ubuntu $BUILD_ENV

# Install production dependencies
WORKDIR /app/UI
RUN npm install --omit=dev --ignore-scripts

# Change the workdir to the root of the app
WORKDIR /app



# Declare environment variables with default values
ENV MERLY_AI_DAEMON_URL=http://localhost:4200/

# Set the entrypoint, passing in the REGISTRATION_KEY environment variable
ENTRYPOINT ["sh", "-c", "./entrypoint.sh \"$REGISTRATION_KEY\""]