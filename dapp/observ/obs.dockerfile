FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY models.py control.py main.py ./

EXPOSE 6000

CMD ["python", "main.py"]