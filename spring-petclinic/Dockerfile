FROM maven:3.8.5-openjdk-17 AS builder
LABEL maintainer="Praveen.Guntu"
WORKDIR /app
COPY pom.xml pom.xml
RUN mvn dependency:go-offline -B
COPY ./ ./
RUN mvn clean package -DskipTests -B

FROM openjdk:17-alpine
LABEL maintainer="Praveen.Guntu"
WORKDIR /app
EXPOSE 8080
COPY --from=builder /app/target/*.jar /app/app.jar
CMD ["java", "-jar", "app.jar"]
