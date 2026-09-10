FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    fontconfig \
    espeak-ng \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Bundle real caption fonts instead of relying on whatever (if anything)
# happens to be installed on the host — python:3.11-slim ships with no
# fonts at all, so without this the `subtitles` ffmpeg filter would have
# nothing to substitute and captions could render blank.
RUN mkdir -p /usr/share/fonts/truetype/shortsforge \
    && cp app/assets/fonts/*.ttf /usr/share/fonts/truetype/shortsforge/ \
    && fc-cache -f

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
