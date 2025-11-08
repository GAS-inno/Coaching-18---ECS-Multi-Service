FROM python:3.11-slim

WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application file
COPY s3.py .

# Expose the application port
EXPOSE 5001

# Run the application
CMD ["python", "s3.py"]
