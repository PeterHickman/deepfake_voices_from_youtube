FROM python:3.10

# docker run --rm -it -v ./voices:/app/voices:ro -v ./output:/app/output:rw piper_say ./say

#NAME piper_say

#RUN -v ./voices:/app/voices:ro
#RUN -v ./output:/app/output:rw

WORKDIR /app

RUN apt update && apt install libsndfile1 ruby -y

COPY setup1 .
RUN bash ./setup1

COPY say .

CMD ["sleep", "infinity"]
