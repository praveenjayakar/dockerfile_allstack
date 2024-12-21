FROM node:slim
LABEL maintainer="Praveen.Guntu"
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY ./ ./
EXPOSE 3000
CMD ["npm", "start"]
