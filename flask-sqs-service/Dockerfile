FROM python:3.11-slim

WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application file
COPY sqs.py .

# Expose the application port
EXPOSE 5002

# Run the application
CMD ["python", "sqs.py"]
