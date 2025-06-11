FROM mcr.microsoft.com/windows/servercore:ltsc2019

# Set up Chocolatey
RUN powershell -Command \
    Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install Git
RUN choco install git -y

# Install Flutter
WORKDIR C:\src
RUN git clone https://github.com/flutter/flutter.git -b 3.19.3
RUN setx PATH "%PATH%;C:\src\flutter\bin" /M
RUN flutter doctor
RUN flutter config --no-analytics
RUN flutter config --no-cli-animations

# Verify versions
RUN flutter --version
RUN dart --version

# Set up MSIX packaging
RUN flutter pub global activate msix

# Set working directory
WORKDIR C:\app

# Copy the application
COPY . .

# Install dependencies
RUN flutter pub get

# Build the app
RUN flutter build windows --release

# Create MSIX package
RUN flutter pub run msix:create --display-name "Kaatje" --publisher-display-name "Your Publisher Name" --identity-name "com.yourdomain.kaatje" --publisher "CN=YourPublisherID" --logo "assets/images/icon.png" --version "1.0.0.0"

# The MSIX package will be in build/windows/msix/ 