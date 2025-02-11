FROM python:3.11.9-slim

# Set ARG and ENV
ARG TELEGRAM_TOKEN
ENV TELEGRAM_TOKEN="${TELEGRAM_TOKEN}"

# Install system dependencies
COPY ../requirements/requirements.apt .
RUN apt-get update && \
    apt-get install -y --no-install-recommends $(sed 's/#.*//' requirements.apt) && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY ../requirements/requirements.txt . 
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source
COPY camera-src /camera-src
WORKDIR /camera-src

# Install Chrome (Optional)
RUN apt-get update && \
    apt-get install -y --no-install-recommends chromium && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

CMD ["python", "main.py"]
