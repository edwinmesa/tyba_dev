# Use a lightweight Python base image
FROM python:3.12-slim

# Prevents Python from writing pyc files.
ENV PIP_NO_CACHE_DIR=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install system dependencies
RUN apt-get update && \
    apt-get install -y git && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first to leverage Docker layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy only the application code into the container
# This avoids copying Airflow files, etc., into the FastAPI image.
COPY ./app .

# Expose FastAPI port
EXPOSE 8088

# Command to run FastAPI app
CMD ["uvicorn", "utils.main:app", "--host", "0.0.0.0", "--port", "8088"]