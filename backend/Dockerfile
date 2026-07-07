FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    fontconfig \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Bundle a real caption font instead of relying on whatever (if anything)
# happens to be installed on the host — python:3.11-slim ships with no
# fonts at all, so without this the `subtitles` ffmpeg filter would have
# nothing to substitute and captions could render blank.
RUN mkdir -p /usr/share/fonts/truetype/inter \
    && cp app/assets/fonts/*.ttf /usr/share/fonts/truetype/inter/ \
    && fc-cache -f

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
