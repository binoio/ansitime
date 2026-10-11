FROM swift:6.0-noble

WORKDIR /src
COPY Package.swift ./
COPY Sources/AnsiCore Sources/AnsiCore
COPY Tests/AnsiCoreTests Tests/AnsiCoreTests

RUN swift test
CMD ["swift", "test"]
