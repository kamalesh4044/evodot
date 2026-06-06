FROM ubuntu:22.04

# Install dependencies for Godot headless
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    ca-certificates \
    fontconfig \
    && rm -rf /var/lib/apt/lists/*

# Download Godot Linux binary (you can update this URL to your specific version)
RUN wget -q https://github.com/godotengine/godot-builds/releases/download/4.2.1-stable/Godot_v4.2.1-stable_linux.x86_64.zip -O godot.zip \
    || wget -q https://github.com/godotengine/godot/releases/download/4.2.1-stable/Godot_v4.2.1-stable_linux.x86_64.zip -O godot.zip \
    && unzip godot.zip \
    && mv Godot_v4.2.1-stable_linux.x86_64 /usr/local/bin/godot \
    && rm godot.zip

# Create working directory and copy files
WORKDIR /app
COPY . .

# Force Godot to import all resources so .glb files work headless
RUN godot --headless --editor --quit || true

# Expose the WebSocket port
EXPOSE 1337

# Run the Godot server headless
CMD ["godot", "--headless", "--server"]
