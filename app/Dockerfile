FROM python:3.11

COPY ./ /code/

RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

WORKDIR /code

CMD ["uvicorn", "app:app", "--proxy-headers", "--host", "0.0.0.0", "--port", "80"]
