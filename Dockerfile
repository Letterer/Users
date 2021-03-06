FROM swift:4.2
LABEL Description="Mikroservice Users" Vendor="Marcin Czachurski" Version="1.0"

ADD . /users
WORKDIR /users

RUN swift build --configuration release
EXPOSE 8001
ENTRYPOINT [".build/release/Run", "--port", "8001", "--hostname", "0.0.0.0"]