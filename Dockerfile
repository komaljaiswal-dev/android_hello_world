FROM gradle:7.5.1-jdk11
WORKDIR /bp/workspace

# Install system dependencies
USER root

RUN apt-get update && apt-get install -y \
    # Ruby and build dependencies
    ruby \
    ruby-dev \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    # Git for fastlane
    git \
    # Utilities
    curl \
    wget \
    unzip \
    jq \
    bc \
    # Additional dependencies for fastlane
    libffi-dev \
    libreadline-dev \
    libyaml-dev \
    libsqlite3-dev \
    sqlite3 \
    libxml2-dev \
    libxslt1-dev \
    libcurl4-openssl-dev \
    software-properties-common \
    libgdbm-dev \
    libncurses5-dev \
    automake \
    libtool \
    bison \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Verify Ruby version
RUN ruby --version

# Install Bundler
RUN gem install bundler -v 2.4.22 --no-document

# Install Fastlane and its dependencies
RUN gem install fastlane -NV --no-document

# Install additional Fastlane plugins
RUN fastlane add_plugin supply || true
RUN fastlane add_plugin firebase_app_distribution || true

# Verify Fastlane installation
RUN fastlane --version

# Add BuildPiper shell functions
ADD BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/

# Make shell functions executable
RUN chmod +x /opt/buildpiper/shell-functions/*.sh

# Copy build.sh script
COPY build.sh /usr/local/bin/build.sh

# Make build.sh executable
RUN chmod +x /usr/local/bin/build.sh

# IMPORTANT: Copy your Android project into the container
# This copies everything from your current directory to /bp/workspace/
COPY . /bp/workspace/

# Set BuildPiper environment variables
ENV ACTIVITY_SUB_TASK_CODE="BP-FASTLANE-TASK"
ENV SLEEP_DURATION="0"
ENV VALIDATION_FAILURE_ACTION="WARNING"
ENV INSTRUCTION="fastlane init"

# BuildPiper workspace configuration
ENV WORKSPACE="/bp/workspace"
ENV CODEBASE_DIR=""
ENV PLATFORM=""

# Fastlane execution mode
ENV FASTLANE_MODE="instruction"
# Options: 
#   - instruction: Execute fastlane lane (original behavior)
#   - supply: Execute fastlane supply directly
#   - both: Execute instruction then supply

# Fastlane Supply variables
ENV PACKAGE_NAME="org.opstree.app"
ENV BUILD_TYPE="apk"
# Options: apk, aab

ENV RELEASE_TRACK="internal"
# Options: internal, alpha, beta, production

ENV ROLLOUT_PERCENTAGE=""
# For production rollout: 10, 25, 50, 100

ENV JSON_KEY_PATH="fastlane/playstore-key.json"
ENV APK_PATH="app/build/outputs/apk/release/app-release.apk"
ENV AAB_PATH="app/build/outputs/bundle/release/app-release.aab"
RUN chmod +x /usr/local/bin/build.sh

ENTRYPOINT ["/usr/local/bin/build.sh"]
