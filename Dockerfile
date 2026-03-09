FROM public.ecr.aws/docker/library/python:3.11-slim
EXPOSE 8080
RUN apt update && apt install -y pkg-config gcc \
    default-libmysqlclient-dev pkg-config
WORKDIR /app
COPY requirements.txt /app
RUN pip3 install -r requirements.txt --no-cache-dir
COPY manage.py /app/
COPY hairdresser_django/ /app/hairdresser_django/
COPY appointments/ /app/appointments/
ENTRYPOINT ["python3"] 
CMD ["manage.py", "runserver", "0.0.0.0:8088"]