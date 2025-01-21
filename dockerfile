# Use the latest Ubuntu image as the base
FROM ubuntu:latest

# Set non-interactive mode for APT
ENV DEBIAN_FRONTEND=noninteractive

# Update package lists and install required packages
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    apt-add-repository -y universe && \
    apt-add-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.13 python3.13-venv python3.13-dev python3-pip libcairo2 libcairo2-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set environment variables for MkDocs
ENV MKDOCS_VERSION=1.6.1

# Create a virtual environment
RUN python3.13 -m venv /venv


# Create the workspace directory
RUN mkdir -p /home/abhishek/workspace/database

# Set the working directory to workspace
WORKDIR /home/abhishek/workspace/database

# Copy requirements.txt
COPY requirements.txt requirements.txt 

# RUN source /venv/bin/activate

# Install MkDocs and any other required Python packages in the virtual environment
# RUN ./venv/bin/pip install --no-cache-dir mkdocs==${MKDOCS_VERSION} mkdocs mkdocs-material pillow cairosvg "mkdocs-material[imaging]"
RUN /venv/bin/pip install -r requirements.txt


# Copy the contents of the current directory to /home/abhishek/workspace/database-helper
COPY . .

# Expose the port that MkDocs will run on
EXPOSE 8000

# Command to run when starting the container
CMD ["/venv/bin/mkdocs", "serve", "-a", "0.0.0.0:8000"]