FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1

# Create app directory
WORKDIR /app/backend

# Install system deps needed for some Python packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install
COPY requirements.txt /app/backend/requirements.txt
RUN pip install --no-cache-dir -r /app/backend/requirements.txt

# Copy application source
COPY . /app/backend

EXPOSE 8000

CMD ["python", "main.py"]
