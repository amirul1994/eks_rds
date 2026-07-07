# Stage 1: Build the React application
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Stage 2: Serve with Nginx using non-root user
FROM nginx:alpine

# Copy custom configuration (replacing the main nginx.conf)
COPY nginx.conf /etc/nginx/nginx.conf

# Copy built assets from builder stage
COPY --from=builder /app/build /usr/share/nginx/html

# Set ownership and permissions for the built-in 'nginx' user
RUN chown -R nginx:nginx /var/cache/nginx /var/log/nginx /etc/nginx/conf.d /var/run/ && \
    chown -R nginx:nginx /usr/share/nginx/html && \
    chown nginx:nginx /etc/nginx/nginx.conf

# Switch to the non-root 'nginx' user
USER nginx

EXPOSE 9000
CMD ["nginx", "-g", "daemon off;"]