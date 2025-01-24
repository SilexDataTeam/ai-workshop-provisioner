FROM registry.access.redhat.com/ubi9/nodejs-22:9.5-1737605092 AS base

# Copy the api server code with owner and permissions
COPY --chown=1001:0 . /workspace/workshop-user-registration

# Install dependencies
RUN npm install --prefix /workspace/workshop-user-registration

# Build the frontend
RUN npm run build --prefix /workspace/workshop-user-registration

# Expose the port
EXPOSE 3000

# Entrypoint
WORKDIR /workspace/workshop-user-registration
ENTRYPOINT ["npm", "start", "--prefix", "/workspace/workshop-user-registration"]