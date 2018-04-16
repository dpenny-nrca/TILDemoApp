# TILDemoApp
[![Swift](https://img.shields.io/badge/Swift-4.1-green.svg)](https://swift.org)
[![MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)


This is a basic Vapor 3 application created from the fantastic [Server Side Swift with Vapor](https://videos.raywenderlich.com/courses/115-server-side-swift-with-vapor/lessons/1) course by Tim Condon on [RayWenderlich.com](https://www.raywenderlich.com).

I have added a few additional features to the app and will continue to use it as a testing/demo repository as I learn various aspects of Vapor 3. I hope this can also be used as an example of how various features are implemented in Vapor 3, so feel free to open an issue or submit a pull request.

***

### Prerequisites
The project is configured to use a Docker container running PostgreSQL. After installing [Docker](https://www.docker.com/community-edition#/download), you can run the following command to create the container:
```shell
docker run --name pgsql -e POSTGRES_USER=til -e POSTGRES_PASSWORD=password -e POSTGRES_DB=vapor -p 5432:5432 -d postgres
```

This creates a new Docker container named `pgsql` and installs the PostgreSQL server.

The databse connection is configured in [configure.swift](Sources/App/configure.swift).