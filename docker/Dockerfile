# Dockerfile
FROM python:3.11-slim as builder

# Set build arguments
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

# Add metadata
LABEL maintainer="devops-team@company.com" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="flask-auth-app" \
      org.label-schema.description="Flask Authentication Application" \
      org.label-schema.url="https://github.com/company/flask-devops-project" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/company/flask-devops-project" \
      org.label-schema.vendor="Company DevOps Team" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Set work directory
WORKDIR /build

# Copy requirements first for better caching
COPY app/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --user -r requirements.txt

# Production stage
FROM python:3.11-slim as production

# Install security updates
RUN apt-get update && apt-get install -y \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set work directory
WORKDIR /app

# Copy Python packages from builder stage
COPY --from=builder /root/.local /home/appuser/.local

# Copy application code
COPY --chown=appuser:appuser app/ .

# Create necessary directories
RUN mkdir -p /app/instance && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Make sure scripts in .local are usable
ENV PATH=/home/appuser/.local/bin:$PATH

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:5000/health')" || exit 1

# Run the application
CMD ["python", "app.py"]
