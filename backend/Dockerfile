FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN pip install --upgrade pip && pip install -r /app/requirements.txt

COPY app.py /app/app.py

# Runtime envs (can be overridden)
ENV PORT=3001 \
    OPENAI_MODEL=gpt-4o-mini

EXPOSE 3001
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "3001"]
